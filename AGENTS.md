# AI 开发约定

本文件是所有 AI 编码工具的统一入口。沟通、评审和开发文档默认使用中文；代码标识符遵循 Dart / Swift 的习惯。

## 1. 项目事实与边界

- Video Slimmer 是 Flutter 视频压缩应用，当前主要实现和验收平台为 **iOS 17.0+**。
- 状态管理使用 **Cubit / flutter_bloc**，页面导航使用 **Navigator + MaterialPageRoute**。
- 视频处理使用 `ffmpeg_kit_flutter_new`，相册访问使用 `photo_manager` 和 `permission_handler`。
- 内购使用 `in_app_purchase`；实时活动使用 `live_activities`、ActivityKit 和 SwiftUI Widget Extension。
- `pubspec.yaml` 中仍有 Riverpod / go_router 依赖，但当前 `lib/` 未使用，不能据此建立另一套状态管理或路由体系。
- Android、macOS、Linux、Windows、Web 目录的存在不代表功能已适配。涉及跨平台行为时，检查插件和原生实现，并明确实际验证范围。

```text
lib/main.dart          启动、本地化、全局错误处理、全局 PurchaseCubit
lib/src/cubits/        业务状态与任务编排
lib/src/models/        数据、配置、状态和事件
lib/src/services/      权限、本地化、内购和实时活动服务
lib/src/screens/       页面与导航
lib/src/widgets/       可复用 UI
lib/src/constants/     常量与主题
lib/src/libs/          日志、本地化入口、异步队列
assets/i18n/           zh-CN / en-US / ja-JP JSON 文案
ios/Runner/            Photos 原生桥接、权限和主应用配置
ios/CompressionWidget/ 实时活动 SwiftUI 扩展
test/                  Flutter 测试
docs/guide/            开发指导
.memory/               跨任务工作记忆
```

## 2. 工作顺序与文档职责

1. 阅读本文件、`.memory/SUMMARY.md` 和最近 3 条 Daily；记忆不存在时直接继续。仅在相关时读取 `.memory/PLAYBOOKS.md`。
2. 执行 `git status --short`，识别已有修改；读取任务对应文档、配置、调用方与实现后再编辑。
3. 以用户当前要求为准，仓库规则约束实现方式，PRD 定义产品行为，代码和配置说明当前事实。技术方案中的历史示例不能替代实际 API。
4. 按任务范围实施，优先复用已有模型、Cubit、服务和组件。发现不一致时修正本任务相关文档；需求歧义影响用户数据、付费权益或平台支持承诺时先澄清。
5. 完成与风险相称的验证，检查 diff，并说明结果和未验证项；最后追加一条 Daily。

文档分工：

- `README.md`：环境、常用命令、文档导航和 AI 工具使用入口。
- `AGENTS.md`：稳定的仓库约束和任务阅读索引；指南承载具体实现约定。
- `PRD.md`：需求、用户流程和产品规则；`TODO.md`：当前待办和待验收项。
- `docs/TECH_SPEC_*.md`：功能设计、协议与历史方案。新增较大方案可以放入 `docs/design/`，不必迁移已有文件。
- `.memory/`：结果、长期决策和可复用经验，不复制 PRD 或开发指南。
- `CLAUDE.md` 只指向本文件，不维护第二份规则。项目不依赖 Cursor 配置。

普通功能任务不顺带重写开发规则。用户要求文档、规范或 AI 配置改造时，可直接更新相关规则，无需再次确认已授权的工作。

## 3. 实现约束

- Dart 文件和目录使用 `lower_snake_case`，类型使用 `PascalCase`，成员使用 `camelCase`；格式以 `dart format` 为准，分析规则以 `analysis_options.yaml` 为准。
- 新状态与业务流程沿用 Cubit；不可变数据优先使用 `final`、`const` 和现有 `copyWith` / Equatable 模式。
- 页面负责展示和交互，Cubit 负责状态和编排，服务负责插件能力。允许维护现有 Cubit 中的 FFmpeg / Photos 调用，不要求为了分层进行无关重构。
- 不自动引入 Riverpod、AutoRoute、freezed、get_it 或新架构层；新增依赖必须确实服务当前任务。
- 使用 `AppTheme` / `Theme.of(context)`、已有弹层与按钮组件；用户可见文案使用 `tr()`，参数化文案沿用现有占位符替换方式，同步三份语言包的键和占位符。
- 关键异步状态、原生协议、资源释放和非直观业务规则补简洁注释，不设机械的函数行数或类大小限制。
- 异步回调考虑页面 / Cubit 生命周期，正确释放订阅、队列、FFmpeg 会话和实时活动；不要吞掉会影响结果的异常。
- 依赖操作使用 `flutter pub`；`pubspec.lock` 是应用依赖基准，应纳入版本控制。不要在普通功能任务中执行 `flutter pub upgrade` 或手改锁文件。
- 不手改 `.dart_tool/`、`build/`、`Pods/`、插件注册文件或平台 `ephemeral/` 产物。遇到生成问题先检查源配置和生成命令。

## 4. 关键业务与原生契约

