#!/bin/bash
# Send a rendered screenshot to the user's Telegram as a DOCUMENT (not a path).
# Usage: bash tools/send_shot.sh /path/to/image.png "caption"
IMG="$1"
CAP="${2:-Muakbank Zombie render}"
if [ ! -f "$IMG" ]; then echo "MISSING: $IMG"; exit 1; fi
TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' ~/.hermes/.env | grep -v '^#' | cut -d= -f2 | tr -d '\n\r ')
CID=$(grep '^TELEGRAM_CHAT_ID=' ~/.hermes/.env 2>/dev/null | grep -v '^#' | cut -d= -f2 | tr -d '\n\r ')
CID="${CID:-8382253048}"
SZ=$(stat -c %s "$IMG")
echo "sending $IMG ($SZ bytes) ..."
curl -s -F "chat_id=${CID}" -F "document=@${IMG}" -F "caption=${CAP}" \
  "https://api.telegram.org/bot${TOKEN}/sendDocument" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('ok') else 'FAIL: '+str(d)[:200])"
