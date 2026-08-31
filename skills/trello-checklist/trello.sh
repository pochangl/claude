#!/usr/bin/env bash
# Minimal Trello checklist helper. Credentials are per repo: the file
# ~/.config/trello/<repo>.env (repo = basename of the git toplevel) must export
# TRELLO_KEY and TRELLO_TOKEN, and may export TRELLO_CARD as the default card.
# They are never echoed.
#
#   trello.sh env                             # show which env file this repo uses
#   trello.sh me                              # verify credentials (prints username)
#   trello.sh card [card]                     # card name + its checklists (id, name, item count)
#   trello.sh items <checklist-id>            # existing items, one per line: [x]/[ ] name
#   trello.sh add <checklist-id> < items.txt  # add one item per non-blank stdin line
#   trello.sh create-checklist [card] <name>  # create a checklist on the card, prints its id
#
# [card] is the short id from the URL (https://trello.com/c/<card>/...) or a full
# card id; when omitted, TRELLO_CARD from the env file is used.
set -euo pipefail

toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not inside a git repo; credentials are resolved per repo" >&2; exit 1; }
repo=$(basename "$toplevel")
ENV_FILE="$HOME/.config/trello/$repo.env"

if [ "${1:-}" = "env" ]; then
  if [ -f "$ENV_FILE" ]; then echo "$ENV_FILE"; else echo "$ENV_FILE (missing)"; fi
  exit 0
fi

[ -f "$ENV_FILE" ] || {
  echo "missing $ENV_FILE — create it (chmod 600) with:" >&2
  echo "  export TRELLO_KEY=...    # https://trello.com/power-ups/admin → API key" >&2
  echo "  export TRELLO_TOKEN=...  # https://trello.com/1/authorize?expiration=never&scope=read,write&response_type=token&name=daily-checklist&key=<KEY>" >&2
  echo "  export TRELLO_CARD=      # optional default card short id" >&2
  exit 1
}
# shellcheck disable=SC1090
source "$ENV_FILE"
[ -n "${TRELLO_KEY:-}" ] && [ -n "${TRELLO_TOKEN:-}" ] || { echo "TRELLO_KEY / TRELLO_TOKEN not set in $ENV_FILE" >&2; exit 1; }

API=https://api.trello.com/1
AUTH="key=$TRELLO_KEY&token=$TRELLO_TOKEN"

# Error output strips the query string: it carries key/token.
api() {
  local method=$1 path=$2; shift 2
  local out code
  out=$(curl -s -X "$method" -w '\n%{http_code}' "$API$path" "$@")
  code=${out##*$'\n'}
  out=${out%$'\n'*}
  if [ "${code:0:1}" != "2" ]; then
    echo "trello API $method ${path%%\?*} failed: HTTP $code $out" >&2
    return 1
  fi
  printf '%s' "$out"
}

cmd=${1:-}; shift || true
case "$cmd" in
  me)
    out=$(api GET "/members/me?$AUTH&fields=username")
    printf '%s' "$out" | python3 -c 'import sys,json; print(json.load(sys.stdin)["username"])'
    ;;
  card)
    card=${1:-${TRELLO_CARD:-}}
    [ -n "$card" ] || { echo "no card given and TRELLO_CARD not set in $ENV_FILE" >&2; exit 1; }
    out=$(api GET "/cards/$card?$AUTH&fields=name,shortUrl&checklists=all&checklist_fields=name")
    printf '%s' "$out" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(f"{d['"'"'name'"'"']}  {d['"'"'shortUrl'"'"']}")
for c in d.get("checklists", []):
    print(f"  {c['"'"'id'"'"']}  {c['"'"'name'"'"']}  ({len(c['"'"'checkItems'"'"'])} items)")
'
    ;;
  items)
    checklist=${1:?checklist id}
    out=$(api GET "/checklists/$checklist/checkItems?$AUTH&fields=name,state,pos")
    printf '%s' "$out" | python3 -c '
import sys, json
for i in sorted(json.load(sys.stdin), key=lambda i: i["pos"]):
    print(("[x] " if i["state"] == "complete" else "[ ] ") + i["name"])
'
    ;;
  add)
    checklist=${1:?checklist id}
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "${line// }" ] && continue
      api POST "/checklists/$checklist/checkItems?$AUTH" --data-urlencode "name=$line" >/dev/null
      n=$((n + 1))
      echo "added: $line"
    done
    echo "$n item(s) added"
    ;;
  create-checklist)
    if [ $# -ge 2 ]; then card=$1; name=$2; else card=${TRELLO_CARD:-}; name=${1:?checklist name}; fi
    [ -n "$card" ] || { echo "no card given and TRELLO_CARD not set in $ENV_FILE" >&2; exit 1; }
    out=$(api POST "/cards/$card/checklists?$AUTH" --data-urlencode "name=$name")
    printf '%s' "$out" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])'
    ;;
  *)
    sed -n '2,15p' "$0" >&2
    exit 1
    ;;
esac
