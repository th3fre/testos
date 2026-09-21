#!/bin/bash

CONFIG="/etc/xray/config.json"
USERDB="/etc/xray/users.json"
TMP_CONFIG="/tmp/config.json.$$"
TMP_USERDB="/tmp/users.json.$$"

read -p "Enter username: " NAME

if [ -z "$NAME" ]; then
  echo "Username cannot be empty."
  exit 1
fi

# create user db if missing
if [ ! -f "$USERDB" ]; then
  echo "{}" > "$USERDB"
fi

# check if name already exists
if jq -e --arg name "$NAME" 'has($name)' "$USERDB" >/dev/null; then
  echo "Username already exists."
  exit 1
fi

UUID=$(xray uuid) || exit 1

jq --arg uuid "$UUID" '
  .inbounds |= map(
    if .protocol == "vless" or .protocol == "vmess" then
      .settings.clients += [{
        "id": $uuid
      }]

    elif .protocol == "trojan" then
      .settings.clients += [{
        "password": $uuid
      }]

    elif .protocol == "shadowsocks" then
      .settings.clients += [{
        "password": $uuid,
        "method": "aes-128-gcm"
      }]

    else .
    end
  )
' "$CONFIG" > "$TMP_CONFIG" || exit 1

jq --arg name "$NAME" --arg uuid "$UUID" '. + {($name): $uuid}' "$USERDB" > "$TMP_USERDB" || exit 1

mv "$TMP_CONFIG" "$CONFIG" || exit 1
mv "$TMP_USERDB" "$USERDB" || exit 1

if ! systemctl restart xray; then
  echo "Failed to restart xray."
  exit 1
fi

echo "================================="
echo " Xray user created successfully"
echo "================================="
echo "Username:"
echo "$NAME"
echo
echo "UUID / Password:"
echo "$UUID"
echo
echo "Available paths & protocols:"
echo "---------------------------------"

jq -r '
  .inbounds[]
  | select(.protocol != "dokodemo-door")
  | if .streamSettings.wsSettings.path then
      "\(.protocol)  →  \(.streamSettings.wsSettings.path)"
    elif .streamSettings.httpSettings.path then
      "\(.protocol)  →  \(.streamSettings.httpSettings.path | join(","))"
    else
      empty
    end
' "$CONFIG"

echo "---------------------------------"
