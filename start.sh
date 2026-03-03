#!/bin/bash

# Start cron service
service cron start

# Start SSH service
service ssh start

# Keep container running
tail -f /dev/null
