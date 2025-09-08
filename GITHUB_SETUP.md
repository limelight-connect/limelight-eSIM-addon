# GitHub 仓库设置指南

## 🚀 创建GitHub仓库

### 1. 创建新仓库
1. 登录GitHub
2. 点击 "New repository"
3. 仓库名称: `limelight-eSIM-addon`
4. 描述: `Home Assistant Add-on: eSIM Management Platform`
5. 设置为公开仓库
6. 不要初始化README（我们已经有了）
7. 点击 "Create repository"

### 2. 添加远程仓库
```bash
# 在ha-addon目录中执行
git remote add origin https://github.com/limelight-connect/limelight-eSIM-addon.git
git branch -M main
git push -u origin main
```

### 3. 创建版本发布
```bash
# 创建标签
git tag v1.0.13
git push origin v1.0.13

# 在GitHub上创建Release
# 1. 进入仓库页面
# 2. 点击 "Releases" -> "Create a new release"
# 3. 选择标签: v1.0.13
# 4. 标题: eSIM Management Platform v1.0.13
# 5. 描述: 初始版本发布
# 6. 点击 "Publish release"
```

## 📦 用户安装指南

### 添加仓库到Home Assistant
1. 打开Home Assistant
2. 进入 **Settings** → **Add-ons** → **Add-on Store**
3. 点击右上角的三点菜单 (⋮)
4. 选择 **Repositories**
5. 添加仓库URL: `https://github.com/limelight-connect/limelight-eSIM-addon`
6. 点击 **Add**

### 安装Add-on
1. 在Add-on Store中找到 "eSIM Management Platform"
2. 点击 **Install**
3. 等待安装完成
4. 进入 **Configuration** 标签页
5. 配置串口设备路径（如 `/dev/ttyUSB2`）
6. 点击 **Save**
7. 点击 **Start** 启动服务

## 🔧 仓库结构说明

```
limelight-eSIM-addon/
├── config.json              # HA add-on配置文件
├── build.yaml               # 多架构构建配置
├── repository.json          # 仓库元数据
├── Dockerfile               # Docker镜像构建文件
├── run.sh                   # 启动脚本
├── build-addon.sh           # 构建脚本
├── README.md                # 项目说明文档
├── CHANGELOG.md             # 版本更新记录
├── DEPLOYMENT.md            # 部署指南
├── SERIAL_DEVICE_CONFIG.md  # 串口设备配置指南
├── MULTI_ARCH_SUPPORT.md    # 多架构支持说明
└── .gitignore              # Git忽略文件
```

## 📋 发布流程

### 1. 更新版本
```bash
# 更新config.json中的版本号
# 更新CHANGELOG.md
# 提交更改
git add .
git commit -m "Update to version 1.0.14"
git push origin main
```

### 2. 创建新版本标签
```bash
# 创建标签
git tag v1.0.14
git push origin v1.0.14
```

### 3. 在GitHub创建Release
1. 进入仓库页面
2. 点击 "Releases" → "Create a new release"
3. 选择新标签
4. 填写发布说明
5. 发布

## 🔄 持续集成建议

### GitHub Actions工作流
可以创建 `.github/workflows/build.yml` 来自动构建多架构镜像：

```yaml
name: Build Multi-Arch Docker Images

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          file: ./Dockerfile
          platforms: linux/amd64,linux/arm64,linux/arm/v7
          push: true
          tags: |
            your-registry/limelight-eSIM-addon:latest
            your-registry/limelight-eSIM-addon:${{ github.ref_name }}
```

## 📞 用户支持

### 问题报告
- 在GitHub Issues中报告问题
- 提供详细的错误日志
- 说明Home Assistant版本和硬件信息

### 功能请求
- 在GitHub Issues中提出功能请求
- 详细描述需求和使用场景

### 文档贡献
- 欢迎提交文档改进
- 通过Pull Request贡献代码

## 🎯 下一步计划

1. **添加图标文件**: icon.png 和 logo.png
2. **完善CI/CD**: GitHub Actions自动构建
3. **用户测试**: 收集用户反馈
4. **功能增强**: 根据需求添加新功能
5. **社区建设**: 建立用户社区

---

**仓库设置完成时间**: 2024-01-XX  
**状态**: ✅ 准备就绪  
**下一步**: 推送到GitHub并创建Release
