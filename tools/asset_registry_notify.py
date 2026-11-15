"""Standardized telemetry webhook notifier for the asset registry / regression
failure routine.

Posts a conformant event (type/severity/name/value/ts) to the telemetry relay
(POST :8095/telemetry, returns 202) which fans out to Node-RED / Telegram.

FAIL-OPEN by design: a webhook outage must NEVER break the build. On any failure
it prints one WARN line to stderr and exits 0. The registry verdict itself is the
authoritative gate (check_asset_registry.py). Env overrides:
  TELEMETRY_RELAY_URL (default http://10.9.0.1:8095/telemetry).
"""
from __future__ import annotations
import argparse, json, os, sys, urllib.request
from datetime import datetime, timezone

DEFAULT_URL = os.environ.get("TELEMETRY_RELAY_URL", "http://10.9.0.1:8095/telemetry")


def utcnow():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def send(severity, name, value, url, timeout=8.0):
    event = {"type": "event", "severity": severity, "name": name, "value": value,
             "ts": utcnow(), "src": "muakbank_zombie.asset_registry"}
    data = json.dumps(event).encode("utf-8")
    req = urllib.request.Request(url, data=data,
                                 headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.status


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--severity", default="info",
                    choices=["info", "warning", "error", "critical"])
    ap.add_argument("--name", required=True)
    ap.add_argument("--value", default="{}")
    ap.add_argument("--url", default=DEFAULT_URL)
    args = ap.parse_args()
    try:
        val = json.loads(args.value)
    except json.JSONDecodeError:
        val = args.value
    try:
        code = send(args.severity, args.name, val, args.url)
        print("WEBHOOK_OK", code, args.name, args.severity)
    except Exception as e:  # noqa: BLE001 - fail open
        sys.stderr.write("WEBHOOK_WARN fail-open: %s: %s\n" % (type(e).__name__, str(e)[:120]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
