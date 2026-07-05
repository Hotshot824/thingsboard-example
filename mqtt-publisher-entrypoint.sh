#!/bin/sh
set -e

echo "[MQTT-Publisher] Starting..."

# Install required packages (including curl and jq)
apk update && apk add --no-cache mosquitto-clients curl jq

# Configuration variables (can be overridden by environment variables)
THINGSBOARD_HOST="${THINGSBOARD_HOST:-thingsboard-ce}"
THINGSBOARD_MQTT_PORT="${THINGSBOARD_MQTT_PORT:-1883}"
THINGSBOARD_HTTP_PORT="${THINGSBOARD_HTTP_PORT:-8080}"
TOPIC="${TOPIC:-v1/devices/me/telemetry}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"

# Default ThingsBoard Tenant Administrator credentials
TB_USER="${TB_USER:-tenant@thingsboard.org}"
TB_PASSWORD="${TB_PASSWORD:-tenant}"
DEVICE_NAME="${DEVICE_NAME:-Auto_Test_Device}"

echo "Waiting for ThingsBoard HTTP service to be ready ($THINGSBOARD_HOST:$THINGSBOARD_HTTP_PORT)..."
until curl -s "http://$THINGSBOARD_HOST:$THINGSBOARD_HTTP_PORT/api/noauth/activate" > /dev/null; do
    sleep 3
done
echo "ThingsBoard is ready. Starting the auto-registration process..."

# --- Step 1: Log in to obtain JWT Token ---
echo "Logging in to tenant account..."
LOGIN_RESPONSE=$(curl -s -X POST "http://$THINGSBOARD_HOST:$THINGSBOARD_HTTP_PORT/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TB_USER\", \"password\":\"$TB_PASSWORD\"}")

JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')

if [ "$JWT_TOKEN" = "null" ] || [ -z "$JWT_TOKEN" ]; then
    echo "ERROR: Failed to log in to ThingsBoard. Please check credentials or service status."
    echo "Response content: $LOGIN_RESPONSE"
    exit 1
fi

# --- Step 2: Check if device exists, if not, create it ---
echo "Checking if device exists: $DEVICE_NAME ..."

# Search for the device by name first
SEARCH_RESPONSE=$(curl -s -X GET "http://$THINGSBOARD_HOST:$THINGSBOARD_HTTP_PORT/api/tenant/devices?deviceName=$DEVICE_NAME" \
  -H "X-Authorization: Bearer $JWT_TOKEN")

DEVICE_ID=$(echo "$SEARCH_RESPONSE" | jq -r '.id.id')

# If device is not found (DEVICE_ID is null), proceed to create it
if [ "$DEVICE_ID" = "null" ] || [ -z "$DEVICE_ID" ]; then
    echo "Device not found. Creating device: $DEVICE_NAME ..."
    DEVICE_RESPONSE=$(curl -s -X POST "http://$THINGSBOARD_HOST:$THINGSBOARD_HTTP_PORT/api/device" \
      -H "Content-Type: application/json" \
      -H "X-Authorization: Bearer $JWT_TOKEN" \
      -d "{\"name\":\"$DEVICE_NAME\", \"type\":\"default\"}")

    DEVICE_ID=$(echo "$DEVICE_RESPONSE" | jq -r '.id.id')

    if [ "$DEVICE_ID" = "null" ] || [ -z "$DEVICE_ID" ]; then
        echo "ERROR: Failed to create device."
        echo "Response content: $DEVICE_RESPONSE"
        exit 1
    fi
    echo "Device created successfully. ID: $DEVICE_ID"
else
    echo "Device already exists. Using existing ID: $DEVICE_ID"
fi

# --- Step 3: Get the MQTT Access Token for the device ---
echo "Retrieving device Access Token..."
CREDENTIALS_RESPONSE=$(curl -s -X GET "http://$THINGSBOARD_HOST:$THINGSBOARD_HTTP_PORT/api/device/$DEVICE_ID/credentials" \
  -H "X-Authorization: Bearer $JWT_TOKEN")

ACCESS_TOKEN=$(echo "$CREDENTIALS_RESPONSE" | jq -r '.credentialsId')

echo "Successfully retrieved Access Token: $ACCESS_TOKEN"
echo "----------------------------------------------------"

# --- Step 4: Start sending periodic MQTT Telemetry ---
while true; do
    # Generate random temperature between 20-30 and humidity between 50-70
    TEMP=$(awk 'BEGIN{srand(); print 20+rand()*10}')
    HUM=$(awk 'BEGIN{srand(); print 50+rand()*20}')
    TIMESTAMP=$(date +%s)000

    JSON_PAYLOAD="{\"temperature\": ${TEMP}, \"humidity\": ${HUM}, \"ts\": ${TIMESTAMP}}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') Sending: $JSON_PAYLOAD"

    mosquitto_pub -h "$THINGSBOARD_HOST" -p "$THINGSBOARD_MQTT_PORT" \
        -t "$TOPIC" \
        -u "$ACCESS_TOKEN" \
        -P "" \
        -m "$JSON_PAYLOAD"

    sleep "$INTERVAL_SECONDS"
done