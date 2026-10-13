# Flutter / Dart 实现约定

## 语言与代码风格

- 使用 Dart null safety；公开 API、状态字段和原生数据转换明确类型，局部变量允许可靠的类型推断。
- `dynamic` 仅用于插件 / JSON / MethodChannel 等动态边界，进入业务模型时做明确转换；不要使用 TypeScript 的 `any`、`readonly` 或 `as const` 写法。
- 文件名 `lower_snake_case`，类型 `PascalCase`，变量 / 方法 / 常量 `camelCase`。使用 Dart formatter 和 `flutter_lints`，不要另设与工具冲突的排版规则。
- 优先不可变状态、`final` 和可行的 `const`。遵循已有模型的 Equatable、`copyWith` 模式；核对可空字段能否区分“保留旧值”和“清空值”。
- 函数按职责拆分，必要时提前返回；不为了机械行数限制拆出无意义抽象。
- 注释解释异步顺序、业务原因、原生约定和生命周期。文档及注释可用中文，代码标识符保持英文。

## Cubit 与异步流程

- 新业务状态使用 `flutter_bloc` 的 Cubit，在现有 `BlocProvider` / `MultiBlocProvider` 范围内提供依赖。
- 页面通过 `BlocBuilder` / `BlocSelector` 展示状态，通过 listener 处理提示、导航等副作用；避免在 `build()` 内启动购买、压缩或注册长期订阅。
- 将状态和事件放入现有 `models/` 体系；变更状态字段时检查所有读写方和相等性判断。
- 在异步完成后更新 UI / state 前检查适用的 `mounted` / `isClosed`，处理取消后的晚到结果，避免已关闭对象继续 `emit`。
- 创建长期订阅的对象应负责释放；`close()` / `dispose()` 清理订阅、队列、会话和活动，保持现有资源所有权。
- 队列清空可能使等待方抛出 `StateError`；不能将停止所有任务误写为关闭 Cubit，否则会破坏重试。
- 日志复用 `libs/logger.dart`。业务失败进入可观察的错误状态 / 提示；允许对非关键能力降级，但记录原因并保持核心流程可用。

## 页面、主题与组件

- 页面放 `screens/`，可复用组件放 `widgets/`；新增页面沿用 Navigator，除非任务明确包含路由改造。
- 复用 `AppBottomSheet`、`PrimaryActionButton`、`VideoThumbnail` 等现有组件；先查看组件参数和已有调用。
- 使用 `AppTheme` / `Theme.of(context)` 的颜色和样式，保持当前黑金主题；避免每页定义独立色彩、间距和按钮语义。
- 界面按需求呈现加载、空数据、权限拒绝、成功和错误状态，异步操作明确反馈并防止重复触发。
- 长列表复用现有分页、缩略图与并发控制方式；不要为了读取列表下载所有 iCloud 原文件。
- 组件按职责提取，避免大段重复 widget 树；复杂任务编排不要塞进 UI 回调。

## 国际化

用户可见 Dart 文案通过 `lib/src/libs/localization.dart` 的 `tr()` 获取，源文案目前使用中文键：

```dart
Text(tr('保存到相册'))
```

修改文案时同步 `assets/i18n/zh-CN.json`、`en-US.json`、`ja-JP.json` 的键与 `{placeholder}` 名称。参数化文案沿用现有调用的占位符替换方式；不要为普通文案另建 AppLocalizations 体系。

`LocalizationService` 在启动前加载语言包，fallback 为 `en-US`；缺少翻译时返回源文本，这一兜底不能替代补齐翻译。原生 Widget 使用独立 Swift 文案，修改时明确其本地化范围。

## 依赖与原生改动

- 先确认已有依赖是否能完成需求；通过 `flutter pub add` / `flutter pub remove` 管理依赖，并检查 `pubspec.yaml` 和 `pubspec.lock` 的 diff。
- 普通任务不升级 SDK、插件或清理历史依赖；升级任务需要检查插件 API、平台最低版本、Podfile 和 Widget 原生兼容性。
- Dart / Swift 桥接字段同时修改两端；Live Activity 创建省略 null，更新使用 `toMap(includeNullValues: true)` 清除旧值。
- 不把历史技术方案中的代码块复制为新实现；使用当前锁定插件版本和已有调用确认签名。
