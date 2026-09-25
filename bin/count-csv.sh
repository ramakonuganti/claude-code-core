#!/usr/bin/env bash
# Count rows in a CSV (Rule #9 helper). Source-of-truth count for memory writes.
# Usage:
#   count-csv.sh <file>                   → total data rows (header excluded)
#   count-csv.sh <file> <col> <pattern>   → rows where column matches pattern
#   count-csv.sh <file> --uniq <col>      → unique values in column
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <file> [<col> <pattern>] | $0 <file> --uniq <col>" >&2
  exit 2
fi

file="$1"
shift || true

if [ ! -f "$file" ]; then
  echo "no such file: $file" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  # total rows minus header
  echo $(($(wc -l < "$file") - 1))
elif [ "$1" = "--uniq" ] && [ "$#" -eq 2 ]; then
  col="$2"
  awk -F, -v c="$col" 'NR==1{for(i=1;i<=NF;i++)if($i==c)k=i;next}{print $k}' "$file" | sort -u | wc -l | tr -d ' '
elif [ "$#" -eq 2 ]; then
  col="$1"; pat="$2"
  awk -F, -v c="$col" -v p="$pat" 'NR==1{for(i=1;i<=NF;i++)if($i==c)k=i;next}$k~p' "$file" | wc -l | tr -d ' '
else
  echo "bad args" >&2; exit 2
fi
