"""
GMod AI Assistant - AI Client
Handles communication with AI providers using OpenAI-compatible API.
Supports: LM Studio, Cerebras, and any OpenAI-compatible provider.
Supports both regular models and thinking/reasoning models.
"""

import json
import re
import time
from openai import OpenAI
from config import (
    SYSTEM_PROMPT, STREAM_RESPONSES, DEBUG, PROVIDER,
    THINKING_MODEL, SHOW_THINKING, THINKING_BUDGET, REASONING_EFFORT,
    get_provider_config
)
from tools import GMOD_TOOLS

# Rate limit retry settings
MAX_RETRIES = 3
RETRY_BASE_DELAY = 2  # seconds


class LMStudioClient:  # Name kept for backwards compatibility
    def __init__(self):
        # Get provider configuration
        provider_config = get_provider_config()
        
        self.client = OpenAI(
            base_url=provider_config["base_url"],
            api_key=provider_config["api_key"]
        )
        self.model = provider_config["model"]
        self.conversations = {}  # Store conversation history per player
        
        if DEBUG:
            print(f"[AI Client] Using provider: {PROVIDER}")
            print(f"[AI Client] Model: {self.model}")
            print(f"[AI Client] Base URL: {provider_config['base_url']}")
        
    def _get_conversation(self, player_id):
        """Get or create conversation history for a player."""
        if player_id not in self.conversations:
            self.conversations[player_id] = [
                {"role": "system", "content": SYSTEM_PROMPT}
            ]
        return self.conversations[player_id]
    
    def _clean_response_text(self, text):
        """
        Remove problematic unicode characters and clean up response text.
        This fixes garbled responses from thinking models.
        """
        if not text:
            return ""
        
        # Remove zero-width and invisible unicode characters
        text = re.sub(r'[\u200b\u200c\u200d\u2060\ufeff]', '', text)
        # Normalize various space characters to regular space
        text = re.sub(r'[\u00a0\u2007\u202f\u2009\u200a]', ' ', text)
        # Remove non-breaking hyphens and other oddities
        text = text.replace('\u2011', '-')
        # Remove stray backslashes that appear in garbled output
        text = re.sub(r'(?<!\\)\\(?![\\nrt"\'\[\]{}])', '', text)
        # Collapse multiple newlines
        text = re.sub(r'\n{3,}', '\n\n', text)
        # Collapse multiple spaces
        text = re.sub(r'  +', ' ', text)
        # Remove lines that are just punctuation/ellipsis
        text = re.sub(r'^[\s\-\.…]+$', '', text, flags=re.MULTILINE)
        # Clean up multiple blank lines
        text = re.sub(r'\n\s*\n\s*\n', '\n\n', text)
        
        return text.strip()
    
    def _add_message(self, player_id, role, content):
        """Add a message to the conversation history."""
        conv = self._get_conversation(player_id)
        conv.append({"role": role, "content": content})
        
        # Keep conversation history reasonable - but preserve tool call chains
        self._trim_conversation(player_id)
    
    def _add_assistant_message_with_tool_calls(self, player_id, content, tool_calls):
        """
        Add an assistant message with tool calls to conversation history.
        OpenAI-compatible APIs require the tool_calls to be in the assistant message.
        """
        conv = self._get_conversation(player_id)
        
        # Build the tool_calls in the format the API expects
        formatted_tool_calls = []
        for tc in tool_calls:
            formatted_tool_calls.append({
                "id": tc["id"],
                "type": "function",
                "function": {
                    "name": tc["name"],
                    "arguments": json.dumps(tc["arguments"]) if isinstance(tc["arguments"], dict) else tc["arguments"]
                }
            })
        
        message = {
            "role": "assistant",
            "content": content or None,  # Some APIs require null instead of empty string
            "tool_calls": formatted_tool_calls
        }
        
        conv.append(message)
        
        # Keep conversation history reasonable - but preserve tool call chains
        self._trim_conversation(player_id)
    
    def _trim_conversation(self, player_id):
        """
        Trim conversation history while preserving tool call chains.
        This prevents 422 errors from orphaned tool results.
        """
        conv = self._get_conversation(player_id)
        if len(conv) <= 21:
            return
        
        # Find which tool call IDs are referenced in messages we want to keep
        messages_to_keep = [conv[0]]  # Always keep system message
        recent_messages = conv[-20:]
        
        # Collect all tool_call_ids that are referenced in recent messages
        referenced_tool_call_ids = set()
        for msg in recent_messages:
            # Tool result messages reference a tool_call_id
            if msg.get("role") == "tool" and msg.get("tool_call_id"):
                referenced_tool_call_ids.add(msg["tool_call_id"])
        
        # Now find all assistant messages with tool_calls that are referenced
        # and include them before the recent messages
        for msg in conv[1:-20]:  # Messages between system and recent
            if msg.get("role") == "assistant" and msg.get("tool_calls"):
                for tc in msg["tool_calls"]:
                    if tc.get("id") in referenced_tool_call_ids:
                        messages_to_keep.append(msg)
                        break
        
        messages_to_keep.extend(recent_messages)
        self.conversations[player_id] = messages_to_keep
    
    def _build_user_message(self, message_data):
        """Build a user message with context."""
        player = message_data.get("player", {})
        
        context = f"""[Context]
Player: {player.get('name', 'Unknown')}
Position: ({player.get('position', {}).get('x', 0)}, {player.get('position', {}).get('y', 0)}, {player.get('position', {}).get('z', 0)})
Health: {player.get('health', 100)} | Armor: {player.get('armor', 0)}
Current Weapon: {player.get('weapon', 'none')}
Is Admin: {player.get('is_admin', False)}
Map: {message_data.get('map', 'unknown')}"""
        
        looking_at = player.get("looking_at")
        if looking_at:
            context += f"\nLooking at: {looking_at.get('class', 'unknown')} ({looking_at.get('model', 'no model')})"
        
        return f"{context}\n\n[Player Message]\n{message_data.get('text', '')}"
    
    def _build_api_params(self):
        """Build API parameters based on configuration."""
        params = {
            "model": self.model,
            "tools": GMOD_TOOLS,
            "tool_choice": "auto",
        }
        
        # Add thinking/reasoning parameters if applicable
        if THINKING_MODEL:
            # For extended thinking models (like some DeepSeek variants)
            if THINKING_BUDGET is not None:
                params["max_completion_tokens"] = THINKING_BUDGET
            
            # For o1-style models
            if REASONING_EFFORT is not None:
                params["reasoning_effort"] = REASONING_EFFORT
        
        return params
    
    def _extract_thinking_and_response(self, text):
        """
        Extract thinking/reasoning content and final response from model output.
        
        Some models wrap thinking in:
        - <think>...</think> tags
        - <reasoning>...</reasoning> tags
        - ```thinking ... ``` blocks
        
        Returns: (thinking_content, response_content)
        """
        if not text:
            return None, ""
        
        thinking = None
        response = text
        
        # Pattern 1: <think>...</think> or <thinking>...</thinking>
        think_match = re.search(r'<think(?:ing)?>(.*?)</think(?:ing)?>', text, re.DOTALL | re.IGNORECASE)
        if think_match:
            thinking = think_match.group(1).strip()
            response = re.sub(r'<think(?:ing)?>(.*?)</think(?:ing)?>', '', text, flags=re.DOTALL | re.IGNORECASE).strip()
        
        # Pattern 2: <reasoning>...</reasoning>
        if not thinking:
            reason_match = re.search(r'<reasoning>(.*?)</reasoning>', text, re.DOTALL | re.IGNORECASE)
            if reason_match:
                thinking = reason_match.group(1).strip()
                response = re.sub(r'<reasoning>(.*?)</reasoning>', '', text, flags=re.DOTALL | re.IGNORECASE).strip()
        
        # Pattern 3: Internal monologue style (DeepSeek-R1 uses this sometimes)
        if not thinking:
            internal_match = re.search(r'\*\*Internal Thoughts?\*\*:?\s*(.*?)(?=\*\*Response\*\*|\*\*Answer\*\*|$)', text, re.DOTALL | re.IGNORECASE)
            if internal_match:
                thinking = internal_match.group(1).strip()
                response = re.sub(r'\*\*Internal Thoughts?\*\*:?.*?(?=\*\*Response\*\*|\*\*Answer\*\*)', '', text, flags=re.DOTALL | re.IGNORECASE)
                response = re.sub(r'\*\*(?:Response|Answer)\*\*:?\s*', '', response, flags=re.IGNORECASE).strip()
        
        return thinking, response
    
    async def chat(self, message_data, stream_callback=None, thinking_callback=None):
        """
        Send a chat message and get a response.
        
        Args:
            message_data: Dict with player info and message text
            stream_callback: Async function to call with each streamed response chunk
            thinking_callback: Async function to call with thinking content (optional)
            
        Returns:
            Dict with response and any tool calls
        """
        player_id = message_data.get("player", {}).get("steamid", "unknown")
        user_message = self._build_user_message(message_data)
        
        if DEBUG:
            print(f"[LM Client] User message: {user_message[:200]}...")
            if THINKING_MODEL:
                print(f"[LM Client] Thinking model mode enabled (show_thinking={SHOW_THINKING})")
        
        self._add_message(player_id, "user", user_message)
        
        try:
            # Build API parameters
            params = self._build_api_params()
            params["messages"] = self._get_conversation(player_id)
            params["stream"] = STREAM_RESPONSES and stream_callback is not None
            
            # Make the API call with retry logic for rate limits
            response = self._api_call_with_retry(params)
            
            if STREAM_RESPONSES and stream_callback is not None:
                return await self._handle_streaming_response(
                    response, player_id, stream_callback, thinking_callback
                )
            else:
                return self._handle_response(response, player_id, thinking_callback)
                
        except Exception as e:
            error_str = str(e)
            print(f"[LM Client] Error: {error_str}")
            # Provide user-friendly message for rate limits
            if "429" in error_str or "rate" in error_str.lower():
                return {"error": "Rate limited by AI provider. Please wait a moment and try again."}
            return {"error": error_str}
    
    def _api_call_with_retry(self, params):
        """Make API call with retry logic for rate limits."""
        last_error = None
        for attempt in range(MAX_RETRIES):
            try:
                return self.client.chat.completions.create(**params)
            except Exception as e:
                error_str = str(e)
                if "429" in error_str or "rate" in error_str.lower() or "too_many_requests" in error_str.lower():
                    delay = RETRY_BASE_DELAY * (2 ** attempt)
                    if DEBUG:
                        print(f"[LM Client] Rate limited, retrying in {delay}s (attempt {attempt + 1}/{MAX_RETRIES})")
                    time.sleep(delay)
                    last_error = e
                else:
                    raise e
        raise last_error
    
    def _handle_response(self, response, player_id, thinking_callback=None):
        """Handle a non-streaming response."""
        message = response.choices[0].message
        
        # Check for tool calls
        if message.tool_calls:
            tool_calls = []
            for tc in message.tool_calls:
                if DEBUG:
                    print(f"[LM Client] Raw tool call from API - id: {tc.id}, function: {tc.function.name}")
                
                try:
                    args = json.loads(tc.function.arguments) if tc.function.arguments else {}
                except json.JSONDecodeError:
                    args = {}
                    
                tool_calls.append({
                    "id": tc.id,
                    "name": tc.function.name,
                    "arguments": args
                })
            
            # Get content and extract thinking if applicable
            content = message.content or ""
            
            if THINKING_MODEL:
                thinking, clean_content = self._extract_thinking_and_response(content)
                if thinking and DEBUG:
                    print(f"[LM Client] Thinking detected: {thinking[:200]}...")
                content = clean_content
            
            # Add assistant message WITH tool_calls to history (required by OpenAI API)
            self._add_assistant_message_with_tool_calls(player_id, content, tool_calls)
            
            if DEBUG:
                print(f"[LM Client] Tool calls detected: {[tc['name'] for tc in tool_calls]}")
            
            return {
                "type": "tool_calls",
                "tool_calls": tool_calls,
                "text": self._clean_response_text(content)
            }
        
        # Regular text response
        text = message.content or ""
        
        # Extract thinking if in thinking model mode
        thinking = None
        if THINKING_MODEL:
            thinking, text = self._extract_thinking_and_response(text)
            if thinking and DEBUG:
                print(f"[LM Client] Thinking: {thinking[:200]}...")
        
        self._add_message(player_id, "assistant", text)
        
        # Clean the text before returning
        clean_text = self._clean_response_text(text)
        
        result = {
            "type": "response",
            "text": clean_text
        }
        
        if thinking and SHOW_THINKING:
            result["thinking"] = thinking
        
        return result
    
    async def _handle_streaming_response(self, response, player_id, stream_callback, thinking_callback=None):
        """Handle a streaming response with support for thinking models."""
        collected_content = ""
        collected_tool_calls = {}
        in_thinking = False
        thinking_buffer = ""
        response_buffer = ""
        
        for chunk in response:
            delta = chunk.choices[0].delta if chunk.choices else None
            
            if delta is None:
                continue
                
            # Handle text content
            if delta.content:
                collected_content += delta.content
                
                if THINKING_MODEL:
                    # Check if we're entering thinking mode
                    if not in_thinking and ('<think' in collected_content.lower() or '<reasoning>' in collected_content.lower()):
                        in_thinking = True
                    
                    # Check if we're exiting thinking mode
                    if in_thinking and ('</think' in collected_content.lower() or '</reasoning>' in collected_content.lower()):
                        in_thinking = False
                        # Extract and send thinking if configured
                        thinking, response = self._extract_thinking_and_response(collected_content)
                        if thinking and SHOW_THINKING and thinking_callback:
                            await thinking_callback(thinking)
                        # Stream the response part
                        if response:
                            await stream_callback(response)
                        continue
                    
                    # If in thinking mode, optionally stream thinking
                    if in_thinking:
                        if SHOW_THINKING and thinking_callback:
                            await thinking_callback(delta.content)
                    else:
                        # Not in thinking, just stream normally
                        # But wait to make sure we're not about to enter thinking
                        if not any(tag in collected_content.lower() for tag in ['<think', '<reasoning>']):
                            await stream_callback(delta.content)
                else:
                    # Non-thinking model, stream directly
                    await stream_callback(delta.content)
            
            # Handle tool calls (streamed incrementally)
            if delta.tool_calls:
                for tc in delta.tool_calls:
                    idx = tc.index
                    if idx not in collected_tool_calls:
                        collected_tool_calls[idx] = {
                            "id": "",
                            "name": "",
                            "arguments": ""
                        }
                    
                    if tc.id:
                        collected_tool_calls[idx]["id"] = tc.id
                    if tc.function:
                        if tc.function.name:
                            collected_tool_calls[idx]["name"] = tc.function.name
                        if tc.function.arguments:
                            collected_tool_calls[idx]["arguments"] += tc.function.arguments
        
        # Process final content - extract thinking if present
        final_text = collected_content
        thinking = None
        if THINKING_MODEL:
            thinking, final_text = self._extract_thinking_and_response(collected_content)
        
        # Process tool calls if any
        if collected_tool_calls:
            tool_calls = []
            for idx in sorted(collected_tool_calls.keys()):
                tc = collected_tool_calls[idx]
                try:
                    args = json.loads(tc["arguments"]) if tc["arguments"] else {}
                except json.JSONDecodeError:
                    args = {}
                
                tool_calls.append({
                    "id": tc["id"],
                    "name": tc["name"],
                    "arguments": args
                })
            
            # Add assistant message WITH tool_calls to history (required by OpenAI API)
            self._add_assistant_message_with_tool_calls(player_id, final_text, tool_calls)
            
            if DEBUG:
                print(f"[LM Client] Streaming: Tool calls detected: {[tc['name'] for tc in tool_calls]}")
            
            result = {
                "type": "tool_calls",
                "tool_calls": tool_calls,
                "text": self._clean_response_text(final_text)
            }
            if thinking and SHOW_THINKING:
                result["thinking"] = thinking
            return result
        
        # No tool calls - add regular assistant message
        self._add_message(player_id, "assistant", final_text)
        
        # Clean the text before returning
        clean_text = self._clean_response_text(final_text)
        
        result = {
            "type": "response",
            "text": clean_text
        }
        if thinking and SHOW_THINKING:
            result["thinking"] = thinking
        return result
    
    def add_tool_result(self, player_id, tool_call_id, tool_name, result):
        """Add a tool result to the conversation for context."""
        conv = self._get_conversation(player_id)
        
        # Add tool result message
        conv.append({
            "role": "tool",
            "tool_call_id": tool_call_id,
            "name": tool_name,
            "content": json.dumps(result)
        })
    
    async def continue_after_tools(self, player_id, stream_callback=None, thinking_callback=None):
        """Continue the conversation after tool results have been added."""
        try:
            params = self._build_api_params()
            params["messages"] = self._get_conversation(player_id)
            params["stream"] = STREAM_RESPONSES and stream_callback is not None
            
            # Use retry logic for rate limits
            response = self._api_call_with_retry(params)
            
            if STREAM_RESPONSES and stream_callback is not None:
                return await self._handle_streaming_response(
                    response, player_id, stream_callback, thinking_callback
                )
            else:
                return self._handle_response(response, player_id, thinking_callback)
                
        except Exception as e:
            error_str = str(e)
            print(f"[LM Client] Error in continue: {error_str}")
            # Provide user-friendly message for rate limits
            if "429" in error_str or "rate" in error_str.lower():
                return {"error": "Rate limited by AI provider. Please wait a moment and try again."}
            return {"error": error_str}
    
    def clear_conversation(self, player_id):
        """Clear a player's conversation history."""
        if player_id in self.conversations:
            del self.conversations[player_id]
    
    def clear_all_conversations(self):
        """Clear all conversation histories."""
        self.conversations = {}
