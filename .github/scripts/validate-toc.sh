#!/usr/bin/env sh
# Validates CoyFlightline.toc against the files on disk.
#
# Luacheck reads the .lua files it is pointed at and knows nothing about the
# TOC, so it structurally cannot catch either of the two most likely ways to
# ship a broken addon here: a listed file that does not exist (the addon simply
# fails to load in game), or a load-order change that puts something before
# Core.lua (which creates ns.db, ns.Surface and the geometry helpers that every
# other file consumes at file scope).

set -eu

TOC="CoyFlightline.toc"
FIRST_FILE="Core.lua"

status=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  status=1
}

if [ ! -f "$TOC" ]; then
  printf 'FAIL: %s not found (run this from the repository root)\n' "$TOC" >&2
  exit 1
fi

# Strip CRs, drop directives and comments (## Interface:, # comment), drop
# blank lines. What remains is the load list, in order.
files=$(tr -d '\r' < "$TOC" | sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d')

if [ -z "$files" ]; then
  fail "$TOC lists no files to load"
fi

first=""
for file in $files; do
  # TOCs may use Windows separators; the repo checks out with forward slashes.
  path=$(printf '%s' "$file" | tr '\\' '/')
  [ -n "$first" ] || first="$path"
  if [ -f "$path" ]; then
    printf '  ok   %s\n' "$file"
  else
    fail "$TOC lists '$file', which does not exist on disk"
  fi
done

if [ -n "$first" ] && [ "$first" != "$FIRST_FILE" ]; then
  fail "$FIRST_FILE must be loaded first; found '$first'"
fi

# Interface is major * 10000 + minor * 100 + patch, so always six digits here.
interface=$(tr -d '\r' < "$TOC" | sed -n 's/^## Interface:[[:space:]]*//p')
case "$interface" in
  [0-9][0-9][0-9][0-9][0-9][0-9]) printf '  ok   ## Interface: %s\n' "$interface" ;;
  '') fail "$TOC has no ## Interface directive" ;;
  *) fail "## Interface must be six digits; found '$interface'" ;;
esac

if [ "$status" -eq 0 ]; then
  printf '%s is valid.\n' "$TOC"
fi

exit "$status"
