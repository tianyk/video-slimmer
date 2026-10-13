# 待办与验收

2026-10-13 根据仓库文件整理。勾选项只表示实现或配置存在；外部服务与设备验收需另行确认，不沿用历史文档中的“已验证”结论。

## 仓库已包含

- [x] 相册视频浏览、排序、分辨率筛选和选择。
- [x] 压缩参数预设、大小估算、下载 / 压缩双队列、进度、取消和重试。
- [x] 保存压缩结果到相册，仅对成功保存的原视频请求删除。
- [x] 免费批量阈值、Pro 升级弹层、商品查询、购买和恢复购买代码。
- [x] StoreKit 本地商品配置及 Runner Scheme 关联。
- [x] Live Activity 数据模型、服务、压缩流程集成和 SwiftUI Widget Extension。
- [x] Runner / Widget 的 App Group entitlements 与 iOS 17.0 Deployment Target。
- [x] Live Activity 创建省略 null、更新可清除旧值的序列化回归测试。
- [x] 统一 AI 开发规则、开发指南和轻量工作记忆。

## 待确认与验收

- [ ] 在实际开发者账户确认 Runner / CompressionWidgetExtension 的 App Groups capability、签名和 provisioning。
- [ ] 设备验证灵动岛及锁屏视图的启动、更新、完成、取消与退出清理。
- [ ] 验证切换后台后的实际压缩行为，明确 iOS 后台执行限制；Live Activity 存在不能作为长期后台运行的证据。
- [ ] 使用专用素材验证本地 / iCloud 视频、取消 / 重试、输出可播放、元数据保留及保存失败不删除原片。
- [ ] 通过 StoreKit 本地测试验证商品查询、购买、取消、故障和恢复购买。
- [ ] 发布前确认 App Store Connect 商品 `cc.kekek.videoslimmer.pro`，并完成真机沙盒验收。
- [ ] 明确需要支持的其他平台，再逐一验收插件能力和原生桥接。

具体变更结果见 `.memory/daily/`；长期开发规则见 [AGENTS.md](AGENTS.md)。
