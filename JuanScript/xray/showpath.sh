#!/bin/bash

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
' /etc/xray/config.json
