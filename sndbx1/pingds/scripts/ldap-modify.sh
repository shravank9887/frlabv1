#!/bin/bash
# Wrapper script for ldapmodify with default connection settings

/opt/opendj/bin/ldapmodify \
  --hostname pingds \
  --port 1636 \
  --useSSL \
  --trustAll \
  --bindDN "cn=Directory Manager" \
  --bindPassword "Passw0rd123" \
  "$@"
