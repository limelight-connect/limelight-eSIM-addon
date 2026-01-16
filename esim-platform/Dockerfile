# Home Assistant Add-on Dockerfile for eSIM Platform
# Based on the main project Dockerfile but optimized for HA add-on environment

# ==================== 前端构建阶段 ====================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci --only=production

COPY frontend/ .

ARG NEXT_PUBLIC_BASE_PATH
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_DEV_API_URL
ENV NEXT_PUBLIC_BASE_PATH=$NEXT_PUBLIC_BASE_PATH
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_DEV_API_URL=$NEXT_PUBLIC_DEV_API_URL
ENV NODE_ENV=production

RUN npm run build

# ==================== 后端构建阶段 ====================
FROM python:3.11-slim AS backend-builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app/backend

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

COPY backend/requirements.txt .

RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .
RUN rm -rf data/ logs/ *.log

RUN mkdir -p logs staticfiles

# ==================== 最终运行镜像 ====================
FROM python:3.11-slim

ARG BUILD_ARCH
ARG VERSION=1.0.13
LABEL version=$VERSION
LABEL maintainer="eSIM Platform Team"
LABEL description="eSIM Platform - Home Assistant Add-on"
LABEL org.opencontainers.image.source="https://github.com/limelight-connect/esim-platform"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV NODE_ENV=production

ENV NEXT_PUBLIC_BASE_PATH=${NEXT_PUBLIC_BASE_PATH:-""}
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL:-""}
ENV NEXT_PUBLIC_DEV_API_URL=${NEXT_PUBLIC_DEV_API_URL:-""}

ENV LOG_LEVEL=INFO
ENV TIMEZONE=Asia/Shanghai
ENV SECRET_KEY=""
ENV DEBUG=False
ENV ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
ENV CORS_ALLOWED_ORIGINS=http://localhost,http://127.0.0.1
ENV SERIAL_DEVICE=/dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0
ENV DATA_RETENTION_DAYS=30
ENV MAX_UPLOAD_SIZE=50M
ENV API_TIMEOUT=300

# 安装系统依赖（追加热点/路由所需工具：hostapd/dnsmasq/iw/iptables）
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
        libqmi-utils \
        udhcpc \
        minicom \
        vim \
        hostapd \
        dnsmasq \
        iw \
        iptables \
        nftables \
        iproute2 \
        ebtables \
        bridge-utils \
        iputils-ping \
        git \
        tig \
        net-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=backend-builder /app/backend ./backend

COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r backend/requirements.txt

COPY --from=frontend-builder /app/frontend/.next/standalone ./frontend
COPY --from=frontend-builder /app/frontend/.next/static ./frontend/.next/static
COPY --from=frontend-builder /app/frontend/public ./frontend/public

RUN mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx-site.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY esim-platform/run.sh /run.sh
COPY docker/qmi.sh /usr/bin/qmi.sh
COPY docker/wifi-router.sh /usr/bin/wifi-router.sh
COPY docker/quectel-CM_x86_64 /usr/bin/quectel-CM
RUN chmod +x /run.sh /usr/bin/qmi.sh /usr/bin/wifi-router.sh /usr/bin/quectel-CM

# 避免 hostapd/dnsmasq 在容器启动时被默认服务启动（我们用脚本/API控制）
RUN systemctl mask hostapd 2>/dev/null || true \
 && systemctl mask dnsmasq 2>/dev/null || true

RUN mkdir -p /var/log/supervisor /var/run/nginx
RUN mkdir -p /data /config /ssl /addons /share /media /backup

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/api/healthz/ || exit 1

ENTRYPOINT ["/run.sh"]