#!/bin/bash

# Start cron service
service cron start
echo "Started cron service"

# Start SSH service
service ssh start
echo "Started SSH service"

# Start Flask application in the background
cd /opt/app
python3 app.py &
echo "Started Flask application"

# Start nginx using the combined configuration
nginx -c /etc/nginx/nginx-combined.conf -g 'daemon off;' &
echo "Started nginx"

# Keep container running and show logs
tail -f /dev/null
