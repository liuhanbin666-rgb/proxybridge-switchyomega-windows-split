# WinDivert 1450 排查、进程分流验收与登录自启动

更新日期：2026-10-28。本文来自一次实际排查，已移除个人路径、原始日志、目标 IP、凭据和安全软件数据库。

## 1. 先区分四个状态

1. 上游代理端口监听：仅表示本地代理正在接收连接。
2. ProxyBridge 程序/服务运行：不等于驱动成功加载。
3. WinDivert 能打开：表示驱动可用，不等于规则符合预期。
4. 真实新连接命中 PROXY/DIRECT：才是分流验收证据。

Codex 能联网，也可能只是继承了系统代理或 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`。因此不能用“能聊天”单独证明 ProxyBridge 接管成功。DIRECT 规则也不会撤销应用自己主动使用的代理配置。

## 2. 本次故障的证据链

| 阶段 | 发现与结果 |
|---|---|
| 初始现象 | WinDivert 加载失败，Windows 错误 1450；ProxyBridge 窗口和服务仍可能存在 |
| 历史对照 | 安装当天就有驱动失败事件，说明故障早于后续应用重装和规则修改；不能据此断言所有历史时段都未成功 |
| 完整性核验 | 安装包与官方发布摘要一致；已装 DLL/SYS 与原安装包及官方 WinDivert 对应文件一致 |
| 可回退修复测试 | 重建驱动服务注册仍失败，原注册已恢复；重启电脑也未解决 |
| 关键证据 | 本机火绒日志中找到同一路径、同一 SHA256 的 `kmodblock` 和 `BYOVD_network_redirect` 记录 |
| 处理 | 用户在火绒官方支持的界面添加该单个驱动例外，其他防护保持开启 |
| 复测 | 相同最小驱动测试由 1450/退出 2 变为 OPEN=PASS/退出 0，驱动 Running |
| 实际验收 | 引擎加载三条规则；Codex 桌面端 TCP 连接记录为代理；普通程序的新连接记录为直连 |
| 系统代理 | 用户关闭 Windows 全局系统代理后，桌面端仍有真实代理记录；普通程序明确禁用应用代理的 HTTPS 请求返回 200，并有 Direct 记录 |

**1450 不是“火绒拦截”的通用同义词。** 只有拿到对应文件/哈希/时间的拦截证据，才能作出本案例的判断。未发现直接证据时继续检查服务、路径、驱动加载和系统事件；不要盲目关闭安全功能或反复重装其他应用。

## 3. 最小驱动测试

在管理员 PowerShell 中运行（路径替换为自己的目录）：

```powershell
.\scripts\Test-WinDivert.ps1 -ProxyBridgeDirectory 'D:\Tools\ProxyBridge'
```

脚本调用 `WinDivertOpen('false', 0, 0, 5)`，使用 SNIFF | RECV_ONLY。`false` 不匹配任何流量，不读取、保存或改写数据包。

```text
# 本案例处理前：退出 2
OPEN=FAILED; WIN32_ERROR=1450; FILTER=false; FLAGS=5
# 处理后：退出 0
OPEN=PASS; CLOSE=True; FILTER=false; FLAGS=5
```

`-ValidateOnly` 仅验证 DLL 路径及测试参数，不加载驱动，不能用其成功结果代替真实加载测试。

## 4. 火绒例外的处理边界

火绒支持的入口是：**系统防护 → 漏洞驱动拦截 → 例外驱动**。仅在核验来源、文件完整性和拦截原因后，由用户决定是否加入具体的 `WinDivert64.sys`。

- 这不是 Windows 防火墙端口放行，也不是普通文件信任区。
- 不需要关闭整个防火墙、退出安全软件、放行整个磁盘或关闭 Windows 安全功能。
- 例外会允许内核驱动加载；合法来源和有效签名不等于没有风险。
- 不接受此例外时，保留防护，另选应用自身的代理配置；不要绕过防护。
- 回退时通过同一界面移除该单文件例外，不直接修改安全软件数据库。

来源：[火绒官方例外说明](https://www.huorong.cn/document/tech/safety-classroom/1950)、[WinDivert 官方发布](https://github.com/basil00/WinDivert/releases/tag/v2.2.2)、[ProxyBridge Windows 文档](https://github.com/InterceptSuite/ProxyBridge/blob/master/Windows/README.md)。

## 5. “仅 Codex 代理”的独立配置

原向导预设包含 cursor/code/git/node/python 等程序。本节是**另一种目标配置**，不要把两种方案混为一谈。

示意规则顺序：

| 顺序 | 进程 | 目标 | 协议 | 动作 |
|---|---|---|---|---|
| 1 | 任意 | 本机回环地址 | TCP/UDP | DIRECT |
| 2 | `codex.exe;ChatGPT.exe`（按实际安装核对） | 任意 | TCP | 指定本地上游代理 |
| 3 | 任意 | 任意 | TCP/UDP | DIRECT |

注意：进程名称会随应用版本变化；`ChatGPT.exe` 会匹配同名进程，不是任意开发子进程的自动继承规则。通用 `node.exe`/`python.exe` 代理规则会影响其他项目，不要为图方便加入“仅 Codex”配置。HTTP 上游不承载 UDP，DNS/QUIC 的处理需要单独核实。

验收顺序：驱动成功 → 引擎启动 → 真实日志 → 再由用户确认关闭全局系统代理 → 新连接复测。保留本地上游代理运行。检查其他应用是否主动配置代理或继承代理变量，避免系统代理关闭后仍出现额外转发。

## 6. 登录自启动

上游代理必须另行安装、登录并启动；本项目不管理其账号和订阅。选择固定、可信目录保存脚本和配置，避免由其他用户或不可信程序修改；计划任务将以当前用户最高权限运行。

先验证路径与配置（不注册任务）：

```powershell
.\scripts\Set-ProxyBridgeAutostart.ps1 `
  -ProxyBridgeDirectory 'D:\Tools\ProxyBridge' `
  -ProfilePath 'D:\ProxyProfiles\CodexOnly.pbprofile' -ValidateOnly
