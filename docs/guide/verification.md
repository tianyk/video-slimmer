# 验证与交付

## 常用命令

在仓库根目录执行，只有缺少依赖或修改依赖时才重新获取：

```bash
flutter --version
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id>
```

Dart 改动格式化修改文件，不对无关目录执行全量格式化：

```bash
dart format <修改的 Dart 文件>
flutter analyze --no-pub
flutter test --no-pub
# 定向验证现有 Live Activity 序列化契约
flutter test --no-pub test/models/live_activity_data_test.dart
```

涉及原生实现或插件时，在具备 Xcode / CocoaPods 的 macOS 环境验证：

```bash
flutter build ios --simulator --debug --no-pub
```

需要手动安装 Pods 时先在根目录 `flutter pub get`，再在 `ios/` 执行 `pod install`。真机运行需要主应用和 Widget 的签名、App Groups 与 provisioning；使用 `ios/Runner.xcworkspace`。

## 按风险选择验证

| 变更 | 最小合理验证 | 仍需注意 |
| --- | --- | --- |
| 文档 / AI 配置 | 路径、Markdown 链接、JSON 语法、配置加载、过时引用检查 | 无需为可逆文档编辑新增测试 |
| 文案 / 样式 | 修改文件格式、分析；语言包键 / 占位符检查；适用时界面走查 | 单测通过不能证明视觉正确 |
| 估算 / 状态 / 序列化 | 独立预期样例或相关现有测试；不足时补最小回归测试 | 不复制实现算法生成预期 |
| 队列 / 取消 / 重试 | 状态迁移、清空后重试、晚到回调、关闭生命周期 | mock 不能证明原生任务已停止 |
| Photos 保存 / 删除 | 保存失败不删除原片、部分成功、权限拒绝、系统拒绝删除 | 使用专用测试相册和可丢弃素材 |
| 编码器 / 元数据 | iOS 构建与设备样例，检查输出可播放、方向、音视频、元数据及大小 | 模拟器不能替代 VideoToolbox 真机验证 |
| 内购 | 商品 ID 一致、StoreKit 购买 / 取消 / 失败 / 恢复、权益状态 | 发布前用沙盒验证；不能发起真实收费 |
| Live Activity | 数据模型测试、iOS 构建、App Group 与原生结构、设备上的开始 / 更新 / 结束 | 本地配置存在不代表账户能力或设备行为已验收 |

新增永久测试前明确具体故障、预期依据、已有检查缺口及维护价值。优先扩展现有测试，允许一次性验证，不按方法数或覆盖率机械增加测试。

## 分析与环境问题

- 若已有 lint / 格式问题，报告基线与本次新增问题，不顺带格式化整个代码库或修改分析规则。
- 缺少 Flutter / Xcode / 设备或插件不可用时，继续可执行检查并说明未验证边界，不将未执行项标记为通过。
- 依赖故障先检查版本、错误日志和源配置。`flutter clean` 是排障选项，不是每次任务的前置步骤。
- 不默认执行 `pod deintegrate` 或删除 `Podfile.lock`、Pods、缓存；先尝试正常依赖安装 / 生成。
- 不把灵动岛显示、模拟器构建或 Dart 单测通过表述为后台压缩与全部 iOS 功能验收完成。

## 交付

检查 `git diff --check`、最终 diff 与新增文件，交付说明写清行为变化、实际验证和剩余限制。追加 Daily；仅在有长期价值时更新 Summary / Playbooks，不自动提交或推送。
