---
category: workflow
---
# /csession — Compress and Summarize This Session

Compress the current conversation context so it fits cleanly into a new session
or a continuation prompt. Use this when the session is getting long and you want
to start fresh without losing important context.

Usage:
  /csession             — compress and summarize this entire session
  /csession $ARGUMENTS  — compress pasted transcript from $ARGUMENTS

Instructions for Claude:
1. If $ARGUMENTS is provided (pasted transcript), write it to a temp file and run:
     python3 ~/ctx_compress.py --mode chat --keep-turns 6
2. If no $ARGUMENTS, produce a handoff summary of THIS conversation containing:

   ## Session Handoff Summary
   **Goal:** <what the user was trying to accomplish>
   **Stack/Context:** <tech stack, environment, tools mentioned>
   **What was tried:** <bullet list of approaches, commands run>
   **Current state:** <where things stand right now>
   **Blockers:** <what's still unresolved>
   **Next step:** <what to do next>
   **Key files/resources:** <any file paths, URLs, pod names, etc. referenced>

3. Tell the user: "Copy this block and paste it at the start of your next session
   with: 'Continue from this context: <block>'"
4. Keep the summary under 40 lines — dense and structured, not narrative.
