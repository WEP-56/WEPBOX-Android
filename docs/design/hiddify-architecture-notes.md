# Hiddify 架构参考笔记

## 1. 结论

`example/hiddify-app` 是当前最适合作为主参考的项目。它不是简单的 Flutter UI 壳，而是完整的 Flutter + Android service + hiddify-core/sing-box 客户端架构。

最值得复用的不是它的 UI，而是这些工程边界：

- Flutter feature 分层。
- Riverpod repository/notifier 状态管理。
- Profile 导入、校验、落盘、激活链路。
- Connection 启停链路。
- Android VPN/Proxy 前台服务。
- Dart 与 Android 之间的 MethodChannel/EventChannel。
- Dart 与 core 之间的 gRPC stream。

核心链路可以概括为：

```text
UI
  -> Riverpod Notifier
  -> Repository
  -> HiddifyCoreService
  -> CoreInterfaceMobile
  -> MethodChannel / EventChannel
  -> Android MethodHandler / EventHandler
  -> BoxService / VPNService / ProxyService
  -> hiddify-core / sing-box
```

## 2. 项目结构

Hiddify 的主要目录：

```text
lib/
  bootstrap.dart
  main.dart
  core/
    db/
    directories/
    preferences/
    router/
    theme/
  features/
    connection/
    profile/
    proxy/
    settings/
    stats/
    log/
    per_app_proxy/
  hiddifycore/
    core_interface/
    generated/
    hiddify_core_service.dart
  singbox/
    model/

android/app/src/main/kotlin/com/hiddify/hiddify/
  MainActivity.kt
  MethodHandler.kt
  EventHandler.kt
  PlatformSettingsHandler.kt
  LogHandler.kt
  bg/
    BoxService.kt
    VPNService.kt
    ProxyService.kt
    ServiceConnection.kt
    ServiceNotification.kt

hiddify-core/
```

这套结构可以直接指导我们的项目分层。建议我们保留 `core/features/singbox/platform` 这种边界，但减少 Hiddify 中暂时用不到的桌面端、Sentry、系统托盘、多语言规模。

## 3. 启动初始化

入口在 `lib/bootstrap.dart`。

初始化顺序大致是：

1. 保留 splash。
2. 初始化日志。
3. 创建 `ProviderContainer` 并注入 environment。
4. 初始化 app directories。
5. 初始化 app info。
6. 初始化 SharedPreferences。
7. 执行 preferences migration。
8. 初始化窗口/托盘等桌面能力。
9. 初始化 log repository。
10. 初始化 profile repository。
11. 初始化 translations。
12. 读取 active profile。
13. 初始化 `hiddify-core`。
14. 启动 `ProviderScope` 和 App。

可参考点：

- 所有关键基础设施都通过 Riverpod provider 初始化。
- 启动过程用 `_init(name, initializer)` 包装，日志清晰。
- 非关键功能用 `_safeInit`，失败不阻塞主程序。
- `hiddify-core` 初始化在 profile 之后，因为 core 需要目录、偏好设置、profile 等上下文。

我们可以简化为：

```text
directories
logger
preferences
database
profileRepository
singboxCore
runApp
```

## 4. 连接启停链路

### 4.1 Dart 业务层

关键文件：

- `lib/features/connection/notifier/connection_notifier.dart`
- `lib/features/connection/data/connection_repository.dart`
- `lib/hiddifycore/hiddify_core_service.dart`

`ConnectionNotifier` 负责 UI 可见状态和用户动作：

- `toggleConnection()`
- `mayConnect()`
- `reconnect(profile)`
- `abortConnection()`

它不会直接调用 Android，而是调用 `ConnectionRepository`。

`ConnectionRepository` 定义了核心接口：

```dart
abstract interface class ConnectionRepository {
  SingboxConfigOption? get configOptionsSnapshot;

  TaskEither<ConnectionFailure, Unit> setup();
  Stream<ConnectionStatus> watchConnectionStatus();
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity activeProfile, bool disableMemoryLimit);
  TaskEither<ConnectionFailure, Unit> disconnect();
  TaskEither<ConnectionFailure, Unit> reconnect(ProfileEntity activeProfile, bool disableMemoryLimit);
}
```

