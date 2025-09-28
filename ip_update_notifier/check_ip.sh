#!/bin/bash

# CONFIG
EMAIL="jp.rosenkranz@gmail.com"
IP_FILE="/var/local/current_ip.txt"

# Get current public IP
CURRENT_IP=$(curl -s https://api.ipify.org)

# Create file if it doesn't exist
if [ ! -f "$IP_FILE" ]; then
    echo "$CURRENT_IP" > "$IP_FILE"
    exit 0
fi

# Read the last IP
LAST_IP=$(cat "$IP_FILE")

# Compare and send email if changed
if [ "$CURRENT_IP" != "$LAST_IP" ]; then
    echo -e "Subject: Home Public IP Changed\n\nYour home public IP changed to: $CURRENT_IP" | msmtp "$EMAIL"
    echo "$CURRENT_IP" > "$IP_FILE"
fi
