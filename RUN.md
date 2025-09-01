# 本地运行指南

## iOS设备运行步骤

### 方法一：自动证书生成（推荐）
```bash
# 启用自动签名
flutter run --device-id="永科的iPad" --allow-provisioning-updates
```

### 方法二：模拟器运行（无证书需求）
```bash
# 直接运行到模拟器
open -a Simulator
flutter run
```

### 方法三：手动配置Xcode
1. 打开项目：`open ios/Runner.xcworkspace`
2. 选择Runner -> Signing & Capabilities
3. 设置Team为你的Apple ID（无需付费账号）
4. 运行：`flutter run`

## 快速验证
```bash
# 检查项目状态
flutter clean
flutter pub get  
flutter build ios --simulator
```

> 对于个人开发者，只需一个免费的Apple ID即可在当前真机上测试！不需要付费开发者账号。