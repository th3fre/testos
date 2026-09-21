#!/bin/bash

USERDB="/etc/xray/users.json"

if [ ! -f "$USERDB" ]; then
  echo "User database not found."
  exit 1
fi

echo "=============================="
echo "        XRAY USERS"
echo "=============================="

jq -r '
  to_entries[]
  | "Name: \(.key)\nUUID: \(.value)\n"
' "$USERDB"
