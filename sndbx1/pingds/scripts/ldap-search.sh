#!/bin/bash
# Wrapper script for ldapsearch with default connection settings

/opt/opendj/bin/ldapsearch \
  --hostname pingds \
  --port 1636 \
  --useSSL \
  --trustAll \
  --bindDN "cn=Directory Manager" \
  --bindPassword "Passw0rd123" \
  "$@"
