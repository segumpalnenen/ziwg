#!/bin/bash
# DNS Pointing for specific protocol
set -euo pipefail

IP=$(wget -qO- ipv4.icanhazip.com || curl -s ifconfig.me)
SUB_DOMAIN=$1
BASE_DOMAIN=$2
CF_TOKEN=$3

# Get Zone ID
ZONE_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN&status=active" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
    echo "Error: Could not find Zone ID for $BASE_DOMAIN"
    exit 1
fi

create_or_update() {
    local NAME=$1; local CONTENT=$2; local TYPE=${3:-A}
    local RECORD_ID=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${NAME}&type=${TYPE}" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
    local DATA="{\"type\":\"${TYPE}\",\"name\":\"${NAME}\",\"content\":\"${CONTENT}\",\"ttl\":120,\"proxied\":false}"
    if [[ -z "$RECORD_ID" ]]; then
        curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json" --data "$DATA" > /dev/null
    else
        curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json" --data "$DATA" > /dev/null
    fi
}

FULL_DOMAIN="${SUB_DOMAIN}.${BASE_DOMAIN}"
echo "Pointing $FULL_DOMAIN to $IP..."
create_or_update "$FULL_DOMAIN" "$IP" "A"
echo "Success: $FULL_DOMAIN"
