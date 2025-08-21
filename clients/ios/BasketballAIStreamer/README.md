# 篮球AI推流应用

一个专为篮球比赛设计的iOS相机录制和RTMP推流应用。

## 功能特性

- 🎥 **高质量录制**: 支持1080p高清录制
- 📡 **实时推流**: RTMP协议推流到指定服务器
- 📱 **横屏优化**: 专为横屏使用设计
- 🎨 **原生界面**: 仿iOS原生相机界面设计
- 🔧 **简洁控制**: 只保留录制功能，界面简洁

## 系统要求

- iOS 15.0+
- iPhone/iPad
- 相机和麦克风权限

## 🚀 快速开始

### 项目状态
✅ **项目已修复完成！** 所有编译错误已解决，项目结构已优化。

### 系统要求
- iOS 14.0+ (推荐 iOS 15.0+)
- Xcode 14.0+ (需要完整版Xcode，不是命令行工具)
- Swift 5.7+
- 真实iOS设备（相机功能需要真机测试，模拟器不支持相机）

### 修复内容

- ✅ 修复了project.pbxproj中的配置错误
- ✅ 解决了Info.plist重复构建冲突问题
- ✅ 创建了完整的Assets.xcassets资源目录
- ✅ 配置了正确的Info.plist文件
- ✅ 优化了项目文件结构
- ✅ 移除了有问题的外部依赖
- ✅ 修复了相机初始化和显示问题
- ✅ 改进了相机权限检查和请求逻辑
- ✅ 修复了CameraPreviewView中的预览层设置问题
- ✅ 添加了详细的调试日志以便问题排查
- ✅ 优化了模拟器和真机环境的兼容性
- ✅ 添加了切换前后摄像头的功能按钮

### 构建步骤

#### 1. 打开项目
```bash
cd /Users/huyz/data/tool-verse/basketball-ai/clients/ios/BasketballAIStreamer
open BasketballAIStreamer.xcodeproj
```
或者直接双击 `BasketballAIStreamer.xcodeproj` 文件

#### 2. 配置开发者账号
- 在Xcode中选择项目
- 进入 "Signing & Capabilities" 选项卡
- 选择您的开发者团队
- 修改Bundle Identifier为唯一标识符

#### 3. 连接真机设备
- 用USB连接iPhone/iPad到Mac
- 在设备上信任开发者证书
- 在Xcode中选择你的设备作为运行目标

#### 4. 构建和运行
- 点击Xcode中的"Build"按钮（⌘+B）
- 点击"Run"按钮（⌘+R）
- 首次运行时需要在设备上信任开发者证书

### ⚠️ 重要提示

- **相机权限**: 应用首次启动时会请求相机和麦克风权限，请允许访问
- **真机测试**: 相机功能只能在真实设备上测试，模拟器无法使用相机
- **竖屏优化**: 应用已调整为竖屏方向，适合篮球拍摄场景

### 🔍 调试信息

应用会在Xcode控制台输出详细的调试信息：
- 相机权限状态检查
- 相机会话配置过程
- 设备输入添加状态
- 会话运行状态
- 预览层设置过程
- 视频方向配置信息

## 配置和使用

### 配置推流服务器

在应用中点击设置按钮，输入：
- **RTMP服务器地址**: 如 `rtmp://your-server.com/live`
- **推流密钥**: 您的推流密钥

### 使用说明

1. **录制视频**: 点击中央的录制按钮开始/停止录制
2. **开始推流**: 点击右侧的WiFi图标开始推流
3. **查看状态**: 顶部显示推流和录制状态

## 技术架构

### 核心组件

- **CameraManager**: 相机管理和AVFoundation封装，负责相机会话管理
- **ContentView**: 主界面和用户交互，包含相机预览和控制按钮
- **CameraPreviewView**: 相机预览显示，使用UIViewRepresentable封装
- **StreamingSettingsView**: 推流设置界面，配置RTMP服务器信息

### 关键修复和优化

- ✅ 修复了相机初始化时机问题，使用异步方法确保线程安全
- ✅ 改进了权限处理逻辑，添加详细状态日志
- ✅ 解决了@MainActor线程安全问题
- ✅ 移除了模拟器限制，专注真机开发
- ✅ 调整相机方向为竖屏，适合篮球拍摄
- ✅ 优化预览层更新逻辑，确保实时响应状态变化

### 视频配置

- **分辨率**: 1920x1080 (1080p)
- **码率**: 5Mbps
- **编码**: H.264
- **帧率**: 30fps

### 音频配置

- **码率**: 128kbps
- **采样率**: 44.1kHz
- **编码**: AAC
- **声道**: 立体声

## 推流服务器要求

支持的推流协议：
- RTMP (Real-Time Messaging Protocol)
- 支持H.264视频编码
- 支持AAC音频编码

推荐的推流服务：
- YouTube Live
- Twitch
- Facebook Live
- 自建RTMP服务器 (nginx-rtmp)

## 开发说明

### 项目结构
```
Sources/BasketballAIStreamer/
├── App.swift                 # 应用入口
├── ContentView.swift         # 主界面
├── CameraManager.swift       # 相机管理
├── Info.plist               # 应用配置
└── Assets.xcassets/         # 资源文件
    ├── AppIcon.appiconset/
    └── AccentColor.colorset/
```

### 权限配置

应用需要以下权限：
- `NSCameraUsageDescription`: 相机访问权限
- `NSMicrophoneUsageDescription`: 麦克风访问权限

### 横屏配置

应用强制横屏显示：
- `UISupportedInterfaceOrientations`: 仅支持横屏方向
- `UIStatusBarHidden`: 隐藏状态栏

## 故障排除

### 常见问题

#### Q: 相机无法启动
A: 检查以下几点：
1. 确保在真机上运行（模拟器不支持相机）
2. 检查相机权限是否已授予
3. 查看Xcode控制台的错误信息
4. 重启应用或重新安装

#### Q: 权限请求失败
A: 
1. 删除应用重新安装
2. 在设置->隐私->相机中检查权限状态
3. 确保Info.plist中有权限描述

#### Q: 编译错误
A:
1. 检查Xcode版本是否满足要求
2. 清理构建缓存（Product -> Clean Build Folder）
3. 重启Xcode
4. 确认开发者账号配置正确

#### Q: 无法连接推流服务器
- 检查网络连接
- 验证RTMP地址和密钥
- 确认服务器支持H.264/AAC编码

#### Q: 录制失败
- 检查存储空间
- 确认相机权限已授予
- 重启应用

#### Q: 预览黑屏或方向不对
- 检查相机权限
- 确认设备相机正常工作
- 应用已优化为竖屏方向
- 查看调试日志确认预览层设置

### 调试模式

在Xcode中运行时，控制台会输出详细的调试信息，帮助定位问题。

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request来改进这个项目。