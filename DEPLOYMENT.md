# Home Assistant Add-on Deployment Guide

This guide explains how to deploy the eSIM Management Platform as a Home Assistant add-on.

## 📋 Prerequisites

- Home Assistant OS or Home Assistant Supervised
- Docker support enabled
- eSIM module (e.g., Quectel EG25-G) connected via USB
- Minimum 1GB RAM and 2GB free disk space

## 🏗️ Building the Add-on

### 1. Prepare the Environment

```bash
# Navigate to the ha-addon directory
cd /path/to/esim-platform/ha-addon

# Ensure backend and frontend directories exist in parent directory
ls ../backend ../frontend
```

### 2. Build the Docker Image

```bash
# Build for specific architecture and version
./build-addon.sh 1.0.13 amd64

# Or build for multiple architectures
./build-addon.sh 1.0.13 armv7
./build-addon.sh 1.0.13 aarch64
```

### 3. Test the Image Locally

```bash
# Test the built image
docker run -d -p 8080:8080 --name test-esim-addon limelight-eSIM-addon-amd64-1.0.13

# Check if it's running
docker ps | grep test-esim-addon

# Test the web interface
curl http://localhost:8080/api/healthz/

# Clean up test container
docker stop test-esim-addon && docker rm test-esim-addon
```

## 📦 Publishing the Add-on

### Option 1: GitHub Repository (Recommended)

1. **Create a GitHub repository** for the add-on:
   ```bash
   git init
   git add .
   git commit -m "Initial HA add-on release v1.0.13"
   git remote add origin https://github.com/limelight-connect/limelight-eSIM-addon.git
   git push -u origin main
   ```

2. **Create releases** for each version:
   - Go to GitHub repository → Releases → Create a new release
   - Tag version: `v1.0.13`
   - Upload the built Docker images as release assets

3. **Users can install** by adding the repository URL to Home Assistant:
   ```
   https://github.com/limelight-connect/limelight-eSIM-addon
   ```

### Option 2: Docker Registry

1. **Push images to registry**:
   ```bash
   # Tag for your registry
   docker tag limelight-eSIM-addon-amd64-1.0.13 limelight-connect/limelight-eSIM-addon-amd64-1.0.13
   
   # Push to registry
   docker push limelight-connect/limelight-eSIM-addon-amd64-1.0.13
   ```

2. **Update config.yaml** with registry image names:
   ```yaml
   image: limelight-connect/limelight-eSIM-addon-{arch}-{version}
   ```

## 🚀 Installation in Home Assistant

### Method 1: Repository Installation

1. **Add Repository**:
   - Open Home Assistant
   - Go to **Settings** → **Add-ons** → **Add-on Store**
   - Click the three dots menu (⋮) → **Repositories**
   - Add: `https://github.com/limelight-connect/limelight-eSIM-addon`

2. **Install Add-on**:
   - Find "eSIM Management Platform" in the add-on store
   - Click **Install**
   - Wait for installation to complete

3. **Configure**:
   - Click **Configuration** tab
   - Adjust settings as needed
   - Click **Save**

4. **Start**:
   - Click **Start**
   - Check logs if needed

### Method 2: Manual Installation

1. **Copy add-on files** to Home Assistant:
   ```bash
   # Copy to Home Assistant add-ons directory
   cp -r ha-addon/ /usr/share/hassio/addons/local/esim-platform/
   ```

2. **Restart Home Assistant** to detect the new add-on

3. **Install and configure** through the add-on store

## ⚙️ Configuration

### Required Settings

- **Serial Device**: Path to your eSIM module (e.g., `/dev/ttyUSB0`)
- **Timezone**: Your local timezone

### Optional Settings

- **Log Level**: `info` (recommended for production)
- **Debug Mode**: `false` (recommended for production)
- **Secret Key**: Leave empty for auto-generation
- **Data Retention**: `30` days (adjust as needed)

### Example Configuration

```yaml
log_level: info
timezone: Asia/Shanghai
debug: false
secret_key: ""
allowed_hosts: "localhost,127.0.0.1,0.0.0.0"
cors_allowed_origins: "http://localhost,http://127.0.0.1"
serial_device: "/dev/ttyUSB0"
data_retention_days: 30
max_upload_size: "50MB"
api_timeout: 300
```

## 🔧 Troubleshooting

### Common Issues

**Add-on won't start:**
```bash
# Check logs
docker logs addon_esim_platform

# Check configuration
cat /usr/share/hassio/addons/local/esim-platform/config.yaml
```

**Serial device not found:**
```bash
# List USB devices
lsusb

# Check device permissions
ls -la /dev/ttyUSB*

# Update device path in configuration
```

**Web interface not accessible:**
```bash
# Check if add-on is running
docker ps | grep esim

# Test health endpoint
curl http://homeassistant.local:8080/api/healthz/
```

### Logs

Access logs through:
- **Home Assistant UI**: Settings → Add-ons → eSIM Platform → Logs
- **SSH**: `docker logs addon_esim_platform`
- **Direct access**: `/usr/share/hassio/addons/local/esim-platform/logs/`

## 🔄 Updates

### Updating the Add-on

1. **Build new version**:
   ```bash
   ./build-addon.sh 1.0.14 amd64
   ```

2. **Update repository**:
   ```bash
   git add .
   git commit -m "Update to v1.0.14"
   git tag v1.0.14
   git push origin main --tags
   ```

3. **Users update** through Home Assistant add-on store

### Rollback

If issues occur after update:
1. Go to add-on configuration
2. Change version in config.yaml
3. Restart add-on

## 📊 Monitoring

### Health Checks

- Built-in health endpoint: `/api/healthz/`
- Automatic restart on failure
- Log monitoring through Home Assistant

### Metrics

- Prometheus metrics available at `/api/metrics/`
- Integration with Home Assistant monitoring
- Custom dashboard widgets possible

## 🔒 Security Considerations

### Production Deployment

1. **Change default passwords**:
   - Default: `admin/admin`
   - Use strong passwords

2. **Network security**:
   - Use Home Assistant's internal network
   - Configure firewall rules if needed

3. **Data protection**:
   - Regular backups of `/data` directory
   - Secure storage of configuration

### Backup

```bash
# Backup add-on data
tar -czf esim-backup-$(date +%Y%m%d).tar.gz /usr/share/hassio/addons/local/esim-platform/data/

# Restore from backup
tar -xzf esim-backup-20240101.tar.gz -C /
```

## 📞 Support

### Getting Help

1. **Check logs** first
2. **Review configuration** settings
3. **Test with minimal configuration**
4. **Open GitHub issue** with:
   - Home Assistant version
   - Add-on version
   - Error logs
   - Configuration (sanitized)

### Community

- GitHub Issues: Bug reports and feature requests
- Home Assistant Community: General discussions
- Documentation: This guide and README.md

---

**Note**: This deployment guide assumes familiarity with Home Assistant and Docker. For basic Home Assistant setup, refer to the official Home Assistant documentation.
