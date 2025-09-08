#!/usr/bin/env bashio
# ==============================================================================
# Home Assistant Add-on: eSIM Management Platform
# ==============================================================================

# 设置错误处理
set -e

# 加载配置
bashio::log.info "Starting eSIM Management Platform..."

# 验证必需配置
bashio::config.require 'serial_device'

# 获取配置选项
LOG_LEVEL=$(bashio::config 'log_level')
TIMEZONE=$(bashio::config 'timezone')
SECRET_KEY=$(bashio::config 'secret_key')
DEBUG=$(bashio::config 'debug')
ALLOWED_HOSTS=$(bashio::config 'allowed_hosts')
CORS_ALLOWED_ORIGINS=$(bashio::config 'cors_allowed_origins')
SERIAL_DEVICE=$(bashio::config 'serial_device')
DATA_RETENTION_DAYS=$(bashio::config 'data_retention_days')
MAX_UPLOAD_SIZE=$(bashio::config 'max_upload_size')
API_TIMEOUT=$(bashio::config 'api_timeout')

# 设置时区
if bashio::config.has_value 'timezone'; then
    bashio::log.info "Setting timezone to ${TIMEZONE}..."
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    echo ${TIMEZONE} > /etc/timezone
else
    # 使用HA supervisor的时区设置
    export TZ="$(bashio::supervisor.timezone)"
    bashio::log.info "Using Home Assistant timezone: ${TZ}"
fi

# 生成密钥（如果未提供）
if [ -z "${SECRET_KEY}" ]; then
    SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    bashio::log.info "Generated new secret key"
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
bashio::log.info "Creating necessary directories..."
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
bashio::log.info "Checking serial devices..."

# 列出所有可用的串口设备
AVAILABLE_DEVICES=$(ls /dev/tty* 2>/dev/null | grep -E "(USB|ACM)" || echo "")
if [ -n "${AVAILABLE_DEVICES}" ]; then
    bashio::log.info "Available serial devices:"
    for device in ${AVAILABLE_DEVICES}; do
        if [ -e "${device}" ]; then
            bashio::log.info "  - ${device} ($(ls -la ${device} 2>/dev/null | awk '{print $1, $3, $4}'))"
        fi
    done
else
    bashio::log.warning "No USB/ACM serial devices found"
fi

# 检查配置的串口设备
if [ -e "${SERIAL_DEVICE}" ]; then
    bashio::log.info "Configured serial device ${SERIAL_DEVICE} found"
    chmod 666 ${SERIAL_DEVICE}
    # 确保设备可访问
    if [ ! -r "${SERIAL_DEVICE}" ] || [ ! -w "${SERIAL_DEVICE}" ]; then
        bashio::log.warning "Serial device ${SERIAL_DEVICE} permissions may need adjustment"
        # 尝试修复权限
        chmod 666 ${SERIAL_DEVICE} 2>/dev/null || true
    fi
    bashio::log.info "Serial device ${SERIAL_DEVICE} is ready for use"
else
    bashio::log.warning "Configured serial device ${SERIAL_DEVICE} not found"
    
    # 尝试自动检测常见的eSIM设备
    AUTO_DETECTED=""
    for device in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyUSB2 /dev/ttyUSB3 /dev/ttyACM0 /dev/ttyACM1; do
        if [ -e "${device}" ]; then
            AUTO_DETECTED="${device}"
            bashio::log.info "Auto-detected serial device: ${device}"
            break
        fi
    done
    
    if [ -n "${AUTO_DETECTED}" ]; then
        bashio::log.info "Using auto-detected device: ${AUTO_DETECTED}"
        export SERIAL_DEVICE="${AUTO_DETECTED}"
        chmod 666 "${AUTO_DETECTED}"
    else
        bashio::log.warning "No suitable serial device found - continuing without serial device"
        bashio::log.info "Please check:"
        bashio::log.info "  1. eSIM module is connected via USB"
        bashio::log.info "  2. USB device is recognized by the system"
        bashio::log.info "  3. Update the 'serial_device' configuration if needed"
    fi
fi

# 初始化数据库
bashio::log.info "Initializing database..."
cd /app/backend
python manage.py migrate --noinput

# 收集静态文件
bashio::log.info "Collecting static files..."
python manage.py collectstatic --noinput

# 创建超级用户（如果不存在）
bashio::log.info "Creating superuser if not exists..."
python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin')
    print('Superuser created: admin/admin')
else:
    print('Superuser already exists')
EOF

# 启动服务
bashio::log.info "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
