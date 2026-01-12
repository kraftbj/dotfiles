#!/usr/bin/env python3
"""
Claude Code Hook: Save Session Summary (SessionEnd)

Uses the Claude Agent SDK to summarize sessions with Haiku.
"""

import json
import sys
from datetime import datetime
from pathlib import Path

from claude_agent_sdk import query, ClaudeAgentOptions, ResultMessage


LOG_DIR = Path.home() / ".claude" / "session-logs"


def parse_transcript(transcript_path: str) -> str:
    """Parse JSONL transcript into readable format."""
    path = Path(transcript_path)
    if not path.exists():
        return ""

    messages = []
    with open(path) as f:
        for line in f:
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
                msg_type = entry.get("type")
                if msg_type in ("user", "assistant"):
                    content = entry.get("message", {}).get("content", "")
                    if isinstance(content, list):
                        content = " ".join(
                            b.get("text", "") if isinstance(b, dict) else str(b)
                            for b in content
                        )
                    if content:
                        role = "User" if msg_type == "user" else "Assistant"
                        messages.append(f"{role}: {content}")
            except json.JSONDecodeError:
                continue

    return "\n\n".join(messages)


async def summarize_session(transcript: str) -> str:
    """Call Haiku to summarize the session."""
    prompt = f"""Summarize this Claude Code session in 1-2 paragraphs. Focus on what was accomplished, key decisions made, and any notable outcomes. Do not include a header - just provide the summary text directly.

<transcript>
{transcript}
</transcript>"""

    options = ClaudeAgentOptions(
        model="haiku",
        max_turns=1,
        system_prompt="You are a session summarizer. Be concise.",
    )

    async for message in query(prompt=prompt, options=options):
        if isinstance(message, ResultMessage):
            if message.is_error:
                return f"Summary failed: {message.result}"
            return message.result

    return "No summary generated"


async def main():
    # Read hook input from stdin
    input_data = json.load(sys.stdin)

    session_id = input_data.get("session_id", "unknown")
    transcript_path = input_data.get("transcript_path", "")
    cwd = input_data.get("cwd", "")

    # Parse transcript
    transcript = parse_transcript(transcript_path)
    if not transcript:
        print("No transcript to summarize")
        return

    # Summarize with Haiku
    summary = await summarize_session(transcript)

    # Write to file
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().isoformat()
    log_file = LOG_DIR / f"{session_id}.md"

    content = f"""# Session {session_id}

**Date:** {timestamp}
**Directory:** {cwd}

## Summary

{summary}
"""

    log_file.write_text(content)
    print(f"Session summary saved to {log_file}")


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
