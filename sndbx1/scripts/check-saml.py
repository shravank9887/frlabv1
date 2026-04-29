#!/usr/bin/env python3
"""Check SAML2 entity configuration in both realms."""
import json, urllib.request, urllib.error, re, sys
sys.path.insert(0, 'C:/PCFolders/Main/Learning/Docker/fr/sndbx1/scripts')
from importlib import import_module

AM = "http://pingam:8081/am"

def get_token():
    mod = import_module('am-auth')
    return mod.authenticate()

def api_get(path, token):
    req = urllib.request.Request(
        f"{AM}{path}",
        headers={"iPlanetDirectoryPro": token, "Accept-API-Version": "resource=1.0, protocol=1.0"}
    )
    return json.loads(urllib.request.urlopen(req).read())

def extract_config(entity_config_xml):
    """Extract key attributes from entityConfig XML."""
    attrs = {}
    for m in re.finditer(r'<Attribute name="([^"]+)">(.*?)</Attribute>', entity_config_xml, re.DOTALL):
        name = m.group(1)
        values = re.findall(r'<Value>([^<]*)</Value>', m.group(2))
        attrs[name] = values
    return attrs

token = get_token()
print(f"Admin token: {token[:40]}...\n")

for realm in ['techcorp', 'partner']:
    print(f"{'='*60}")
    print(f"REALM: /{realm}")
    print(f"{'='*60}")
    try:
        data = api_get(f"/json/realms/root/realms/{realm}/realm-config/federation/entityproviders/saml2?_queryFilter=true", token)
        for entity in data.get('result', []):
            eid = entity['_id']
            ec = entity.get('entityConfig', '')
            hosted = 'hosted="true"' in ec
            entity_type = 'IdP' if 'IDPSSOConfig' in ec else 'SP'
            print(f"\n  Entity: {eid} ({entity_type}, {'HOSTED' if hosted else 'REMOTE'})")

            config = extract_config(ec)
            important_keys = [
                'metaAlias', 'nameIDFormatMap', 'cotlist', 'useNameIDAsSPUserID',
                'nameIDFormatList', 'relayStateUrlList', 'transientUser',
                'spAccountMapper', 'attributeMap', 'spAutofedEnabled',
                'spAutofedAttribute'
            ]
            for key in important_keys:
                if key in config and config[key] != ['']:
                    print(f"    {key}: {config[key]}")
    except urllib.error.HTTPError as e:
        print(f"  Error: HTTP {e.code} - {e.read().decode()}")
    print()

# Check demo user's cn attribute
print(f"{'='*60}")
print("DEMO USER ATTRIBUTES")
print(f"{'='*60}")
try:
    data = api_get("/json/realms/root/realms/techcorp/users/demo", token)
    print(f"  uid: {data.get('uid', 'N/A')}")
    print(f"  cn: {data.get('cn', 'N/A')}")
    print(f"  mail: {data.get('mail', 'N/A')}")
    print(f"  sn: {data.get('sn', 'N/A')}")
    print(f"  givenName: {data.get('givenName', 'N/A')}")
except urllib.error.HTTPError as e:
    print(f"  Error: HTTP {e.code} - {e.read().decode()}")