- 压缩由下载 / 压缩双队列编排；取消终止当前处理，重试从头开始，不描述为暂停恢复。
- `cancelAllCompression()` 清空队列后调度循环继续等待重试；`close()` 才结束调度生命周期。修改时检查晚到回调和状态覆盖。
- **只有成功保存压缩结果的原视频才可进入删除列表**；保存失败、权限拒绝或系统拒绝删除不得被当作完整成功。
- 免费批量阈值和内购商品 ID 以 `AppConstants` 为准；权益变更沿用购买事件流，不能把本地缓存等同于服务端收据验证。
- Photos MethodChannel 名为 `cc.kekek.videoslimmer`。修改方法、参数或返回值时同步 Dart 调用方与 `ios/Runner/AppDelegate.swift`。
- 实时活动 App Group 为 `group.cc.kekek.videoslimmer`。修改时同步服务、Widget UserDefaults 与 entitlements。
- Widget 的 `LiveActivitiesAppAttributes` / `ContentState` 必须匹配锁定插件的原生定义；不能照抄旧方案中的字段结构。
- Live Activity 创建数据省略 null；更新数据可携带 null 以移除旧值。修改时保留现有序列化测试的保护。
- 实时活动显示进度不等于 iOS 保证长期后台压缩；声明后台能力必须有对应实现与设备验证。
- 所有视频处理保持在设备本地。自动验证使用专用测试视频，不操作用户真实相册或发起真实付费。

## 5. 任务 → 文档索引

| 任务 | 先读 |
| --- | --- |
| 熟悉项目 / 调整架构 | `docs/guide/overview.md`、`pubspec.yaml`、`lib/main.dart` |
| Dart / Flutter 编码、页面、状态 | `docs/guide/flutter.md`、相关 Cubit / model / screen |
| 主题与公共 UI | `docs/guide/flutter.md`、`lib/src/constants/app_theme.dart`、相关 widgets |
| 文案与国际化 | `docs/guide/flutter.md`、`lib/src/libs/localization.dart`、`assets/i18n/` |
| 压缩、取消、重试、保存 | `PRD.md`、`docs/TECH_SPEC_COMPRESSION.md`、`compression_progress_cubit.dart` |
| 相册元数据、权限、iCloud | `video_data_cubit.dart`、`permission_service.dart`、`ios/Runner/AppDelegate.swift`、`ios/Podfile`、`ios/Runner/Info.plist` |
| Pro 权益、购买、恢复购买 | `docs/TECH_SPEC_IAP.md`、`purchase_service.dart`、`purchase_cubit.dart`、`app_constants.dart`、`ios/Runner/StoreKitConfig.storekit` |
| 灵动岛 / 锁屏活动 | `docs/TECH_SPEC_LIVE_ACTIVITY.md`、`live_activity_service.dart`、`live_activity_data.dart`、`ios/CompressionWidget/`、相关 entitlements |
| 测试与交付 | `docs/guide/verification.md`、相关 `test/` 文件 |
| 环境故障 | `TROUBLESHOOTING.md`、对应平台配置 |
| 当前进度 | `TODO.md`、相关 Daily；功能存在和验收通过分别判断 |

表格中的 Dart 文件名均位于上述 `lib/src/` 对应目录；用搜索定位，不据此创建同名的新文件。

## 6. 验证与交付

- 文档 / AI 配置改动：检查链接、路径、配置语法、工具加载和过时引用，不强制构建应用。
- Dart 逻辑改动：格式化修改的文件，执行 `flutter analyze --no-pub` 与相关 `flutter test --no-pub`；需要依赖初始化时先 `flutter pub get`。
- 原生 / 插件改动：在具备环境时增加 `flutter build ios --simulator --debug --no-pub`；Photos、硬件编码、沙盒支付、实时活动按风险补设备验证。
- 按故障风险决定复用已有测试、一次性验证或新增永久测试；不要求每个公开方法都写测试，不通过降低规则、删断言或跳过失败伪造通过。
- 既有分析告警与本次新增问题分开说明。检查失败时报告原因和影响；环境不可用时明确未执行项，不声称真机验收通过。
- 交付说明包含改了什么、为什么、实际验证和剩余限制；不自动提交、推送或发布。

## 7. 工作记忆

参考 hdims 的 Daily / Summary / Playbooks 分层，控制体积：

- **Daily**：每次任务结束向 `.memory/daily/YYYY-MM-DD.md` 追加一条，使用东八区时间；只写结果、关键决策及未完成项，不覆盖历史。
- **Summary**：仅在产生长期有效的架构约束、决策或高价值踩坑经验时更新 `.memory/SUMMARY.md`；最多 20 条，优先合并和替换过时项，不复制规则。
- **Playbooks**：同类问题重复出现并形成稳定检查步骤时，更新 `.memory/PLAYBOOKS.md`；默认最多 7 个，没有经验时留空，不为凑数量创建。
- 每累计约 20 条任务记录时检查 Summary / Playbooks 的重复与失效项；Daily 保留历史，不自动删除。
- 三层记忆均纳入版本控制；不记录密钥、账户信息或用户视频路径。

Daily 格式：

```markdown
## HH:MM [codex / claude-code / 实际工具名]
- 完成：一句话结果
- 决策：关键选择及原因（可省略）
- 验证：执行结果或未验证范围
- 待办：阻塞或待验收项（可省略）
```
