# eSIM Management Platform - Home Assistant Add-on

A comprehensive eSIM management system designed to run as a Home Assistant add-on, providing unified management of eSIM devices and profiles through a modern web interface.

## 🏗️ Features

- **Device Management**: Manage eSIM devices and their profiles
- **Profile Operations**: Download, enable, disable, and delete eSIM profiles
- **Real-time Monitoring**: Live device status and communication logs
- **Web Interface**: Modern, responsive web UI built with Next.js
- **REST API**: Full REST API for integration with other systems
- **Serial Communication**: Direct communication with eSIM modules via serial ports
- **Data Persistence**: SQLite database with configurable data retention
- **Health Monitoring**: Built-in health checks and monitoring

## 📋 Requirements

- Home Assistant OS or Home Assistant Supervised
- eSIM module (e.g., Quectel EG25-G) connected via USB
- Minimum 1GB RAM
- 2GB free disk space

## 🚀 Installation

1. **Add the repository to Home Assistant**:
   - Go to **Settings** → **Add-ons** → **Add-on Store**
   - Click the three dots menu (⋮) → **Repositories**
   - Add repository URL: `https://github.com/limelight-connect/limelight-eSIM-addon`

2. **Install the add-on**:
   - Find "eSIM Management Platform" in the add-on store
   - Click **Install**
   - Wait for the installation to complete

3. **Configure the add-on**:
   - Click **Configuration** tab
   - Adjust settings as needed (see Configuration section below)
   - Click **Save**

4. **Start the add-on**:
   - Click **Start**
   - Wait for the service to start (check logs if needed)

5. **Access the web interface**:
   - Open the add-on in your browser
   - Default login: `admin` / `admin`
   - **Important**: Change the default password after first login

## ⚙️ Configuration

### Basic Settings

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| **Log Level** | Application log level | `info` | No |
| **Timezone** | System timezone | `Asia/Shanghai` | No |
| **Debug Mode** | Enable debug mode | `false` | No |
| **Secret Key** | Django secret key (auto-generated if empty) | `""` | No |

### Network Settings

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| **Allowed Hosts** | Comma-separated list of allowed hosts | `localhost,127.0.0.1,0.0.0.0` | No |
| **CORS Allowed Origins** | CORS allowed origins | `http://localhost,http://127.0.0.1` | No |

### Device Settings

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| **Serial Device** | Path to serial device | `/dev/ttyUSB2` | Yes |
| **Data Retention Days** | Log data retention period | `30` | No |
| **Max Upload Size** | Maximum file upload size | `50MB` | No |
| **API Timeout** | API request timeout (seconds) | `300` | No |

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

## 🌐 Web Interface

### Access URLs

- **Main Interface**: `http://homeassistant.local:8080`
- **API Documentation**: `http://homeassistant.local:8080/api/schema/swagger-ui/`
- **Admin Interface**: `http://homeassistant.local:8080/admin/`
- **Health Check**: `http://homeassistant.local:8080/api/healthz/`

### Default Login

- **Username**: `admin`
- **Password**: `admin`

**⚠️ Security Note**: Change the default password immediately after first login!

## 📚 API Endpoints

### Health & Monitoring
- `GET /api/healthz/` - Health check endpoint
- `GET /api/metrics/` - Prometheus metrics

### Device Management
- `GET /api/devices/` - List all devices
- `POST /api/devices/` - Create new device
- `GET /api/devices/{id}/` - Get device details
- `GET /api/devices/{id}/eid` - Get device EID
- `GET /api/devices/{id}/profiles` - List device profiles

### Profile Operations
- `POST /api/devices/{id}/download` - Download profile (external mode)
- `POST /api/devices/{id}/ota` - OTA activation (internal mode)
- `POST /api/profiles/{iccid}/enable` - Enable profile
- `POST /api/profiles/{iccid}/disable` - Disable profile
- `POST /api/profiles/{iccid}/delete` - Delete profile

## 🔧 Troubleshooting

### Common Issues

**Add-on won't start:**
1. Check the add-on logs in Home Assistant
2. Verify serial device path is correct
3. Ensure sufficient disk space and memory

**Serial device not found:**
1. Check if the eSIM module is properly connected
2. Verify the device path in configuration
3. Check USB permissions (device should be accessible)

**Web interface not accessible:**
1. Verify the add-on is running
2. Check port 8080 is not blocked
3. Try accessing via Home Assistant's internal network

**API errors:**
1. Check backend logs in the add-on logs
2. Verify configuration settings
3. Test health endpoint: `/api/healthz/`

### Logs

Access logs through:
- **Home Assistant**: Settings → Add-ons → eSIM Management Platform → Logs
- **SSH**: `docker logs addon_esim_platform`

### Support

For issues and support:
1. Check the troubleshooting section above
2. Review add-on logs
3. Open an issue on the GitHub repository

## 🔒 Security

### Data Protection
- All sensitive data (EID, ICCID, activation codes) is masked in logs
- Database is stored in Home Assistant's secure data directory
- All operations are logged with timestamps

### Access Control
- Change default admin password immediately
- Use strong passwords for production environments
- Consider using Home Assistant's authentication system

### Network Security
- Add-on runs in Home Assistant's secure container environment
- CORS is properly configured
- API endpoints are protected

## 📊 Monitoring

### Health Checks
- Built-in health monitoring
- Automatic service restart on failure
- Prometheus metrics endpoint available

### Logs
- Structured logging with configurable levels
- Log rotation and retention policies
- Integration with Home Assistant's logging system

## 🔄 Updates

The add-on will automatically check for updates through Home Assistant's add-on store. To update:

1. Go to **Settings** → **Add-ons** → **eSIM Management Platform**
2. Click **Update** if available
3. Restart the add-on after update

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📞 Support

- **Documentation**: Check this README and the main project documentation
- **Issues**: Open an issue on GitHub
- **Community**: Join our community discussions

---

**Note**: This add-on is designed to work seamlessly with Home Assistant's ecosystem while providing powerful eSIM management capabilities.
