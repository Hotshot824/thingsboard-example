#!/bin/sh
set -e

echo "[MQTT-Publisher] Starting..."

# Install required packages (Only mosquitto-clients is needed)
apk update && apk add --no-cache mosquitto-clients

# Configuration variables (Can be overridden by environment variables in compose)
THINGSBOARD_HOST="${THINGSBOARD_HOST:-rabbitmq}"
THINGSBOARD_MQTT_PORT="${THINGSBOARD_MQTT_PORT:-1883}"
TOPIC="${TOPIC:-any/topic/you/want}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"
DEVICE_NAME="${DEVICE_NAME:-Auto_Test_Device}"

# RabbitMQ Authentication credentials (Default to guest/guest for testing)
RABBITMQ_USER="${RABBITMQ_USER:-guest}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-guest}"

echo "Connecting to RabbitMQ Broker ($THINGSBOARD_HOST:$THINGSBOARD_MQTT_PORT)..."
echo "Authenticating as user: $RABBITMQ_USER"
echo "Sending data to topic: $TOPIC"
echo "----------------------------------------------------"

# --- Start sending periodic MQTT Telemetry to RabbitMQ ---
while true; do
    # Generate random temperature between 20-30 and humidity between 50-70
    TEMP=$(awk 'BEGIN{srand(); print 20+rand()*10}')
    HUM=$(awk 'BEGIN{srand(); print 50+rand()*20}')
    TIMESTAMP=$(date +%s)000

    # Include "deviceName" inside the JSON payload for TB-Gateway routing
    JSON_PAYLOAD="{\"deviceName\": \"$DEVICE_NAME\", \"temperature\": ${TEMP}, \"humidity\": ${HUM}, \"ts\": ${TIMESTAMP}}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') Sending to RabbitMQ: $JSON_PAYLOAD"

    # Connect using configurable RabbitMQ credentials
    mosquitto_pub -h "$THINGSBOARD_HOST" -p "$THINGSBOARD_MQTT_PORT" \
        -t "$TOPIC" \
        -u "$RABBITMQ_USER" \
        -P "$RABBITMQ_PASSWORD" \
        -m "$JSON_PAYLOAD"

    sleep "$INTERVAL_SECONDS"
done