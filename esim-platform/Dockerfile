# Home Assistant Add-on Dockerfile for eSIM Platform
# Based on the main project Dockerfile but optimized for HA add-on environment

# ==================== 前端构建阶段 ====================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# 复制前端依赖文件（利用Docker缓存）
COPY frontend/package*.json ./

# 安装依赖（只有package.json变化时才重新安装）
RUN npm ci --only=production

# 复制前端源代码
COPY frontend/ .

# 设置构建时环境变量
ARG NEXT_PUBLIC_BASE_PATH
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_DEV_API_URL
ENV NEXT_PUBLIC_BASE_PATH=$NEXT_PUBLIC_BASE_PATH
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_DEV_API_URL=$NEXT_PUBLIC_DEV_API_URL
ENV NODE_ENV=production

# 构建前端应用
RUN npm run build

# ==================== 后端构建阶段 ====================
FROM python:3.11-slim AS backend-builder

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app/backend

# 安装系统依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gcc \
        libpq-dev \
        pkg-config \
        libffi-dev \
        libssl-dev \
        default-libmysqlclient-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 复制后端依赖文件（利用Docker缓存）
COPY backend/requirements.txt .

# 安装Python依赖（只有requirements.txt变化时才重新安装）
RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r requirements.txt

# 复制后端源代码（排除开发数据）
COPY backend/ .
# 删除开发时的数据库和日志文件
RUN rm -rf data/ logs/ *.log

# 创建必要的目录
RUN mkdir -p logs staticfiles

# ==================== 最终运行镜像 ====================
FROM python:3.11-slim

# 设置镜像版本标签
ARG BUILD_ARCH
ARG VERSION=1.0.13
LABEL version=$VERSION
LABEL maintainer="eSIM Platform Team"
LABEL description="eSIM Platform - Home Assistant Add-on"
LABEL org.opencontainers.image.source="https://github.com/limelight-connect/esim-platform"

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV NODE_ENV=production

# 前端环境变量（支持Home Assistant Add-on Ingress）
# 这些变量会被Home Assistant Add-on的options覆盖
ENV NEXT_PUBLIC_BASE_PATH=${NEXT_PUBLIC_BASE_PATH:-""}
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL:-""}
ENV NEXT_PUBLIC_DEV_API_URL=${NEXT_PUBLIC_DEV_API_URL:-""}

# HA Add-on 配置环境变量
ENV LOG_LEVEL=INFO
ENV TIMEZONE=Asia/Shanghai
ENV SECRET_KEY=""
ENV DEBUG=False
ENV ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
ENV CORS_ALLOWED_ORIGINS=http://localhost,http://127.0.0.1
ENV SERIAL_DEVICE=/dev/ttyUSB2
ENV DATA_RETENTION_DAYS=30
ENV MAX_UPLOAD_SIZE=50M
ENV API_TIMEOUT=300

# 安装系统依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        curl \
        nodejs \
        npm \
        procps \
        net-tools \
        jq \
        apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /app

# 从构建阶段复制后端应用
COPY --from=backend-builder /app/backend ./backend

# 安装Python依赖到最终镜像
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r backend/requirements.txt

# 从构建阶段复制前端构建产物
COPY --from=frontend-builder /app/frontend/.next/standalone ./frontend
COPY --from=frontend-builder /app/frontend/.next/static ./frontend/.next/static
COPY --from=frontend-builder /app/frontend/public ./frontend/public

# 创建nginx配置目录
RUN mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# 复制nginx配置
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx-site.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

# 复制supervisor配置
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 复制HA add-on特定的启动脚本
COPY ha-addon/esim-platform/run.sh /run.sh
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /run.sh /entrypoint.sh

# 使用root用户运行所有服务
# 注意：在HA add-on环境中，容器以root权限运行是安全的
# 因为HA Supervisor会管理容器的安全边界

# 注意：串口设备目录在运行时由HA supervisor创建和挂载

# 创建必要的目录
RUN mkdir -p /var/log/supervisor /var/run/nginx

# 创建HA add-on特定的目录结构
RUN mkdir -p /data /config /ssl /addons /share /media /backup

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/api/healthz/ || exit 1

# 设置entrypoint和启动服务
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/run.sh"]