连接动作：

```text
connect(activeProfile)
  -> setup()
  -> applyConfigOption(activeProfile)
  -> singbox.start(profileConfigPath, profileName, disableMemoryLimit)
```

断开动作：

```text
disconnect()
  -> singbox.stop()
```

重连动作：

```text
reconnect(activeProfile)
  -> applyConfigOption(activeProfile)
  -> singbox.restart(profileConfigPath, profileName, disableMemoryLimit)
```

### 4.2 Core service 层

`HiddifyCoreService` 封装 core 能力：

- `setup()`
- `changeOptions()`
- `start(path, name, disableMemoryLimit)`
- `stop()`
- `restart(path, name, disableMemoryLimit)`
- `watchStatus()`
- `watchStats()`
- `watchGroup()`
- `watchActiveGroups()`
- `selectOutbound()`
- `urlTest()`
- `watchLogs()`

`start()` 的主要流程：

```text
status = starting
core.setupBackground(path, name)
  -> Android MethodChannel start
  -> Android 启动 service
等待 bg gRPC 端口可用
core.bgClient.start(StartRequest)
status 通过 gRPC/EventChannel 更新
```

`stop()` 的主要流程：

```text
core.bgClient.stop()
core.stop()
status = stopped
```

### 4.3 Android 层

关键文件：

- `android/.../MainActivity.kt`
- `android/.../MethodHandler.kt`
- `android/.../EventHandler.kt`
- `android/.../bg/BoxService.kt`
- `android/.../bg/VPNService.kt`
- `android/.../bg/ProxyService.kt`

`MainActivity` 注册插件：

```text
MethodHandler
PlatformSettingsHandler
EventHandler
LogHandler
```

`MethodHandler` 处理 MethodChannel：

- `setup`
- `start`
- `stop`
- `restart` 目前注释掉
- `get_grpc_server_public_key`
- `add_grpc_client_public_key`

`start` 方法会设置：

```text
Settings.activeConfigPath
Settings.activeProfileName
Settings.grpcServiceModePort
Settings.debugMode
```

然后调用：

```text
MainActivity.instance.startService()
```

`MainActivity.startService()` 会：

1. 检查 Android 13+ 通知权限。
2. rebuild service mode。
3. 如果是 VPN mode，执行 `VpnService.prepare()`。
4. 启动前台服务。
5. 设置 `startedByUser = true`。

## 5. MethodChannel / EventChannel

### 5.1 Dart 移动端接口

关键文件：

- `lib/hiddifycore/core_interface/core_interface_mobile.dart`

channel：

```dart
static const channelPrefix = "com.hiddify.app";
static const methodChannel = MethodChannel("$channelPrefix/method");
static const statusChannel = EventChannel("$channelPrefix/service.status", JSONMethodCodec());
static const alertsChannel = EventChannel("$channelPrefix/service.alerts", JSONMethodCodec());
```

固定端口：

```dart
static const portBack = 17079;
static const portFront = 17078;
```

移动端核心通信有两种通道：

- MethodChannel：负责 setup/start/stop 这类平台动作。
- gRPC：负责 core 的业务 API、状态流、日志流、proxy group、stats。

### 5.2 Android 状态和告警

关键文件：

- `android/.../EventHandler.kt`

状态通道：

```text
com.hiddify.app/service.status
```

告警通道：

```text
com.hiddify.app/service.alerts
```

Android 会观察 `MainActivity.instance.serviceStatus` 和 `serviceAlerts`，然后把 map 发给 Dart。

状态 map：

```text
{ "status": "Started" }
```

告警 map：

```text
{
  "status": "Stopped",
  "alert": "RequestVPNPermission",
  "message": "..."
}
```

我们可以沿用这种模式，但 channel 名要换成自己的包名，例如：

```text
com.wepbox.app/method
com.wepbox.app/service.status
com.wepbox.app/service.alerts
```

## 6. Profile / 订阅链路

关键文件：

- `lib/features/profile/data/profile_repository.dart`
- `lib/features/profile/data/profile_parser.dart`
- `lib/features/profile/data/profile_path_resolver.dart`
- `lib/features/profile/data/profile_data_source.dart`
- `lib/features/profile/model/profile_entity.dart`

