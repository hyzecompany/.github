#!/usr/bin/env bash
# Mesmo que status.ps1, para shells bash (usado pelo Claude do Cowork).
cd "$(dirname "$0")" || exit 1
for d in */ .github/; do
  [ -d "$d/.git" ] || continue
  echo; echo "=== ${d%/} ==="
  git -C "$d" status --short
  git -C "$d" log --oneline "@{u}..HEAD" 2>/dev/null | sed 's/^/sem push: /'
  git -C "$d" log --oneline -3 --format="%h %ad %s" --date=format:"%d/%m %H:%M"
done