```

确认后在管理员 PowerShell 运行相同命令，去掉 `-ValidateOnly`：

```powershell
.\scripts\Set-ProxyBridgeAutostart.ps1 `
  -ProxyBridgeDirectory 'D:\Tools\ProxyBridge' `
  -ProfilePath 'D:\ProxyProfiles\CodexOnly.pbprofile'
```

行为：

- 当前用户**登录后**延迟 20 秒，不是在无人登录时建立交互用户会话。
- 使用账号 SID，避免含中文的电脑名称在 PowerShell 5.1 下编码错误。
- 使用交互登录令牌和最高权限，不存储密码。
- 等待本地上游端口最多 120 秒；失败由计划任务每分钟重试，最多 10 次。
- 允许电池供电、无运行时间上限，重复任务实例被忽略。
- 已有 ProxyBridge GUI/CLI 进程时正常退出，避免争抢引擎；**已有进程未必加载正确规则，仍须人工核对**。
- 日志仅留本机 `%LOCALAPPDATA%\ProxyBridgeLauncher`，其中目标地址可能属于隐私，不应上传。
- 原始分流规则、Windows 系统代理、防火墙、安全软件设置均不由辅助脚本修改。

自启动依赖脚本和配置保留在原路径；移动或删除这些文件会使任务失败。已存在同名任务时不覆盖，先检查再移除或选择其他任务名。

撤销自启动（管理员 PowerShell）：

```powershell
.\scripts\Set-ProxyBridgeAutostart.ps1 -Remove
```

此操作仅删除该自启动任务，不停止当前引擎、不删除驱动、不撤销安全软件例外。更换过任务名时需加同样的 `-TaskName`。

## 7. 验证范围与上传边界

本案例现场已验证：驱动加载、分流引擎、桌面端代理连接、普通程序 Direct 新连接、关闭全局代理后的检查、自启动任务即时派发/防重复分支、临时任务回退。未为验收再次重启电脑，也没有把桌面端连接样本当作所有后台/子进程的覆盖证明。

通用脚本另外通过仓库中的 `tests/Test-Helpers.ps1` 作 Windows PowerShell 5.1 语法和无副作用参数测试。它不注册任务、不加载驱动、不证明读者电脑的真实网络行为。

只提交通用源码、占位配置描述和脱敏结论。原始日志、安全软件数据库、含凭据 profile、截图、账号资料、真实网络目标和本机任务导出均留在本机，不进入公开仓库。
