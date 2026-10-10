#!/usr/bin/env python3
"""AstroWizard activation codes.

  python tools/make_code.py --new-secret          # print a fresh random secret
  python tools/make_code.py 30  --secret XXXXX    # one code worth 30 days
  python tools/make_code.py 365 --secret XXXXX -n 5

The same secret must be (1) a GitHub Actions secret named AW_SECRET (the app is
built with it) and (2) in the WordPress snippet that issues codes.

Code layout (12 bytes -> 20 Crockford base32 chars, shown as XXXXX-XXXXX-XXXXX-XXXXX):
  days (2 bytes) | issue day (2 bytes, days since 2024-01-01 UTC) | id (3 bytes) | HMAC-SHA256(secret, first 7 bytes)[:5]
The app accepts a code for 60 days after it was issued.
"""
import argparse, datetime, hashlib, hmac, secrets, sys

ALPHA = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
EPOCH = datetime.date(2024, 1, 1)


def b32(data: bytes) -> str:
    bits = "".join(f"{b:08b}" for b in data)
    bits += "0" * (-len(bits) % 5)
    return "".join(ALPHA[int(bits[i:i + 5], 2)] for i in range(0, len(bits), 5))


def make_code(secret: str, days: int, issue_day: int, ident: int) -> str:
    assert 1 <= days <= 65535
    payload = days.to_bytes(2, "big") + issue_day.to_bytes(2, "big") + ident.to_bytes(3, "big")
    mac = hmac.new(secret.encode(), payload, hashlib.sha256).digest()[:5]
    c = b32(payload + mac)
    return "-".join(c[i:i + 5] for i in range(0, 20, 5))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("days", nargs="?", type=int)
    ap.add_argument("--secret")
    ap.add_argument("-n", type=int, default=1)
    ap.add_argument("--new-secret", action="store_true")
    a = ap.parse_args()
    if a.new_secret:
        print(secrets.token_urlsafe(32))
        return
    if not a.days or not a.secret:
        sys.exit("usage: make_code.py DAYS --secret SECRET [-n COUNT]")
    issue = (datetime.datetime.now(datetime.timezone.utc).date() - EPOCH).days
    for _ in range(a.n):
        print(make_code(a.secret, a.days, issue, secrets.randbits(24)))


if __name__ == "__main__":
    main()
