#!/bin/bash

# eSIM Platform Home Assistant Add-on Startup Script

set -e

echo "🚀 Starting eSIM Platform Home Assistant Add-on..."

echo "📁 Setting up persistent data directories..."

mkdir -p /data/esim/{db,logs,staticfiles,files,secrets}
echo "✅ Created persistent directories in /data/esim/"

if [ -d "/app/backend/data" ] && [ ! -e "/data/esim/.migrated" ]; then
    echo "🔄 Migrating existing data from /app/backend/data -> /data/esim ..."
    cp -a /app/backend/data/* /data/esim/ 2>/dev/null || true
    touch /data/esim/.migrated
    echo "✅ Data migration completed"
fi

chmod -R 755 /data/esim 2>/dev/null || true

export ESIM_DATA_DIR=/data/esim
export ESIM_DB_PATH=/data/esim/db/esim.sqlite3
export ESIM_LOG_DIR=/data/esim/logs
export ESIM_STATIC_DIR=/data/esim/staticfiles
export ESIM_FILES_DIR=/data/esim/files
export ESIM_SECRETS_DIR=/data/esim/secrets

echo "✅ Persistent data setup completed"
echo "📂 Data directories:"
echo "  - Database: $ESIM_DB_PATH"
echo "  - Logs: $ESIM_LOG_DIR"
echo "  - Static files: $ESIM_STATIC_DIR"
echo "  - User files: $ESIM_FILES_DIR"
echo "  - Secrets: $ESIM_SECRETS_DIR"

LOG_LEVEL=${LOG_LEVEL:-"INFO"}
TIMEZONE=${TIMEZONE:-"Asia/Shanghai"}
SECRET_KEY=${SECRET_KEY:-""}
DEBUG=${DEBUG:-"False"}
ALLOWED_HOSTS=${ALLOWED_HOSTS:-"localhost,127.0.0.1,0.0.0.0"}
CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:-"http://localhost,http://127.0.0.1"}
SERIAL_DEVICE=${SERIAL_DEVICE:-"/dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0"}
DATA_RETENTION_DAYS=${DATA_RETENTION_DAYS:-30}
MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-"50M"}
API_TIMEOUT=${API_TIMEOUT:-300}

WEB_AUTH_ENABLED=${WEB_AUTH_ENABLED:-"false"}
WEB_AUTH_USERNAME=${WEB_AUTH_USERNAME:-"admin"}
WEB_AUTH_PASSWORD=${WEB_AUTH_PASSWORD:-""}

if [ -f "/data/options.json" ]; then
    echo "📋 Reading authentication config from /data/options.json..."
    WEB_AUTH_ENABLED=$(jq -r '.web_auth_enabled // false' /data/options.json)
    WEB_AUTH_USERNAME=$(jq -r '.web_auth_username // "admin"' /data/options.json)
    WEB_AUTH_PASSWORD=$(jq -r '.web_auth_password // ""' /data/options.json)
    echo "✅ Config loaded from options.json: enabled=$WEB_AUTH_ENABLED, username=$WEB_AUTH_USERNAME"
fi

NEXT_PUBLIC_BASE_PATH=${NEXT_PUBLIC_BASE_PATH:-${next_public_base_path:-""}}
NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL:-${next_public_api_url:-""}}
NEXT_PUBLIC_DEV_API_URL=${NEXT_PUBLIC_DEV_API_URL:-${next_public_dev_api_url:-""}}

echo "📋 Configuration loaded:"
echo "  - Log Level: ${LOG_LEVEL}"
echo "  - Timezone: ${TIMEZONE}"
echo "  - Debug: ${DEBUG}"
echo "  - Serial Device: ${SERIAL_DEVICE}"
echo "  - Next.js Base Path: ${NEXT_PUBLIC_BASE_PATH}"
echo "  - Next.js API URL: ${NEXT_PUBLIC_API_URL}"
echo "  - Next.js Dev API URL: ${NEXT_PUBLIC_DEV_API_URL}"

echo "🔍 Environment variable mapping debug:"
echo "  - NEXT_PUBLIC_BASE_PATH from env: ${NEXT_PUBLIC_BASE_PATH}"
echo "  - next_public_base_path from env: ${next_public_base_path}"
echo "  - NEXT_PUBLIC_API_URL from env: ${NEXT_PUBLIC_API_URL}"
echo "  - next_public_api_url from env: ${next_public_api_url}"
echo "  - NEXT_PUBLIC_DEV_API_URL from env: ${NEXT_PUBLIC_DEV_API_URL}"
echo "  - next_public_dev_api_url from env: ${next_public_dev_api_url}"

if [ -n "${TIMEZONE}" ] && [ "${TIMEZONE}" != "UTC" ]; then
    echo "🌍 Setting timezone to ${TIMEZONE}..."
    if [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
        ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
        echo ${TIMEZONE} > /etc/timezone
    else
        echo "⚠️  Timezone ${TIMEZONE} not found, using UTC"
    fi
fi

if [ -z "${SECRET_KEY}" ]; then
    echo "🔑 Generating new secret key..."
    SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    echo "✅ Secret key generated"
fi

export DEBUG=${DEBUG}
export SECRET_KEY=${SECRET_KEY}
export ALLOWED_HOSTS=${ALLOWED_HOSTS}
export CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS}
export LOG_LEVEL=${LOG_LEVEL}
export LOG_FORMAT=standard
export TIME_ZONE=${TIMEZONE}
export CELERY_TIMEZONE=${TIMEZONE}
export DATA_RETENTION_DAYS=${DATA_RETENTION_DAYS}
export MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE}
export API_TIMEOUT=${API_TIMEOUT}

export NEXT_PUBLIC_BASE_PATH=${NEXT_PUBLIC_BASE_PATH}
export NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
export NEXT_PUBLIC_DEV_API_URL=${NEXT_PUBLIC_DEV_API_URL}

echo "📁 Creating necessary directories..."
mkdir -p /data/backend/data
mkdir -p /data/backend/logs
mkdir -p /data/backend/staticfiles
mkdir -p /config/esim
mkdir -p /share/esim

chmod -R 755 /data
chmod -R 755 /config/esim
chmod -R 755 /share/esim

echo "🔌 Checking serial devices..."

if [ -e "${SERIAL_DEVICE}" ]; then
    echo "✅ Configured serial device ${SERIAL_DEVICE} found"
    echo "✅ Serial device ${SERIAL_DEVICE} is ready for use"
else
    echo "⚠️  Configured serial device ${SERIAL_DEVICE} not found"
    
    AUTO_DETECTED=""
    for device in /dev/serial/by-id/usb-Quectel_EG25-GC-if00-port0 /dev/serial/by-id/usb-Quectel_EG25-GC-if01-port0 /dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0 /dev/serial/by-id/usb-Quectel_EG25-GC-if03-port0 /dev/ttyACM0 /dev/ttyACM1; do
        if [ -e "${device}" ]; then
            AUTO_DETECTED="${device}"
            echo "🔍 Auto-detected serial device: ${device}"
            break
        fi
    done
    
    if [ -n "${AUTO_DETECTED}" ]; then
        echo "✅ Using auto-detected device: ${AUTO_DETECTED}"
        export SERIAL_DEVICE="${AUTO_DETECTED}"
    else
        echo "⚠️  No suitable serial device found - continuing without serial device"
        echo "📋 Please check:"
        echo "  1. eSIM module is connected via USB"
        echo "  2. USB device is recognized by the system"
        echo "  3. Update the 'serial_device' configuration if needed"
    fi
fi

cd /app/backend

# Function to fix database permissions
fix_database_permissions() {
    echo "🔧 Fixing database permissions..."
    
    # 确保数据目录存在
    mkdir -p /app/backend/data
    
    if [ -f "/app/backend/data/db.sqlite3" ]; then
        echo "📁 Found existing database, fixing permissions..."
        chmod -R 755 /app/backend/data
    fi
}

check_database_readiness() {
    echo "⏳ Checking database readiness..."
    
    # 确保数据目录存在
    mkdir -p /app/backend/data
    
    if [ ! -f "/app/backend/data/db.sqlite3" ]; then
        echo "📊 Database file not found, will be created during migration"
    else
        echo "✅ Database file exists"
    fi
    
    echo "✅ Database is ready!"
}

run_migrations() {
    echo "🔍 Checking for pending migrations..."
    echo "📦 Applying pending migrations..."
    
    python manage.py migrate --noinput
    
    echo "✅ Migrations applied successfully!"
}

configure_web_auth() {
    echo "🔐 Configuring web authentication..."
    echo "DEBUG: WEB_AUTH_ENABLED=$WEB_AUTH_ENABLED"
    echo "DEBUG: WEB_AUTH_USERNAME=$WEB_AUTH_USERNAME"
    echo "DEBUG: WEB_AUTH_PASSWORD=$WEB_AUTH_PASSWORD"
    echo "DEBUG: All environment variables containing 'AUTH':"
    env | grep -i auth || echo "No AUTH variables found"
    
    if [ "$WEB_AUTH_ENABLED" = "true" ] && [ -n "$WEB_AUTH_PASSWORD" ]; then
        echo "✅ Web authentication enabled"
        echo "📝 Generating .htpasswd file..."
        
        htpasswd -cb /etc/nginx/.htpasswd "$WEB_AUTH_USERNAME" "$WEB_AUTH_PASSWORD"
        
        echo "✅ Authentication file created for user: $WEB_AUTH_USERNAME"
        
        sed -i 's/# auth_basic/auth_basic/g' /etc/nginx/sites-available/default
        sed -i 's/# auth_basic_user_file/auth_basic_user_file/g' /etc/nginx/sites-available/default
    else
        echo "⚠️  Web authentication disabled or no password provided"
        echo "📝 Creating empty .htpasswd file..."
        
        touch /etc/nginx/.htpasswd
        
        sed -i 's/^[[:space:]]*auth_basic/# auth_basic/g' /etc/nginx/sites-available/default
        sed -i 's/^[[:space:]]*auth_basic_user_file/# auth_basic_user_file/g' /etc/nginx/sites-available/default
    fi
}

create_superuser() {
    echo "👤 Checking for superuser..."
    
    if python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print('exists' if User.objects.filter(is_superuser=True).exists() else 'not_exists')" | grep -q "exists"; then
        echo "✅ Superuser already exists"
    else
        echo "🔧 Creating default superuser..."
        python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
"
    fi
}

collect_static_files() {
    echo "📁 Collecting static files..."
    python manage.py collectstatic --noinput
    echo "✅ Static files collected!"
}

fix_log_permissions() {
    echo "🔧 Fixing log file permissions before Django starts..."
    mkdir -p /app/backend/logs
    chmod -R 755 /app/backend/logs
    echo "✅ Log file permissions fixed!"
}

start_qmi() {
    echo "🔌 Starting QMI service..."
    /usr/bin/qmi.sh &
    echo "✅ QMI service started!"
}

start_route_metric_adjuster() {
    echo "⏰ Starting route metric adjuster (calls API every 1 minute)..."
    
    (
        echo "⏳ Waiting for services to start (30 seconds)..."
        sleep 30
        
        while true; do
            curl -X POST http://127.0.0.1:8080/api/devices/adjust_route_metric/ \
                --connect-timeout 5 \
                --max-time 10 \
                --silent \
                --output /dev/null \
                --write-out "Route metric adjuster: HTTP %{http_code} at $(date '+%Y-%m-%d %H:%M:%S')\n" \
                2>&1 || echo "Route metric adjuster: Failed at $(date '+%Y-%m-%d %H:%M:%S')"
            
            sleep 60
        done
    ) &
    
    echo "✅ Route metric adjuster started in background (PID: $!)"
}

echo "🎯 Starting initialization process..."

fix_database_permissions

check_database_readiness

run_migrations

create_superuser

collect_static_files

fix_log_permissions

echo "🎉 Initialization completed! Starting application..."

configure_web_auth

start_qmi

start_route_metric_adjuster

echo "🚀 Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf