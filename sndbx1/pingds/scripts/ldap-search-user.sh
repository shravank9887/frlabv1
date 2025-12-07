#!/bin/bash
# Wrapper script for ldapsearch with user authentication
# Usage: ./ldap-search-user.sh <username> <password> [additional args]

USERNAME="$1"
PASSWORD="$2"
shift 2

/opt/opendj/bin/ldapsearch \
  --hostname pingds \
  --port 1636 \
  --useSSL \
  --trustAll \
  --bindDN "uid=${USERNAME},ou=people,ou=identities" \
  --bindPassword "${PASSWORD}" \
  "$@"
