#!/usr/bin/env bash
# release-snapshot.sh - what a USGS software release will contain, and the path and secret scan that decides whether it can go.
#
# Usage: tools/release-snapshot.sh --scan-only [--with-dev] [--ref=<commit or tree>]
#        tools/release-snapshot.sh <empty folder outside this repository> [--with-dev] [--ref=<commit or tree>]
#        tools/release-snapshot.sh --sync=<the release repository> [--message="<text>"] [--with-dev] [--ref=<commit or tree>]
#
# Of dev/, only the files in tools/release-dev-files.txt go (--with-dev keeps all of it).
# With a folder: extracts the commit (HEAD by default) without the files listed in EXCLUDE, scans it, and on a clean scan makes
# it a new git repository with one commit. Pushing it is left to you. The repository this runs in is not changed.
# With --sync: makes an existing release repository match the commit, as one new commit on its main branch, after a clean scan.
# It refuses a release repository with uncommitted work, off main, or with a release candidate branch (a name like 1.1.0): from
# Request Peer Review on, changes go on that branch where reviewers can follow them. Pushing is left to you.
# Exit status: 0 clean, 1 something to look at, 2 wrong use.
set -u
REF=HEAD; OUT=""; DEV=0; SYNC=""; MSG=""
for a in "$@"; do case "$a" in
  --scan-only) ;;
  --with-dev) DEV=1 ;;
  --ref=*) REF="${a#--ref=}" ;;
  --sync=*) SYNC="${a#--sync=}" ;;
  --message=*) MSG="${a#--message=}" ;;
  -*) echo "unknown option $a" >&2; exit 2 ;;
  *) OUT="$a" ;;
esac; done

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 2
if [ -n "$SYNC" ]; then
  [ -z "$OUT" ] || { echo "give a folder or --sync, not both" >&2; exit 2; }
  [ -e "$SYNC/.git" ] || { echo "$SYNC is not a git repository" >&2; exit 2; }
  SYNC="$(git -C "$SYNC" rev-parse --show-toplevel)" || exit 2
  [ "$SYNC" != "$ROOT" ] || { echo "--sync must name the release repository, not this one" >&2; exit 2; }
  [ -z "$(git -C "$SYNC" status --porcelain)" ] || { echo "$SYNC has uncommitted work: commit or discard it first" >&2; exit 2; }
  [ "$(git -C "$SYNC" branch --show-current)" = main ] || { echo "$SYNC is not on main" >&2; exit 2; }
  RC="$(git -C "$SYNC" for-each-ref --format='%(refname:short)' refs/heads refs/remotes refs/tags | grep -E '(^|/)[0-9]+\.[0-9]+\.[0-9]+$')"
  [ -z "$RC" ] || { echo "$SYNC has a release candidate ($RC): make further changes on that branch, where reviewers can follow them" >&2; exit 2; }
  [ -n "$MSG" ] || MSG="Update from the development repository ($(git -C "$ROOT" rev-parse --short "$REF"))"
fi
# development records that are not part of the software
EXCLUDE=("docs/guide/source" "docs/guide/build-guide.R" "docs/How to Publish a Software Release.txt")

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
git -C "$ROOT" archive --format=tar "$REF" | tar -x -C "$WORK" || exit 2
for e in "${EXCLUDE[@]}"; do rm -rf "$WORK/$e"; done
cd "$WORK" || exit 2
if [ "$DEV" != 1 ]; then
  [ -f tools/release-dev-files.txt ] || { echo "no tools/release-dev-files.txt in $REF" >&2; exit 2; }
  KEEP="$(mktemp)"; tr -d '\r' < tools/release-dev-files.txt | grep -v '^#' | sort > "$KEEP"
  find dev -type f | sort | comm -23 - "$KEEP" | while IFS= read -r f; do rm -f "$f"; done
  comm -13 <(find dev -type f | sort) "$KEEP" | sed 's/^/listed but not in the commit: /' >&2
  find dev -type d -empty -delete; rm -f "$KEEP"
fi

BADFILE="$(mktemp)"; trap 'rm -rf "$WORK" "$BADFILE"' EXIT
report() { # title, then matching lines on stdin. Runs at the end of a pipe, in a subshell, so a finding is kept in a file
  local n; n="$(cat)"; if [ -n "$n" ]; then echo "--- $1"; echo "$n" | cut -c1-180; echo x >> "$BADFILE"; else echo "ok  $1"; fi; }
TEXT=(--include='*' --exclude='*.png' --exclude='*.dll' --exclude='*.shp' --exclude='*.shx' --exclude='*.dbf' --exclude='*.rds')

