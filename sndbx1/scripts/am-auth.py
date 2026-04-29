#!/usr/bin/env python3
"""Helper: authenticate to PingAM, print tokenId to stdout."""
import sys, json, urllib.request

AM = "http://pingam:8081/am"

def authenticate(realm="/", username="amadmin", password="changeit"):
    base = f"{AM}/json/realms/root/authenticate" if realm == "/" else f"{AM}/json/realms/root/realms/{realm}/authenticate"
    hdrs = {"Content-Type": "application/json", "Accept-API-Version": "resource=2.0, protocol=1.0"}

    req1 = urllib.request.Request(base, data=b'{}', headers=hdrs, method='POST')
    r1 = json.loads(urllib.request.urlopen(req1).read())

    callbacks = r1['callbacks']
    for cb in callbacks:
        if cb['type'] == 'NameCallback':
            cb['input'][0]['value'] = username
        elif cb['type'] == 'PasswordCallback':
            cb['input'][0]['value'] = password

    body = json.dumps({'authId': r1['authId'], 'callbacks': callbacks}).encode()
    req2 = urllib.request.Request(base, data=body, headers=hdrs, method='POST')
    r2 = json.loads(urllib.request.urlopen(req2).read())
    return r2.get("tokenId")

if __name__ == "__main__":
    user = sys.argv[1] if len(sys.argv) > 1 else "amadmin"
    pwd = sys.argv[2] if len(sys.argv) > 2 else "changeit"
    realm = sys.argv[3] if len(sys.argv) > 3 else "/"
    token = authenticate(realm, user, pwd)
    if token:
        print(token)
    else:
        print("FAILED", file=sys.stderr)
        sys.exit(1)