`ProfileRepository` 接口：

```dart
abstract interface class ProfileRepository {
  TaskEither<ProfileFailure, Unit> init();
  TaskEither<ProfileFailure, ProfileEntity?> getById(String id);
  TaskEither<ProfileFailure, Unit> setAsActive(String id);
  TaskEither<ProfileFailure, Unit> deleteById(String id, bool isActive);
  Stream<Either<ProfileFailure, ProfileEntity?>> watchActiveProfile();
  Stream<Either<ProfileFailure, bool>> watchHasAnyProfile();
  Stream<Either<ProfileFailure, List<ProfileEntity>>> watchAll();
  TaskEither<ProfileFailure, Unit> upsertRemote(String url);
  TaskEither<ProfileFailure, Unit> addLocal(String content);
  TaskEither<ProfileFailure, Unit> offlineUpdate(ProfileEntity profile, String content);
  TaskEither<ProfileFailure, Unit> validateConfig(String path, String tempPath, String? override, bool debug);
  TaskEither<ProfileFailure, String> generateConfig(String id);
  TaskEither<ProfileFailure, String> getRawConfig(String id);
}
```

### 6.1 添加远程订阅

```text
upsertRemote(url)
  -> getByUrl(url)
  -> 如果存在：updateRemote
  -> 如果不存在：addRemote
  -> 下载到 tempFile
  -> populateHeaders
  -> parse
  -> validateConfig(finalPath, tempPath)
  -> 写入 Drift 数据库
  -> 删除 tempFile
```

关键设计：

- 临时文件先落盘。
- validate 成功后才写入正式 profile。
- 更新失败不会破坏旧配置。
- headers 会从远程响应和配置内容两边提取。

### 6.2 添加本地配置

```text
addLocal(content)
  -> 生成 uuid
  -> 写 tempFile
  -> parser.addLocal
  -> validateConfig
  -> insert profile
  -> 删除 tempFile
```

### 6.3 配置校验

```text
validateConfig(path, tempPath, profileOverride, debug)
  -> configOptionRepository.fullOptionsOverrided(profileOverride)
  -> singbox.changeOptions(overridedOptions)
  -> singbox.validateConfigByPath(path, tempPath, debug)
```

这非常关键：profile 不是简单保存 JSON，而是通过 core 解析/校验后才成为可用配置。

我们应保留这种模式。

## 7. Proxy / 节点组链路

关键文件：

- `lib/features/proxy/data/proxy_repository.dart`
- `lib/hiddifycore/hiddify_core_service.dart`
- `lib/hiddifycore/generated/v2/hcore/hcore.pb.dart`

`ProxyRepository` 接口：

```dart
abstract interface class ProxyRepository {
  Stream<Either<ProxyFailure, OutboundGroup?>> watchProxies();
  Stream<Either<ProxyFailure, List<OutboundGroup>>> watchActiveProxies();
  TaskEither<ProxyFailure, IpInfo> getCurrentIpInfo(CancelToken cancelToken);
  TaskEither<ProxyFailure, Unit> selectProxy(String groupTag, String outboundTag);
  TaskEither<ProxyFailure, Unit> urlTest(String groupTag);
}
```

Hiddify 当前主要通过 gRPC 获取节点组：

```text
watchGroup()
  -> core.bgClient.outboundsInfo(Empty())

watchActiveGroups()
  -> core.bgClient.mainOutboundsInfo(Empty())

selectOutbound(groupTag, outboundTag)
  -> core.bgClient.selectOutbound(...)

urlTest(groupTag)
  -> core.bgClient.urlTest(...)
```

Android 里旧的 `GroupsChannel.kt` 和 `StatsChannel.kt` 已经注释，不是当前主链路。

我们实现节点页时应优先走 core API，而不是 Android EventChannel。

## 8. Stats / 流量状态链路

关键文件：

- `lib/features/stats/data/stats_repository.dart`
- `lib/hiddifycore/hiddify_core_service.dart`

`StatsRepository` 很薄：

```dart
abstract interface class StatsRepository {
  Stream<Either<StatsFailure, SystemInfo>> watchStats();
}
```

