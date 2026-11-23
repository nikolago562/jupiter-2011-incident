#!/usr/bin/env bash
# Syntax-checks every Luau file. Needs StyLua: cargo install stylua --features luau
cd "$(dirname "$0")/.." || exit 1
fail=0
for f in $(find src -name "*.luau" | sort); do
  out=$(stylua --syntax luau --check "$f" 2>&1 | grep -A3 "error parsing")
  if [ -n "$out" ]; then echo "== $f"; echo "$out"; fail=1; fi
done
[ $fail -eq 0 ] && echo "All Luau files parse." || exit 1
