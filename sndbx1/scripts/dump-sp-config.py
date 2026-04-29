#!/usr/bin/env python3
"""Dump all SP config attributes from partner realm."""
import json, urllib.request, re, sys
sys.path.insert(0, '.')

AM = "http://pingam:8081/am"

# Authenticate
hdrs_auth = {"Content-Type": "application/json", "Accept-API-Version": "resource=2.0, protocol=1.0"}
req1 = urllib.request.Request(f"{AM}/json/realms/root/authenticate", data=b'{}', headers=hdrs_auth, method='POST')
r1 = json.loads(urllib.request.urlopen(req1).read())
callbacks = r1['callbacks']
for cb in callbacks:
    if cb['type'] == 'NameCallback': cb['input'][0]['value'] = 'amadmin'
    elif cb['type'] == 'PasswordCallback': cb['input'][0]['value'] = 'changeit'
body = json.dumps({'authId': r1['authId'], 'callbacks': callbacks}).encode()
req2 = urllib.request.Request(f"{AM}/json/realms/root/authenticate", data=body, headers=hdrs_auth, method='POST')
token = json.loads(urllib.request.urlopen(req2).read())['tokenId']

# Get SP config
req = urllib.request.Request(
    f"{AM}/json/realms/root/realms/partner/realm-config/federation/entityproviders/saml2?_queryFilter=true",
    headers={"iPlanetDirectoryPro": token, "Accept-API-Version": "resource=1.0, protocol=1.0"}
)
data = json.loads(urllib.request.urlopen(req).read())

for entity in data['result']:
    eid = entity['_id']
    ec = entity.get('entityConfig', '')
    hosted = 'hosted="true"' in ec
    etype = 'IdP' if 'IDPSSOConfig' in ec else 'SP'
    print(f"\n{'='*60}")
    print(f"Entity: {eid} ({etype}, {'HOSTED' if hosted else 'REMOTE'})")
    print(f"{'='*60}")

    for m in re.finditer(r'<Attribute name="([^"]+)">(.*?)</Attribute>', ec, re.DOTALL):
        name = m.group(1)
        vals = re.findall(r'<Value>([^<]*)</Value>', m.group(2))
        nonempty = [v for v in vals if v]
        if nonempty:
            print(f"  {name}: {nonempty}")
        else:
            # Show empty ones too for relay state
            if 'relay' in name.lower() or 'url' in name.lower():
                print(f"  {name}: (empty)")
