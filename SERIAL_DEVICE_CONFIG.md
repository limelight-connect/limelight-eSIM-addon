# 串口设备配置指南

## 🔌 串口设备挂载配置

### 1. HA Add-on 配置

我们的 add-on 已经配置了完整的串口设备支持：

#### config.json 中的关键配置
```json
{
  "uart": true,           // 启用串口支持
  "udev": true,           // 启用udev设备管理
  "devices": [            // 预定义的串口设备列表
    "/dev/serial/by-id/usb-Quectel_EG25-GC-if00-port0",
    "/dev/serial/by-id/usb-Quectel_EG25-GC-if01-port0", 
    "/dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0",
    "/dev/serial/by-id/usb-Quectel_EG25-GC-if03-port0",
    "/dev/ttyACM0",
    "/dev/ttyACM1",
    "/dev/ttyACM2",
    "/dev/ttyACM3"
  ]
}
```

### 2. 支持的设备类型

#### USB 串口设备 (ttyUSB*)
- **Quectel EG25-G**: 通常映射到 `/dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0`
- **Quectel EC25**: 通常映射到 `/dev/serial/by-id/usb-Quectel_EG25-GC-if00-port0` 或 `/dev/serial/by-id/usb-Quectel_EG25-GC-if01-port0`
- **其他USB转串口设备**: 根据连接顺序映射到不同端口

#### USB CDC 设备 (ttyACM*)
- **某些eSIM模块**: 使用CDC模式，映射到 `/dev/ttyACM*`
- **Arduino设备**: 通常使用CDC模式

### 3. 自动设备检测

启动脚本会自动检测可用的串口设备：

```bash
# 自动检测逻辑
1. 列出所有可用的 /dev/ttyUSB* 和 /dev/ttyACM* 设备
2. 检查用户配置的 serial_device 是否存在
3. 如果配置的设备不存在，自动检测第一个可用的设备
4. 设置正确的设备权限 (666)
```

### 4. 设备权限管理

#### 容器内权限设置
```dockerfile
# 用户组配置
RUN usermod -a -G dialout appuser  # 串口设备访问组
RUN usermod -a -G tty appuser      # 终端设备访问组

# 设备权限
chmod 666 /dev/ttyUSB*             # 读写权限
chmod 666 /dev/ttyACM*             # 读写权限
```

#### 宿主机权限要求
- 设备文件必须对容器可访问
- 通常需要 `dialout` 组权限
- HA add-on 会自动处理权限映射

### 5. 配置选项

#### 用户配置
```yaml
# 在 add-on 配置中设置
serial_device: "/dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0"  # 指定具体的串口设备
```

#### 自动检测
如果未配置或配置的设备不存在，系统会：
1. 自动检测第一个可用的 USB 串口设备
2. 优先选择 `/dev/ttyUSB*` 设备
3. 如果 USB 设备不可用，尝试 `/dev/ttyACM*` 设备

### 6. 故障排除

#### 设备未找到
```bash
# 检查日志中的设备列表
bashio::log.info "Available serial devices:"
bashio::log.info "  - /dev/serial/by-id/usb-Quectel_EG25-GC-if00-port0 (crw-rw-rw- root dialout)"
bashio::log.info "  - /dev/serial/by-id/usb-Quectel_EG25-GC-if01-port0 (crw-rw-rw- root dialout)"
```

#### 权限问题
```bash
# 自动权限修复
chmod 666 /dev/ttyUSB* 2>/dev/null || true
```

#### 设备连接检查
```bash
# 在宿主机上检查设备
lsusb                           # 查看USB设备
ls -la /dev/ttyUSB*            # 查看串口设备
dmesg | grep tty               # 查看设备连接日志
```

### 7. 常见eSIM模块配置

#### Quectel EG25-G
```yaml
serial_device: "/dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0"  # 通常映射到USB2
```

#### Quectel EC25
```yaml
serial_device: "/dev/serial/by-id/usb-Quectel_EG25-GC-if00-port0"  # 通常映射到USB0
```

#### 其他模块
```yaml
# 使用自动检测，或根据实际设备调整
serial_device: "/dev/serial/by-id/usb-Quectel_EG25-GC-if01-port0"  # 根据实际情况调整
```

### 8. 动态设备管理

#### 热插拔支持
- HA add-on 支持设备热插拔
- 重启 add-on 后会自动检测新设备
- 支持设备重新连接

#### 多设备支持
```json
"devices": [
  "/dev/serial/by-id/usb-Quectel_EG25-GC-if00-port0",  // 支持多个设备同时挂载
  "/dev/serial/by-id/usb-Quectel_EG25-GC-if01-port0", 
  "/dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0",
  "/dev/serial/by-id/usb-Quectel_EG25-GC-if03-port0"
]
```

### 9. 安全考虑

#### 设备访问控制
- 只有配置的设备才会被挂载到容器
- 使用非root用户运行应用
- 设备权限最小化原则

#### 权限隔离
- 容器内用户只能访问指定的串口设备
- 无法访问宿主机的其他设备
- 符合HA add-on安全模型

### 10. 测试验证

#### 设备连接测试
```bash
# 在容器内测试设备访问
ls -la /dev/ttyUSB*
cat /dev/serial/by-id/usb-Quectel_EG25-GC-if02-port0  # 测试读取（需要设备响应）
```

#### 应用集成测试
```bash
# 检查应用是否能正确识别设备
curl http://localhost:8080/api/devices/
# 查看设备状态和连接信息
```

---

## 📋 配置检查清单

- [ ] 确认eSIM模块已正确连接到USB端口
- [ ] 检查宿主机是否识别设备 (`lsusb`, `ls /dev/ttyUSB*`)
- [ ] 在add-on配置中设置正确的 `serial_device` 路径
- [ ] 启动add-on并检查日志中的设备检测信息
- [ ] 验证应用能够访问串口设备
- [ ] 测试eSIM模块的AT命令通信

## 🔧 故障排除步骤

1. **检查设备连接**: 确认USB连接和电源
2. **查看系统日志**: 检查设备识别和驱动加载
3. **验证权限**: 确认设备文件权限正确
4. **测试通信**: 使用AT命令测试设备响应
5. **检查配置**: 确认add-on配置正确

---

**配置完成时间**: 2024-01-XX  
**支持状态**: ✅ 完全支持  
**测试状态**: 🔄 待测试