# Allowed: default install folders of public software, made-up paths inside test fixtures, and this script's own patterns
grep -rInE '\b[A-Za-z]:[/\\]{1,2}[A-Za-z0-9_]{2,}' "${TEXT[@]}" . \
  | grep -vE '[A-Za-z]:[/\\]{1,2}Program Files|C:[/\\]+PROGRA|[A-Za-z]:[/\\]{1,2}(example|nowhere|another-machine|tools/(env|page|opt)|no/such|x/y|path/)|^\./tools/release-snapshot\.sh' \
  | report "absolute paths"
grep -rInE '(Users|home)[/\\]+[a-z][a-z0-9._-]+[/\\]' "${TEXT[@]}" . | grep -v '^\./tools/release-snapshot\.sh' | report "home folders"
grep -rInE '\b(10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)\b|\.(chs|cr)\.usgs\.gov|\.doi\.net|\.local\b' "${TEXT[@]}" . \
  | grep -v '^\./tools/release-snapshot\.sh' | grep -v 'dmsdata\.cr\.usgs\.gov' | report "internal hosts and addresses"
grep -rInE 'eyJ[A-Za-z0-9_-]{20,}|glpat-[A-Za-z0-9_-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{12,}|-----BEGIN [A-Z ]*PRIVATE KEY|(password|passwd|secret|api[_-]?key|token)[[:space:]]*[=:][[:space:]]*["'"'"'][^"'"'"' ]{8,}' "${TEXT[@]}" . \
  | grep -v '^\./tools/release-snapshot\.sh' | report "tokens and passwords"
grep -rInE '[A-Za-z0-9._%+-]+@(gmail|yahoo|hotmail|outlook|icloud)\.[a-z]+' "${TEXT[@]}" . | grep -v '^\./tools/release-snapshot\.sh' | report "personal email addresses"
grep -rIln 'claude\.ai/' "${TEXT[@]}" . | report "links to private Claude documents"
grep -rIlE 'github\.com/[A-Za-z0-9_-]+/lucasCore|\.github\.io/lucasCore' "${TEXT[@]}" . | grep -v '^\./tools/release-snapshot\.sh' | report "links to the old GitHub repository"
for f in README.md code.json LICENSE.md DISCLAIMER.md CHANGELOG.md CONTRIBUTING.md; do [ -f "$f" ] || echo "missing $f" ; done | report "required files"
# Files the software relies on must not name a dev/ file this snapshot leaves out. A number range such as dev/fia/22-24 names scripts; the fits file is made by a script that ships.
grep -rIoE '\bdev/[a-z]+(/[A-Za-z0-9_.-]+)*' src defaults tools docs/carbon-assumptions.md docs/carbon-build-process.md README.md 2>/dev/null | grep -vE '^tools/release-|dev/(libs|null)\b' \
  | while IFS=: read -r src ref; do r="${ref%.}"; case "$r" in dev/climate/itrdb-full-site-fits.csv) continue ;; esac; [ -e "$r" ] && continue; b="${r##*/}"; printf '%s\n' "$b" | grep -qE '^[0-9]+-[0-9]+$' && continue; echo "$src -> $r"; done | sort -u | report "references to dev/ files this snapshot leaves out"

echo "files: $(find . -type f | wc -l)  size: $(du -sh . | cut -f1)  images to check by eye: $(find . -name '*.png' | wc -l)"
BAD=0; [ -s "$BADFILE" ] && BAD=1
if [ -n "$SYNC" ]; then
  if [ "$BAD" != 0 ]; then echo "not syncing: see above. $SYNC is unchanged" >&2; exit 1; fi
  find "$SYNC" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -a . "$SYNC"/ && cd "$SYNC" && git add -A || exit 2
  if git diff --cached --quiet; then echo "$SYNC already matches $REF: nothing to commit"; exit 0; fi
  git commit -q -m "$MSG" || exit 2
  git log -1 --format="committed %h %s" | cut -c1-120; git show --stat --format= HEAD | tail -1
  echo "Look it over with: git -C \"$SYNC\" show --stat. Then push it with: git -C \"$SYNC\" push"
  exit 0
fi
if [ -z "$OUT" ]; then exit "$BAD"; fi
if [ "$BAD" != 0 ]; then echo "not making a repository: see above" >&2; exit 1; fi
mkdir -p "$OUT" && [ -z "$(ls -A "$OUT")" ] || { echo "$OUT must be an empty folder" >&2; exit 2; }
cp -a . "$OUT"/ && cd "$OUT" && git init -q -b main && git add -A && git commit -q -m "lucasCore: first commit for USGS software release review" && git log --oneline
