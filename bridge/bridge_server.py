"""
GMod AI Assistant - Bridge Server
WebSocket server that bridges GMod and LM Studio.
"""

import asyncio
import json
import signal
import sys
from typing import Dict, Set
import websockets
from websockets.server import serve

from config import WEBSOCKET_HOST, WEBSOCKET_PORT, DEBUG
from lm_client import LMStudioClient


class BridgeServer:
    def __init__(self):
        self.clients: Set[websockets.WebSocketServerProtocol] = set()
        self.client_info: Dict[websockets.WebSocketServerProtocol, dict] = {}
        self.lm_client = LMStudioClient()
        self.pending_tool_calls: Dict[str, dict] = {}  # message_id -> tool call info
        
    async def handle_client(self, websocket):
        """Handle a new client connection."""
        self.clients.add(websocket)
        client_id = id(websocket)
        print(f"[Bridge] Client connected: {client_id}")
        
        try:
            async for message in websocket:
                await self.handle_message(websocket, message)
        except websockets.exceptions.ConnectionClosed:
            print(f"[Bridge] Client disconnected: {client_id}")
        finally:
            self.clients.remove(websocket)
            if websocket in self.client_info:
                del self.client_info[websocket]
    
    async def handle_message(self, websocket, message):
        """Handle an incoming message from GMod."""
        try:
            data = json.loads(message)
            msg_type = data.get("type")
            
            if DEBUG:
                print(f"[Bridge] Received: {msg_type} - {str(data)[:200]}")
            
            if msg_type == "handshake":
                await self.handle_handshake(websocket, data)
                
            elif msg_type == "chat":
                await self.handle_chat(websocket, data)
                
            elif msg_type == "tool_result":
                await self.handle_tool_result(websocket, data)
            
            elif msg_type == "mcp_tool_call":
                # Direct tool call from MCP server
                await self.handle_mcp_tool_call(websocket, data)
                
            else:
                print(f"[Bridge] Unknown message type: {msg_type}")
                
        except json.JSONDecodeError as e:
            print(f"[Bridge] JSON decode error: {e}")
        except Exception as e:
            print(f"[Bridge] Error handling message: {e}")
            await self.send_error(websocket, data.get("message_id"), str(e))
    
    async def handle_handshake(self, websocket, data):
        """Handle handshake from GMod server."""
        self.client_info[websocket] = {
            "server_name": data.get("server_name", "Unknown"),
            "map": data.get("map", "Unknown"),
            "max_players": data.get("max_players", 0),
            "player_count": data.get("player_count", 0)
        }
        print(f"[Bridge] GMod server connected: {data.get('server_name')} on {data.get('map')}")
    
    async def handle_chat(self, websocket, data):
        """Handle a chat message from a player."""
        message_id = data.get("message_id", "unknown")
        player_id = data.get("player", {}).get("steamid", "unknown")
        
        # Send thinking status
        await self.send(websocket, {
            "type": "thinking",
            "message_id": message_id
        })
        
        # Create stream callback
        async def stream_callback(chunk):
            await self.send(websocket, {
                "type": "response_stream",
                "message_id": message_id,
                "chunk": chunk
            })
        
        # Get response from LM Studio
        result = await self.lm_client.chat(data, stream_callback)
        
        if "error" in result:
            await self.send_error(websocket, message_id, result["error"])
            return
        
        if result["type"] == "tool_calls":
            # AI wants to use tools
            for tool_call in result["tool_calls"]:
                tool_call_id = tool_call["id"]
                
                # Store pending tool call info using tool_call_id as unique key
                self.pending_tool_calls[tool_call_id] = {
                    "websocket": websocket,
                    "message_id": message_id,
                    "player_id": player_id,
                    "tool_call": tool_call,
                    "total_calls": len(result["tool_calls"])
                }
                
                if DEBUG:
                    print(f"[Bridge] Stored pending tool call: {tool_call_id} for message {message_id}")
                
                # Send tool call to GMod - include tool_call_id for tracking
                await self.send(websocket, {
                    "type": "tool_call",
                    "message_id": message_id,
                    "tool": tool_call["name"],
                    "tool_call_id": tool_call_id,
                    "args": tool_call["arguments"],
                    "player_id": player_id
                })
        else:
            # Regular response - send end-of-stream marker
            await self.send(websocket, {
                "type": "response_end",
                "message_id": message_id
            })
            
            # Also send complete response for chat display
            await self.send(websocket, {
                "type": "response",
                "message_id": message_id,
                "text": result["text"]
            })
    
    async def handle_tool_result(self, websocket, data):
        """Handle tool execution result from GMod."""
        message_id = data.get("message_id")
        tool_call_id = data.get("tool_call_id")
        tool_name = data.get("tool")
        success = data.get("success", False)
        result = data.get("result", {})
        
        if DEBUG:
            print(f"[Bridge] Tool result received - message_id: {message_id}, tool_call_id: {tool_call_id}, tool: {tool_name}")
            print(f"[Bridge] Pending tool calls: {list(self.pending_tool_calls.keys())}")
        
        # Look up by tool_call_id first (preferred), fall back to message_id + tool_name for backwards compatibility
        pending = None
        lookup_key = None
        
        if tool_call_id and tool_call_id in self.pending_tool_calls:
            lookup_key = tool_call_id
            pending = self.pending_tool_calls[lookup_key]
        elif message_id:
            # Fallback: try to find by message_id
            for key, value in self.pending_tool_calls.items():
                if value.get("message_id") == message_id and value.get("tool_call", {}).get("name") == tool_name:
                    lookup_key = key
                    pending = value
                    break
        
        if not pending:
            print(f"[Bridge] No pending tool call found for tool_call_id: {tool_call_id}, message_id: {message_id}, tool: {tool_name}")
            print(f"[Bridge] Available pending calls: {self.pending_tool_calls}")
            return
        
        player_id = pending["player_id"]
        tool_call = pending["tool_call"]
        original_message_id = pending["message_id"]
        
        if DEBUG:
            print(f"[Bridge] Found pending call with key: {lookup_key}, original message_id: {original_message_id}")
        
        # Add tool result to LM Studio conversation
        self.lm_client.add_tool_result(
            player_id,
            tool_call["id"],
            tool_name,
            {"success": success, "result": result}
        )
        
        del self.pending_tool_calls[lookup_key]
        
        # Check if all tool calls for this original message are complete
        remaining = sum(1 for k, v in self.pending_tool_calls.items() if v.get("message_id") == original_message_id)
        
        if remaining == 0:
            if DEBUG:
                print(f"[Bridge] All tool calls complete for message {original_message_id}, getting final AI response")
            
            # All tools executed, get final response from AI
            async def stream_callback(chunk):
                await self.send(websocket, {
                    "type": "response_stream",
                    "message_id": original_message_id,
                    "chunk": chunk
                })
            
            result = await self.lm_client.continue_after_tools(player_id, stream_callback)
            
            if DEBUG:
                print(f"[Bridge] AI continuation result type: {result.get('type', 'unknown')}")
            
            if "error" in result:
                await self.send_error(websocket, original_message_id, result["error"])
                return
            
            if result["type"] == "tool_calls":
                # AI wants more tools (chaining)
                if DEBUG:
                    print(f"[Bridge] AI requested {len(result['tool_calls'])} more tool calls")
                
                for tool_call in result["tool_calls"]:
                    tool_call_id = tool_call["id"]
                    
                    self.pending_tool_calls[tool_call_id] = {
                        "websocket": websocket,
                        "message_id": original_message_id,
                        "player_id": player_id,
                        "tool_call": tool_call
                    }
                    
                    await self.send(websocket, {
                        "type": "tool_call",
                        "message_id": original_message_id,
                        "tool": tool_call["name"],
                        "tool_call_id": tool_call_id,
                        "args": tool_call["arguments"],
                        "player_id": player_id
                    })
            else:
                # Send final response
                if DEBUG:
                    print(f"[Bridge] Sending final response: {result.get('text', '')[:100]}...")
                
                await self.send(websocket, {
                    "type": "response_end",
                    "message_id": original_message_id
                })
                
                await self.send(websocket, {
                    "type": "response",
                    "message_id": original_message_id,
                    "text": result["text"]
                })
        else:
            if DEBUG:
                print(f"[Bridge] {remaining} tool calls still pending for message {original_message_id}")
    
    async def handle_mcp_tool_call(self, websocket, data):
        """Handle direct tool call from MCP server (bypasses LM Studio)."""
        message_id = data.get("message_id")
        tool_name = data.get("tool")
        args = data.get("args", {})
        
        # Store the pending call
        self.pending_tool_calls[message_id] = {
            "websocket": websocket,
            "message_id": message_id,
            "is_mcp": True
        }
        
        # Find a connected GMod client
        gmod_client = None
        for client in self.clients:
            if client in self.client_info:
                gmod_client = client
                break
        
        if not gmod_client:
            await self.send(websocket, {
                "type": "tool_result",
                "message_id": message_id,
                "success": False,
                "error": "No GMod server connected"
            })
            return
        
        # Forward tool call to GMod
        await self.send(gmod_client, {
            "type": "tool_call",
            "message_id": message_id,
            "tool": tool_name,
            "args": args
        })
    
    async def send(self, websocket, data):
        """Send a message to a client."""
        try:
            message = json.dumps(data)
            if DEBUG:
                print(f"[Bridge] Sending: {str(data)[:200]}")
            await websocket.send(message)
        except Exception as e:
            print(f"[Bridge] Send error: {e}")
    
    async def send_error(self, websocket, message_id, error):
        """Send an error message to a client."""
        await self.send(websocket, {
            "type": "error",
            "message_id": message_id,
            "error": error
        })
    
    async def broadcast(self, data):
        """Broadcast a message to all connected clients."""
        for client in self.clients:
            await self.send(client, data)
    
    async def start(self):
        """Start the WebSocket server."""
        print(f"[Bridge] Starting server on ws://{WEBSOCKET_HOST}:{WEBSOCKET_PORT}")
        print("[Bridge] Waiting for GMod connection...")
        print("[Bridge] Press Ctrl+C to stop")
        
        async with serve(self.handle_client, WEBSOCKET_HOST, WEBSOCKET_PORT):
            await asyncio.Future()  # Run forever


async def main():
    server = BridgeServer()
    
    # Handle graceful shutdown
    def signal_handler(sig, frame):
        print("\n[Bridge] Shutting down...")
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    await server.start()


if __name__ == "__main__":
    print("=" * 50)
    print("  GMod AI Assistant - Bridge Server")
    print("=" * 50)
    print()
    print("Make sure:")
    print("1. LM Studio is running with a model loaded")
    print("2. LM Studio server is started at http://localhost:1234")
    print("3. GMod addon is installed and server is running")
    print()
    
    asyncio.run(main())
