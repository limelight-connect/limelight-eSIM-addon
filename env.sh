#!/bin/bash

# Set logging format to standard (human-readable)
export LOG_FORMAT=standard

# Disable SSL verification for RSP (Remote SIM Provisioning) in development
export RSP_VERIFY_SSL=false

# MySQL Database Configuration
export DB_NAME=esim_platform
export DB_USER=esim_user
export DB_PASSWORD=mele@2025
export DB_HOST=192.168.1.12
export DB_PORT=33060

source "../venv/bin/activate"
