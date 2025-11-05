# SegDemo - iOS 视频人像抠像性能测试 Demo

基于 Apple Vision Framework 的 iOS 视频人像抠像性能测试应用。

## 功能

- **性能测试**：测试不同设备、不同质量级别的单帧处理时间
- **人物抠图**：生成 mask 和抠图效果预览

## 性能数据

以下数据均来自本 Demo 实际测试：

### 单帧处理时间

| 设备 | 分辨率 | 质量级别 | 处理时间 |
|------|--------|---------|---------|
| iPhone 16 Plus | 1080p | Fast | ~7 ms |
| iPhone 16 Plus | 1080p | Balanced | ~15 ms |
| iPhone 16 Plus | 1080p | Accurate | ~75 ms |
| iPhone X | 1080p | Fast | ~89 ms |
| iPhone X | 1080p | Balanced | ~203 ms |
| iPhone X | 1080p | Accurate | ~568 ms |
| iPhone 7 | 1080p | Balanced | ~263 ms |
| iPhone 7 | 720p | Balanced | ~67 ms |

### 视频处理时长（30FPS）

**5 秒视频 (150帧)：**

| 设备 | 分辨率 | 质量级别 | 处理时间 |
|------|--------|---------|---------|
| iPhone 16 Plus | 1080p | Balanced | ~3.83 秒 |
| iPhone X | 1080p | Balanced | ~28 秒 |
| iPhone 7 | 1080p | Balanced | ~36 秒 |

**15 秒视频 (450帧)：**

| 设备 | 分辨率 | 质量级别 | 处理时间 |
|------|--------|---------|---------|
| iPhone 16 Plus | 1080p | Balanced | ~11.5 秒 |
| iPhone X | 1080p | Balanced | ~84 秒 |
| iPhone 7 | 1080p | Balanced | ~108 秒 |

## 使用

1. 使用 Xcode 打开 `SegDemo.xcodeproj`
2. 配置开发者账号
3. 运行到真机（iOS 15.0+）

### 功能说明

- **性能测试**：选择图片 → 选择质量级别 → 开始测试 → 查看结果
- **人物抠图**：选择图片 → 选择质量级别 → 生成 Mask → 查看效果 → 保存到相册

## 数据来源

**所有性能数据均来自本 Demo 的实际测试结果。**

测试方法：

- 使用真实人物图片进行测试
- 每个质量级别测试 10 次，取平均值
- 测试前进行 3 次预热

## 技术栈

- Vision Framework (`VNGeneratePersonSegmentationRequest`)
- SwiftUI
- CoreImage

## 注意事项

- 需要 iOS 15.0+
- 处理时不能锁屏或后台运行
- 不同设备性能差异较大

## 作者

VP工作室 / App开发组 / 杨锋
