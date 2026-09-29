#!/usr/bin/env bash
set -euo pipefail

# Materialize the Android release signing config from Infisical.
# Reads 4 secrets and writes android/key.properties + the keystore file.
# Both outputs are gitignored. Run before `flutter build appbundle --release`.
#
# Environment (the script exits if either of the first two is unset):
#   INFISICAL_SIGNING_PROJECT_ID          Infisical project that holds the signing secrets
#   INFISICAL_SIGNING_PATH                secret folder path inside that project
#   INFISICAL_SIGNING_ENV                 environment slug (default: prod)
#
# Required Infisical secrets:
#   infocutter_release_keystore_b64       base64 of the upload keystore (.jks)
#   infocutter_release_keystore_password  store password
#   infocutter_release_key_password       key password
#   infocutter_release_key_alias          key alias

PROJECT_ID="${INFISICAL_SIGNING_PROJECT_ID:?set INFISICAL_SIGNING_PROJECT_ID to the Infisical project that holds the signing secrets}"
ENV_NAME="${INFISICAL_SIGNING_ENV:-prod}"
SIGN_PATH="${INFISICAL_SIGNING_PATH:?set INFISICAL_SIGNING_PATH to the signing secret folder path}"

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$APP_DIR/android"
KEYSTORE_FILE="infocutter-upload.jks"
KEYSTORE_PATH="$ANDROID_DIR/app/$KEYSTORE_FILE"

get() {
  infisical secrets get "$1" --plain --path "$SIGN_PATH" --projectId "$PROJECT_ID" --env "$ENV_NAME"
}

get infocutter_release_keystore_b64 | base64 --decode > "$KEYSTORE_PATH"

umask 077
{
  echo "storeFile=$KEYSTORE_FILE"
  echo "storePassword=$(get infocutter_release_keystore_password)"
  echo "keyPassword=$(get infocutter_release_key_password)"
  echo "keyAlias=$(get infocutter_release_key_alias)"
} > "$ANDROID_DIR/key.properties"

echo "signing materialized -> $KEYSTORE_PATH + $ANDROID_DIR/key.properties"
