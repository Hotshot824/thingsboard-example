#!/bin/sh
set -e

echo "[MQTT-Publisher] Starting..."

apk update && apk add --no-cache mosquitto-clients

THINGSBOARD_HOST="${THINGSBOARD_HOST:-rabbitmq}"
THINGSBOARD_MQTT_PORT="${THINGSBOARD_MQTT_PORT:-1883}"
TOPIC="${TOPIC:-sensor/data}" 
INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"
DEVICE_NAME="${DEVICE_NAME:-SN-001}"

RABBITMQ_USER="${RABBITMQ_USER:-guest}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-guest}"

echo "Connecting to RabbitMQ Broker ($THINGSBOARD_HOST:$THINGSBOARD_MQTT_PORT)..."
echo "Sending data to topic: $TOPIC"
echo "----------------------------------------------------"

# --- Start sending periodic MQTT Telemetry to RabbitMQ ---
while true; do
    TEMP=$(awk 'BEGIN{srand(); printf "%.2f", 20+rand()*10}')
    HUM=$(awk 'BEGIN{srand(); printf "%.2f", 50+rand()*20}')

    JSON_PAYLOAD="{\"serialNumber\": \"$DEVICE_NAME\", \"sensorType\": \"Thermometer\", \"sensorModel\": \"DHT11\", \"temp\": \"$TEMP\", \"hum\": $HUM}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') Sending: $JSON_PAYLOAD"

    mosquitto_pub -h "$THINGSBOARD_HOST" -p "$THINGSBOARD_MQTT_PORT" \
        -t "$TOPIC" \
        -u "$RABBITMQ_USER" \
        -P "$RABBITMQ_PASSWORD" \
        -m "$JSON_PAYLOAD"

    sleep "$INTERVAL_SECONDS"
done