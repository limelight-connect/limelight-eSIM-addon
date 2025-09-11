#!/bin/bash

# eSIM Platform Docker Entrypoint Script
# 解决数据库权限和初始化问题

set -e

echo "🚀 Starting eSIM Platform Docker container..."

# Function to fix database permissions
fix_database_permissions() {
    echo "🔧 Fixing database permissions..."
    
    # 确保数据目录存在
    mkdir -p /app/backend/data
    
    # 如果数据库文件存在但权限不对，修复权限
    if [ -f "/app/backend/data/db.sqlite3" ]; then
        echo "📁 Found existing database, fixing permissions..."
        chown -R appuser:appuser /app/backend/data
        chmod 664 /app/backend/data/db.sqlite3
        chmod 755 /app/backend/data
    else
        echo "📁 Creating new database directory..."
        chown -R appuser:appuser /app/backend/data
        chmod 755 /app/backend/data
    fi
    
    echo "✅ Database permissions fixed!"
}

# Function to wait for database to be ready (for SQLite, just check file permissions)
wait_for_db() {
    echo "⏳ Checking database readiness..."
    
    # 确保数据库文件可写
    if [ -f "/app/backend/data/db.sqlite3" ]; then
        if [ ! -w "/app/backend/data/db.sqlite3" ]; then
            echo "❌ Database file is not writable, fixing permissions..."
            chown appuser:appuser /app/backend/data/db.sqlite3
            chmod 664 /app/backend/data/db.sqlite3
        fi
    fi
    
    echo "✅ Database is ready!"
}

# Function to check if migrations are needed
check_migrations() {
    echo "🔍 Checking for pending migrations..."
    
    # 切换到后端目录
    cd /app/backend
    
    # 检查是否有待执行的迁移
    if python manage.py showmigrations --plan | grep -q "\[ \]"; then
        echo "📦 Applying pending migrations..."
        python manage.py migrate --noinput
        echo "✅ Migrations applied successfully!"
    else
        echo "✅ No pending migrations found."
    fi
}

# Function to create superuser if needed
create_superuser() {
    echo "👤 Checking for superuser..."
    
    cd /app/backend
    
    # 检查是否存在超级用户
    if ! python manage.py shell -c "from django.contrib.auth.models import User; print('SUPERUSER_EXISTS' if User.objects.filter(is_superuser=True).exists() else 'NO_SUPERUSER')" | grep -q "SUPERUSER_EXISTS"; then
        echo "🔧 Creating default superuser..."
        python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
"
    else
        echo "✅ Superuser already exists."
    fi
}

# Function to collect static files
collect_static() {
    echo "📁 Collecting static files..."
    
    cd /app/backend
    python manage.py collectstatic --noinput
    echo "✅ Static files collected!"
}

# Function to fix log file permissions before Django starts
fix_log_permissions() {
    echo "🔧 Fixing log file permissions before Django starts..."
    
    # 确保日志目录存在
    mkdir -p /app/backend/logs
    
    # 删除可能存在的日志文件
    rm -f /app/backend/logs/esim_platform.log
    
    # 创建新的日志文件并设置正确权限
    touch /app/backend/logs/esim_platform.log
    chown appuser:appuser /app/backend/logs/esim_platform.log
    chmod 664 /app/backend/logs/esim_platform.log
    
    echo "✅ Log file permissions fixed!"
}

# Function to fix all permissions
fix_all_permissions() {
    echo "🔧 Fixing all application permissions..."
    
    # 修复后端目录权限
    chown -R appuser:appuser /app/backend
    chmod -R 755 /app/backend
    
    # 修复前端目录权限
    chown -R appuser:appuser /app/frontend
    chmod -R 755 /app/frontend
    
    # 修复日志目录权限
    mkdir -p /var/log/supervisor
    chown -R appuser:appuser /var/log/supervisor
    chmod -R 755 /var/log/supervisor
    
    # 修复应用日志目录权限
    mkdir -p /app/backend/logs
    chown -R appuser:appuser /app/backend/logs
    chmod -R 755 /app/backend/logs
    
    # 如果日志文件已存在但权限不对，删除并重新创建
    if [ -f "/app/backend/logs/esim_platform.log" ]; then
        rm -f /app/backend/logs/esim_platform.log
        touch /app/backend/logs/esim_platform.log
        chown appuser:appuser /app/backend/logs/esim_platform.log
        chmod 664 /app/backend/logs/esim_platform.log
    fi
    
    echo "✅ All permissions fixed!"
}

# Main execution
main() {
    echo "🔧 Initializing eSIM Platform..."
    
    # 修复所有权限
    fix_all_permissions
    
    # 修复数据库权限
    fix_database_permissions
    
    # 检查数据库准备就绪
    wait_for_db
    
    # 应用迁移
    check_migrations
    
    # 迁移后再次修复数据库权限
    fix_database_permissions
    
    # 创建超级用户
    create_superuser
    
    # 收集静态文件
    collect_static
    
    # 最后修复日志文件权限
    fix_log_permissions
    
    echo "🎉 Initialization completed! Starting application..."
    
    # 执行主命令
    exec "$@"
}

# Run main function with all arguments
main "$@"
