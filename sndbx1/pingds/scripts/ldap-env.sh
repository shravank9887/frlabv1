#!/bin/bash
# Source this file to set LDAP environment variables
# Usage: source ldap-env.sh

# Connection settings
export LDAP_HOST="pingds"
export LDAP_PORT="1636"
export LDAP_ADMIN_DN="cn=Directory Manager"
export LDAP_ADMIN_PWD="Passw0rd123"

# Base DNs
export LDAP_BASE_DN="ou=identities"
export LDAP_PEOPLE_DN="ou=people,ou=identities"
export LDAP_GROUPS_DN="ou=groups,ou=identities"

# Aliases for common commands
alias ldap-modify='/opt/opendj/bin/ldapmodify --hostname $LDAP_HOST --port $LDAP_PORT --useSSL --trustAll --bindDN "$LDAP_ADMIN_DN" --bindPassword "$LDAP_ADMIN_PWD"'
alias ldap-search='/opt/opendj/bin/ldapsearch --hostname $LDAP_HOST --port $LDAP_PORT --useSSL --trustAll --bindDN "$LDAP_ADMIN_DN" --bindPassword "$LDAP_ADMIN_PWD"'
alias ldap-delete='/opt/opendj/bin/ldapdelete --hostname $LDAP_HOST --port $LDAP_PORT --useSSL --trustAll --bindDN "$LDAP_ADMIN_DN" --bindPassword "$LDAP_ADMIN_PWD"'

echo "LDAP environment variables and aliases loaded!"
echo "Available aliases: ldap-modify, ldap-search, ldap-delete"
