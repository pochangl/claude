#!/usr/bin/env bash
# Minimal Trello checklist helper. Credentials are per repo: the file
# ~/.config/trello/<repo>.env (repo = basename of the git toplevel) must export
# TRELLO_KEY and TRELLO_TOKEN, and may export TRELLO_CARD as the default card.
# They are never echoed.
#
# Writes only touch cards sitting in a whitelisted board/list pair, set in the
# same env file as a bash array (board = short id from https://trello.com/b/<board>/...
# or full id; list = name or full id). Unset or empty means every write is refused.
#   TRELLO_WRITE_LISTS=("abc123/進行中" "def456/Done")
#
#   trello.sh env                             # show which env file this repo uses
#   trello.sh me                              # verify credentials (prints username)
#   trello.sh card [card]                     # card name, board/list, writable?, checklists
#   trello.sh items <checklist-id>            # existing items, one per line: [x]/[ ] name
#   trello.sh add <checklist-id> < items.txt  # add one item per non-blank stdin line
#   trello.sh create-checklist [card] <name>  # create a checklist on the card, prints its id
#   trello.sh board <board>                   # open lists and cards with descriptions/checklists
#   trello.sh create-card <board>/<list> < cards.tsv  # one card per line: name<TAB>description
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
  echo '  TRELLO_WRITE_LISTS=("<board>/<list>")  # writable board/list pairs' >&2
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

# Sets board_id, board_short, board_name, list_id, list_name for the card.
card_location() {
  local out
  out=$(api GET "/cards/$1?$AUTH&fields=idBoard,idList&board=true&board_fields=shortLink,name&list=true&list_fields=name")
  IFS=$'\t' read -r board_id board_short board_name list_id list_name < <(
    printf '%s' "$out" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("\t".join([d["idBoard"], d["board"]["shortLink"], d["board"]["name"], d["idList"], d["list"]["name"]]))
')
}

# Expects card_location to have run for the card.
location_writable() {
  local pair b l
  for pair in ${TRELLO_WRITE_LISTS[@]+"${TRELLO_WRITE_LISTS[@]}"}; do
    b=${pair%%/*}
    l=${pair#*/}
    if [[ ($b == "$board_id" || $b == "$board_short") && ($l == "$list_id" || $l == "$list_name") ]]; then
      return 0
    fi
  done
  return 1
}

require_writable_card() {
  card_location "$1"
  location_writable || {
    echo "refused: card is in board \"$board_name\" ($board_short) / list \"$list_name\", not in TRELLO_WRITE_LISTS of $ENV_FILE" >&2
    exit 1
  }
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
    card_location "$card"
    if location_writable; then writable=yes; else writable=no; fi
    printf '%s' "$out" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(f"{d['"'"'name'"'"']}  {d['"'"'shortUrl'"'"']}")
print(f"  board/list: {sys.argv[1]}/{sys.argv[2]}  writable: {sys.argv[3]}")
for c in d.get("checklists", []):
    print(f"  {c['"'"'id'"'"']}  {c['"'"'name'"'"']}  ({len(c['"'"'checkItems'"'"'])} items)")
' "$board_short" "$list_name" "$writable"
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
  board)
    board=${1:?board short id}
    out=$(api GET "/boards/$board?$AUTH&fields=name,url&lists=open&list_fields=name,pos&cards=open&card_fields=name,desc,idList,labels,due,shortUrl,pos&checklists=all&checklist_fields=name,idCard")
    printf '%s' "$out" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("# " + d["name"] + "  " + d["url"])
checklists = {}
for c in d.get("checklists", []):
    checklists.setdefault(c["idCard"], []).append(c)
for l in sorted(d["lists"], key=lambda l: l["pos"]):
    cards = sorted((c for c in d["cards"] if c["idList"] == l["id"]), key=lambda c: c["pos"])
    print("\n## %s  [%s]  (%d cards)" % (l["name"], l["id"], len(cards)))
    for c in cards:
        labels = ", ".join(x["name"] or x["color"] for x in c["labels"])
        line = "\n### " + c["name"] + "  " + c["shortUrl"]
        if labels: line += "  labels: " + labels
        if c["due"]: line += "  due: " + c["due"]
        print(line)
        if c["desc"]: print(c["desc"])
        for cl in checklists.get(c["id"], []):
            print("  - checklist: " + cl["name"])
            for i in sorted(cl["checkItems"], key=lambda i: i["pos"]):
                print(("    [x] " if i["state"] == "complete" else "    [ ] ") + i["name"])
'
    ;;
  add)
    checklist=${1:?checklist id}
    out=$(api GET "/checklists/$checklist?$AUTH&fields=idCard")
    require_writable_card "$(printf '%s' "$out" | python3 -c 'import sys,json; print(json.load(sys.stdin)["idCard"])')"
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "${line// }" ] && continue
      api POST "/checklists/$checklist/checkItems?$AUTH" --data-urlencode "name=$line" >/dev/null
      n=$((n + 1))
      echo "added: $line"
    done
    echo "$n item(s) added"
    ;;
  create-card)
    target=${1:?board/list}
    board=${target%%/*}
    list=${target#*/}
    out=$(api GET "/boards/$board?$AUTH&fields=name,shortLink&lists=open&list_fields=name")
    IFS=$'\t' read -r board_id board_short board_name list_id list_name < <(
      printf '%s' "$out" | python3 -c '
import sys, json
d = json.load(sys.stdin)
for l in d["lists"]:
    if sys.argv[1] in (l["id"], l["name"]):
        print("\t".join([d["id"], d["shortLink"], d["name"], l["id"], l["name"]]))
        break
else:
    sys.exit("no open list \"%s\" on board %s" % (sys.argv[1], d["name"]))
' "$list")
    location_writable || {
      echo "refused: board \"$board_name\" ($board_short) / list \"$list_name\" is not in TRELLO_WRITE_LISTS of $ENV_FILE" >&2
      exit 1
    }
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "${line// }" ] && continue
      name=${line%%$'\t'*}
      desc=""
      [[ $line == *$'\t'* ]] && desc=${line#*$'\t'}
      api POST "/cards?$AUTH" --data-urlencode "idList=$list_id" --data-urlencode "pos=bottom" \
        --data-urlencode "name=$name" --data-urlencode "desc=$desc" >/dev/null
      n=$((n + 1))
      echo "created: $name"
    done
    echo "$n card(s) created"
    ;;
  create-checklist)
    if [ $# -ge 2 ]; then card=$1; name=$2; else card=${TRELLO_CARD:-}; name=${1:?checklist name}; fi
    [ -n "$card" ] || { echo "no card given and TRELLO_CARD not set in $ENV_FILE" >&2; exit 1; }
    require_writable_card "$card"
    out=$(api POST "/cards/$card/checklists?$AUTH" --data-urlencode "name=$name")
    printf '%s' "$out" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])'
    ;;
  *)
    sed -n '2,22p' "$0" >&2
    exit 1
    ;;
esac
