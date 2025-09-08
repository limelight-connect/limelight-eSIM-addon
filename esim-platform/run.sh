#!/bin/bash

# eSIM Platform Home Assistant Add-on Startup Script
# 基于原始entrypoint.sh，但适配HA add-on环境

set -e

echo "🚀 Starting eSIM Platform Home Assistant Add-on..."

# 从环境变量获取配置（HA会设置这些变量）
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
TIMEZONE=${TIMEZONE:-"Asia/Shanghai"}
SECRET_KEY=${SECRET_KEY:-""}
DEBUG=${DEBUG:-"False"}
ALLOWED_HOSTS=${ALLOWED_HOSTS:-"localhost,127.0.0.1,0.0.0.0"}
CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:-"http://localhost,http://127.0.0.1"}
SERIAL_DEVICE=${SERIAL_DEVICE:-"/dev/ttyUSB2"}
DATA_RETENTION_DAYS=${DATA_RETENTION_DAYS:-30}
MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-"50M"}
API_TIMEOUT=${API_TIMEOUT:-300}

echo "📋 Configuration loaded:"
echo "  - Log Level: ${LOG_LEVEL}"
echo "  - Timezone: ${TIMEZONE}"
echo "  - Debug: ${DEBUG}"
echo "  - Serial Device: ${SERIAL_DEVICE}"

# 设置时区
if [ -n "${TIMEZONE}" ] && [ "${TIMEZONE}" != "UTC" ]; then
    echo "🌍 Setting timezone to ${TIMEZONE}..."
    if [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
        ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
        echo ${TIMEZONE} > /etc/timezone
    else
        echo "⚠️  Timezone ${TIMEZONE} not found, using UTC"
    fi
fi

# 生成密钥（如果未提供）
if [ -z "${SECRET_KEY}" ]; then
    echo "🔑 Generating new secret key..."
    SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    echo "✅ Secret key generated"
fi

# 设置环境变量
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

# 创建必要的目录
echo "📁 Creating necessary directories..."
mkdir -p /data/backend/data
mkdir -p /data/backend/logs
mkdir -p /data/backend/staticfiles
mkdir -p /config/esim
mkdir -p /share/esim

# 设置权限
chown -R appuser:appuser /data
chown -R appuser:appuser /config/esim
chown -R appuser:appuser /share/esim

# 检查串口设备
echo "🔌 Checking serial devices..."

# 列出所有可用的串口设备
AVAILABLE_DEVICES=$(ls /dev/tty* 2>/dev/null | grep -E "(USB|ACM)" || echo "")
if [ -n "${AVAILABLE_DEVICES}" ]; then
    echo "📱 Available serial devices:"
    for device in ${AVAILABLE_DEVICES}; do
        if [ -e "${device}" ]; then
            echo "  - ${device} ($(ls -la ${device} 2>/dev/null | awk '{print $1, $3, $4}'))"
        fi
    done
else
    echo "⚠️  No USB/ACM serial devices found"
fi

# 检查配置的串口设备
if [ -e "${SERIAL_DEVICE}" ]; then
    echo "✅ Configured serial device ${SERIAL_DEVICE} found"
    # 在HA add-on环境中，设备权限由supervisor管理，不需要手动修改
    # 检查设备是否可访问
    if [ ! -r "${SERIAL_DEVICE}" ] || [ ! -w "${SERIAL_DEVICE}" ]; then
        echo "⚠️  Serial device ${SERIAL_DEVICE} may not be accessible"
        echo "📋 Device permissions: $(ls -la ${SERIAL_DEVICE} 2>/dev/null || echo 'Unable to read')"
    else
        echo "✅ Serial device ${SERIAL_DEVICE} is accessible"
    fi
    echo "✅ Serial device ${SERIAL_DEVICE} is ready for use"
else
    echo "⚠️  Configured serial device ${SERIAL_DEVICE} not found"
    
    # 尝试自动检测常见的eSIM设备
    AUTO_DETECTED=""
    for device in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyUSB2 /dev/ttyUSB3 /dev/ttyACM0 /dev/ttyACM1; do
        if [ -e "${device}" ]; then
            AUTO_DETECTED="${device}"
            echo "🔍 Auto-detected serial device: ${device}"
            break
        fi
    done
    
    if [ -n "${AUTO_DETECTED}" ]; then
        echo "✅ Using auto-detected device: ${AUTO_DETECTED}"
        export SERIAL_DEVICE="${AUTO_DETECTED}"
        # 在HA add-on环境中，设备权限由supervisor管理
        echo "📋 Auto-detected device permissions: $(ls -la ${AUTO_DETECTED} 2>/dev/null || echo 'Unable to read')"
    else
        echo "⚠️  No suitable serial device found - continuing without serial device"
        echo "📋 Please check:"
        echo "  1. eSIM module is connected via USB"
        echo "  2. USB device is recognized by the system"
        echo "  3. Update the 'serial_device' configuration if needed"
    fi
fi

# 进入后端目录
cd /app/backend

# Function to fix database permissions
fix_database_permissions() {
    echo "🔧 Fixing database permissions..."
    
    # 确保数据目录存在
    mkdir -p /app/backend/data
    
    # 如果数据库文件存在但权限不对，修复权限
    if [ -f "/app/backend/data/db.sqlite3" ]; then
        echo "📁 Found existing database, fixing permissions..."
        chown -R appuser:appuser /app/backend/data
        chmod -R 755 /app/backend/data
    fi
}

# 检查数据库是否就绪
check_database_readiness() {
    echo "⏳ Checking database readiness..."
    
    # 确保数据目录存在
    mkdir -p /app/backend/data
    
    # 检查数据库文件是否存在
    if [ ! -f "/app/backend/data/db.sqlite3" ]; then
        echo "📊 Database file not found, will be created during migration"
    else
        echo "✅ Database file exists"
    fi
    
    echo "✅ Database is ready!"
}

# 执行数据库迁移
run_migrations() {
    echo "🔍 Checking for pending migrations..."
    echo "📦 Applying pending migrations..."
    
    # 运行迁移
    python manage.py migrate --noinput
    
    echo "✅ Migrations applied successfully!"
}

# 创建超级用户
create_superuser() {
    echo "👤 Checking for superuser..."
    
    # 检查是否已存在超级用户
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

# 收集静态文件
collect_static_files() {
    echo "📁 Collecting static files..."
    python manage.py collectstatic --noinput
    echo "✅ Static files collected!"
}

# 修复日志文件权限
fix_log_permissions() {
    echo "🔧 Fixing log file permissions before Django starts..."
    mkdir -p /app/backend/logs
    chown -R appuser:appuser /app/backend/logs
    chmod -R 755 /app/backend/logs
    echo "✅ Log file permissions fixed!"
}

# 执行初始化步骤
echo "🎯 Starting initialization process..."

# 修复数据库权限
fix_database_permissions

# 检查数据库就绪状态
check_database_readiness

# 运行数据库迁移
run_migrations

# 创建超级用户
create_superuser

# 收集静态文件
collect_static_files

# 修复日志文件权限
fix_log_permissions

echo "🎉 Initialization completed! Starting application..."

# 启动服务
echo "🚀 Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf