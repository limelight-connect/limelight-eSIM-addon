#!/bin/bash

# eSIM Platform 开发环境启动脚本
# 支持代码热更新

set -e

echo "🚀 启动 eSIM Platform 开发环境 (Django + Frontend + Nginx)..."

# 进入后端目录
cd /app/backend

# 创建数据目录
echo "📁 创建数据目录..."
mkdir -p data

# 数据库迁移
echo "📊 执行数据库迁移..."
python manage.py migrate --noinput

# 收集静态文件
echo "📁 收集静态文件..."
python manage.py collectstatic --noinput

# 创建超级用户（如果不存在）
echo "👤 检查超级用户..."
python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('超级用户已创建: admin/admin123')
else:
    print('超级用户已存在')
"

# 返回根目录
cd /app

# 启动supervisor管理所有服务
echo "🎯 启动开发服务 (Django + Frontend + Nginx)..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