实际数据来自：

```text
HiddifyCoreService.watchStats()
  -> core.bgClient.getSystemInfoStream(Empty())
```

首页上下行速度、总流量、连接数等数据应从该 stream 映射，而不是自己轮询 Android service。

## 9. Log 链路

`HiddifyCoreService.watchLogs()` 会同时监听 fg/bg client：

```text
startListeningLogs("bg", core.bgClient)
startListeningLogs("fg", core.fgClient)
yield logController.stream
```

Android 侧还有 `LogHandler`，但 core 日志流主要在 Dart service 内聚合。

我们的 MVP 可以先只保留错误提示，日志页放到 M5。

## 10. Android Service 层

`BoxService` 是核心 service 包装。

职责：

- 前台通知。
- 状态 LiveData。
- 关闭广播。
- TUN file descriptor。
- DefaultNetworkMonitor。
- 调用 `Mobile.setup(...)`。
- 设置内存限制。
- 触发 service alert。

`MainActivity.startService()` 负责权限和服务启动，`BoxService` 负责真正 service 生命周期。

这条边界建议保留：

```text
Activity
  处理权限、启动入口

Service
  处理前台服务、core、通知、VPN fd、网络监听
```

## 11. 我们项目的取舍

应参考：

- Riverpod feature 分层。
- `ConnectionRepository` 边界。
- `ProfileRepository` 的 tempFile -> validate -> persist 流程。
- `HiddifyCoreService` 的统一 core facade。
- Android `MethodHandler/EventHandler/MainActivity/BoxService/VPNService` 的职责划分。
- gRPC stream 驱动 stats/proxy/log 的方式。

应简化：

- 多平台桌面能力。
- Sentry 和 analytics。
- 系统托盘、窗口控制。
- WARP、高级 TLS tricks。
- 多语言规模。
- 复杂 adaptive layout。
- 过重首页 UI。

应重写：

- UI 风格。
- 包名、品牌、图标。
- channel 名称。
- 主题系统。
- 首页/节点/订阅/设置页面组织。

## 12. 初步迁移策略

### 阶段 A：读懂和隔离 core 启停

目标文件：

- `HiddifyCoreService`
- `CoreInterfaceMobile`
- `MethodHandler`
- `EventHandler`
- `MainActivity`
- `BoxService`
- `VPNService`

产出：

- 我们自己的 `SingboxCoreService` 接口。
- Android channel 名称清单。
- 最小 start/stop/status demo。

### 阶段 B：迁移 profile 基础能力

目标文件：

- `ProfileRepository`
- `ProfileParser`
- `ProfilePathResolver`
- `ProfileEntity`
- Drift DB 相关表。

产出：

- 本地 JSON 导入。
- 远程 URL 导入。
- validate 后落盘。
- active profile。

### 阶段 C：迁移 proxy/stats

目标文件：

- `ProxyRepository`
- `StatsRepository`
- `singbox/model/*`
- gRPC generated model。

产出：

- 首页实时速度。
- 节点列表。
- 节点切换。
- 延迟测试。

## 13. 风险

- Hiddify 是 GPL-3.0，复用代码必须遵守许可证。
- `hiddify-core` 和生成的 gRPC/FFI 代码耦合较深。
- Android service 使用固定本地端口，迁移时要确认冲突和安全边界。
- `ProfileParser` 支持格式多，抽取时容易带入大量依赖。
- `ConfigOptionRepository` 与 profile override、Warp 等高级设置耦合，MVP 需要裁剪。
- 如果直接迁移 Android 包，品牌、包名、资源、通知、权限都要彻底替换。

## 14. 下一步建议

1. 先做一个最小 Flutter 工程壳，使用我们的 UI 风格。
2. 抽象 `SingboxCoreService`，接口对齐 Hiddify，但先不迁移全部实现。
3. 从 Hiddify 迁移/改写 Android `MethodHandler + EventHandler + BoxService + VPNService` 的最小集。
4. 打通 `setup -> start -> status -> stop`。
5. 再接 `ProfileRepository` 的本地导入和校验。
6. 最后接 stats/proxy。
