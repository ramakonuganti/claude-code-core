---
category: workflow
---
# /compress — Context Compressor

Run the ctx_compress.py script on the provided input before processing it.

Usage:
  /compress $ARGUMENTS

The $ARGUMENTS value should be either:
  - Raw text, logs, or a question you want compressed before sending
  - A file path (e.g. /compress /tmp/terraform.log)
  - A mode flag followed by content (e.g. /compress --mode chat <pasted session>)

Instructions for Claude:
1. Take the full $ARGUMENTS string as input
2. Detect if it looks like a file path — if so, run:
     python3 ~/ctx_compress.py --file <path>
   Otherwise write the content to a temp file and run:
     echo "<content>" | python3 ~/ctx_compress.py
3. Show the compressed output block to the user
4. Then ask: "Compressed. What's your question about this?"
5. Use the compressed block as the actual context for the answer — do NOT re-expand it

If $ARGUMENTS is empty, tell the user to paste content after /compress or use --file.
