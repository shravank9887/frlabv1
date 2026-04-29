#!/bin/bash
#
# Copyright 2016-2025 Ping Identity Corporation. All Rights Reserved
#
# This code is to be used exclusively in connection with Ping Identity
# Corporation software or services. Ping Identity Corporation only offers
# such software or services to legal entities who have entered into a
# binding license agreement with Ping Identity Corporation.
#

if [ -z "$JAVA_HOME" ]
then
    echo
    echo "\$JAVA_HOME is not specified. Exiting."
    echo
    exit 1
fi

if [ -z "$1" ]
then
    echo
    echo "No command was specified. For help, use: $0 help"
    echo
    exit 0
fi

if [ "$1" == "help" ] ; then
    echo
    echo "generate"
    echo
    echo "$0 generate [keystore directory]"
    echo
    echo "Generates a suitable transport key in the specified keystore"
    echo
    echo
    echo "move"
    echo
    echo "$0 move [source keystore directory] [destination keystore directory]"
    echo
    echo "Moves the transport key from the source keystore to the destination keystore"
    echo "If the destination keystore does not exist, it will be created."
    echo "If the destination .storepass does not exist, the source .storepass will be used."
    echo "If the source .storepass does not exist, it will fail."
    echo "The .storepass contains the password to the keystore."
    echo
    echo
    echo "delete"
    echo
    echo "$0 delete [keystore directory]"
    echo
    echo "Deletes the transport key from a keystore."
    echo
fi

# Generates a suitable transport key in the OpenAM keystore.

if [ "$1" == "generate" ] ; then
    if [ -z "$2" ] ; then
        echo "No argument for OpenAM config directory supplied"
        exit 0
    fi

    OPENAM_DIR=$2

    echo "OpenAM dir : ${OPENAM_DIR}"

    cd "${OPENAM_DIR}"

    DEST_STORE_PASS=$( cat ".storepass" )
    DEST_KEY_PASS=$( cat ".keypass" )

    # generate and store the secret transport key
    $JAVA_HOME/bin/keytool -genseckey -alias sms.transport.key -keyalg AES -keysize 128 -storetype jceks -keystore keystore.jceks -storepass ${DEST_STORE_PASS} -keypass ${DEST_KEY_PASS}

    echo "Successfully generated"
    echo "Changes require a restart of OpenAM"
fi

# Moves the transport key from one keystore to another. If the destination doesn't have a keystore, one will be created.
# If the destination doesn't have a .storepass the source .storepass will be used

if [ "$1" == "move" ] ; then
    if [ -z "$2" ] ; then
        echo "No argument for source directory supplied"
        exit 0
    fi

    SRC_KEYSTORE_DIR=$2

    echo "Source directory : ${SRC_KEYSTORE_DIR}"

    if [ -z "$3" ] ; then
        echo "No argument for destination directory supplied"
        exit 0
    fi

    DEST_KEYSTORE_DIR=$3

    echo "Destination directory : ${DEST_KEYSTORE_DIR}"

    cd "${SRC_KEYSTORE_DIR}"

    SRC_STORE_PASS=$( cat ".storepass" )
    SRC_KEY_PASS=$( cat ".keypass" )

    if [ -f "${DEST_KEYSTORE_DIR}/.storepass" ] ; then
        DEST_STORE_PASS=$( cat "${DEST_KEYSTORE_DIR}/.storepass" )
    else
        DEST_STORE_PASS=${SRC_STORE_PASS}
        cp "${SRC_KEYSTORE_DIR}/.storepass" ${DEST_KEYSTORE_DIR}
    fi

    if [ -f "${DEST_KEYSTORE_DIR}/.keypass" ] ; then
        DEST_KEY_PASS=$( cat "${DEST_KEYSTORE_DIR}/.keypass" )
    else
        DEST_KEY_PASS=${SRC_KEY_PASS}
        cp "${SRC_KEYSTORE_DIR}/.keypass" ${DEST_KEYSTORE_DIR}
    fi

    # import the exported keystore into the current openam keystore
    $JAVA_HOME/bin/keytool -importkeystore -srckeystore "${SRC_KEYSTORE_DIR}/keystore.jceks" -destkeystore "${DEST_KEYSTORE_DIR}/keystore.jceks" -srcstoretype jceks \
        -deststoretype jceks -srcalias "sms.transport.key" -destalias "sms.transport.key" -srckeypass "${SRC_KEY_PASS}" -destkeypass "${DEST_KEY_PASS}" \
        -srcstorepass "${SRC_STORE_PASS}" -deststorepass "${DEST_STORE_PASS}"

    echo "Successfully exported transport key"
fi

if [ $1 == "delete" ] ; then
    if [ -z "$2" ] ; then
        echo "No argument for OpenAM config directory supplied"
        exit 0
    fi

    OPENAM_DIR=$2

    echo "OpenAM directory : ${OPENAM_DIR}"

    cd "${OPENAM_DIR}"

    STORE_PASS=$( cat ".storepass" )

    # generate and store the secret transport key
    $JAVA_HOME/bin/keytool -delete -alias "sms.transport.key" -storetype jceks -keystore "${OPENAM_DIR}/keystore.jceks" -storepass "${STORE_PASS}"

    echo "Successfully deleted"
    echo "Changes require a restart of OpenAM"
fi
