# Changelog

All notable changes to the eSIM Management Platform Home Assistant Add-on will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.13] - 2024-01-XX

### Added
- Initial release of eSIM Management Platform as Home Assistant add-on
- Complete web interface for eSIM device and profile management
- REST API with comprehensive endpoints for device and profile operations
- Real-time serial communication with eSIM modules
- Health monitoring and logging system
- Configurable settings through Home Assistant add-on interface
- Support for multiple architectures (amd64, armv7, armhf, aarch64)
- Automatic database initialization and superuser creation
- Static file serving and CORS configuration
- Data persistence with configurable retention policies

### Features
- **Device Management**: Full CRUD operations for eSIM devices
- **Profile Operations**: Download, enable, disable, and delete eSIM profiles
- **Serial Communication**: Direct communication with Quectel EG25-G and similar modules
- **Web Interface**: Modern, responsive UI built with Next.js and TypeScript
- **API Documentation**: Swagger UI for API exploration
- **Health Checks**: Built-in health monitoring with automatic restart
- **Logging**: Structured logging with configurable levels
- **Security**: Data masking, audit trails, and secure configuration

### Configuration Options
- Log level control (debug, info, warning, error)
- Timezone configuration
- Secret key management (auto-generation supported)
- Debug mode toggle
- Allowed hosts configuration
- CORS settings
- Serial device path configuration
- Data retention policies
- Upload size limits
- API timeout settings

### Technical Details
- **Base Image**: Python 3.11-slim with Node.js 18
- **Frontend**: Next.js 14 with TypeScript
- **Backend**: Django 5 with Django REST Framework
- **Database**: SQLite with automatic migrations
- **Web Server**: Nginx with optimized configuration
- **Process Management**: Supervisor for service orchestration
- **Container**: Multi-stage Docker build for optimized image size

### Security
- Non-root user execution
- Proper file permissions
- Data masking for sensitive information
- Secure default configuration
- CORS protection
- Input validation and sanitization

### Documentation
- Comprehensive README with installation and configuration instructions
- API documentation with Swagger UI
- Troubleshooting guide
- Security best practices
- Monitoring and logging information

## [Unreleased]

### Planned Features
- Integration with Home Assistant's authentication system
- MQTT integration for device status updates
- Backup and restore functionality
- Multi-device support improvements
- Advanced logging and analytics
- Custom dashboard widgets for Home Assistant
- Webhook support for external integrations
- Advanced profile management features

### Known Issues
- None at this time

### Breaking Changes
- None

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.13 | 2024-01-XX | Initial release |

## Support

For support and bug reports, please:
1. Check the troubleshooting section in the README
2. Review the add-on logs
3. Open an issue on the GitHub repository

## Contributing

Contributions are welcome! Please see the main project repository for contribution guidelines.
