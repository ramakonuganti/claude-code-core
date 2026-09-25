---
category: workflow
---
# /clog — Compress a DevOps Log Before Analyzing

Compress a terminal log (kubectl, terraform, helm, git) using ctx_compress.py
in log mode, then analyze it for the root cause.

Usage:
  /clog $ARGUMENTS

$ARGUMENTS can be:
  - A file path:           /clog /tmp/pod.log
  - A kubectl command:     /clog kubectl logs mypod --tail=300
  - A pod name shorthand:  /clog mypod   (runs kubectl logs mypod automatically)

Instructions for Claude:
1. If $ARGUMENTS looks like a file path, run:
     python3 ~/ctx_compress.py --file <path> --mode log --context 4
2. If $ARGUMENTS looks like a kubectl/terraform/helm command, run it and pipe:
     <command> 2>&1 | python3 ~/ctx_compress.py --mode log --context 4
3. If $ARGUMENTS is just a pod name, run:
     kubectl logs <podname> --tail=500 2>&1 | python3 ~/ctx_compress.py --mode log --context 4
4. Show the compressed output block
5. Then perform root cause analysis on the compressed context:
   - Identify the primary error
   - Identify contributing factors
   - Suggest next diagnostic commands
   - Suggest a fix if the cause is clear
