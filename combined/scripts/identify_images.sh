#!/bin/bash

cd /opt/app/static/assets/images

# Clear previous log
truncate -s 0 metadata.log

# Identify all JPEG images and log metadata
# VULNERABLE: This uses ImageMagick 7.1.1-35 which is vulnerable to CVE-2024-41817
find /opt/app/static/assets/images/ -type f -name "*.jpg" | xargs /usr/local/bin/magick identify >> metadata.log
