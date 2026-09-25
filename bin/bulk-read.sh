#!/usr/bin/env bash
# bulk-read.sh <file> [file...] "<question>"
# Sends files plus a question to Haiku in headless mode and prints bullet
# answers only. Keeps large file bodies out of the main session's context.
#
# BULK_READ_MODEL overrides the model (default: haiku).

set -uo pipefail
if [ "$#" -lt 2 ]; then
  echo "usage: $0 <file> [file...] \"<question>\"" >&2
  exit 2
fi

question="${@: -1}"
set -- "${@:1:$#-1}"
model="${BULK_READ_MODEL:-haiku}"

payload="$(
  for f in "$@"; do
    f="${f/#\~/$HOME}"
    if [ ! -f "$f" ]; then echo "bulk-read: not a file: $f" >&2; exit 2; fi
    printf '<file path="%s">\n' "$f"
    cat "$f"
    printf '\n</file>\n'
  done
)" || exit 2

prompt="You are a file reader for another engineer. Answer the question using only the files below.
Rules: terse bullet points only, no prose, no preamble, no markdown headers or code fences.
Cite line numbers or symbol names when useful. If the answer is not in the files, say so in one bullet.

Question: $question

$payload"

printf '%s' "$prompt" | claude -p --model "$model" --output-format text 2>/dev/null
rc=$?
[ $rc -ne 0 ] && echo "bulk-read: claude exited $rc" >&2
exit $rc
