#!/bin/bash

CONFIG="/etc/xray/config.json"
USERDB="/etc/xray/users.json"
TMP_CONFIG="/tmp/config.json.$$"
TMP_USERDB="/tmp/users.json.$$"

read -p "Enter username to delete: " NAME

if [ -z "$NAME" ]; then
  echo "Username cannot be empty."
  exit 1
fi

if [ ! -f "$USERDB" ]; then
  echo "User database not found: $USERDB"
  exit 1
fi

UUID=$(jq -r --arg name "$NAME" '.[$name] // empty' "$USERDB")

if [ -z "$UUID" ]; then
  echo "Username not found."
  exit 1
fi

jq --arg t "$UUID" '
  .inbounds |= map(
    if (.settings.clients? | type) == "array" then
      .settings.clients |= map(
        select((.id // .password) != $t)
      )
    else
      .
    end
  )
' "$CONFIG" > "$TMP_CONFIG" || exit 1

jq --arg name "$NAME" 'del(.[$name])' "$USERDB" > "$TMP_USERDB" || exit 1

mv "$TMP_CONFIG" "$CONFIG" || exit 1
mv "$TMP_USERDB" "$USERDB" || exit 1

if ! systemctl restart xray; then
  echo "Failed to restart xray."
  exit 1
fi

echo "User deleted successfully."
echo "Username: $NAME"
echo "UUID: $UUID"
