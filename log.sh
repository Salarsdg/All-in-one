#!/bin/bash

# Log file
log_file="/tmp/script_log.txt"

# Function to log messages
log() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %T"): $message" >> "$log_file"
}

# Log script start
log "Script started"

# Create directory
sudo mkdir -p /var/www/my_website 2>&1 | tee -a "$log_file"

# Log script end
log "Script ended"
