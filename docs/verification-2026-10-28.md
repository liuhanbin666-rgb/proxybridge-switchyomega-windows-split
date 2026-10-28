# 2026-10-28 更新验证

## 代码验证

在 Windows PowerShell 5.1 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Helpers.ps1
```

字面输出：

```text
TESTS=PASS; POWERSHELL=5.1.22621.4391; PARSED=4; DRY_RUNS=4; NEGATIVE=1; LIVE_SETTINGS_UNCHANGED
```

退出状态：0。

- 语法检查包括原有向导和新增三个辅助脚本。
- 四个 ValidateOnly 用例覆盖驱动测试、引擎启动、任务安装和任务移除。
- 缺失必填路径的负向用例被正确拒绝。
- 测试仅使用临时占位文件；未加载驱动、运行占位程序、创建计划任务或修改任何网络/安全设置。
- `git diff --check` 通过。
- 原始 `scripts/SplitProxy.ps1`、`scripts/Start_SplitProxy.bat` 保持不变。

## 现场证据与范围

脱敏故障案例见 [驱动恢复与自启动指南](driver-recovery-and-autostart.md)。已完成的现场操作使用本地专用脚本；不能把该现场测试自动等同于所有通用脚本在任意机器上的全流程验收。

- 驱动：相同最小输入由 1450/退出 2 恢复为 OPEN=PASS/退出 0。
- 分流：捕获到 Codex 桌面端 TCP 代理连接和普通程序 Direct 新连接；没有宣称所有后台/子进程和 UDP 均覆盖。
- 自启动：本地专用任务即时派发返回 0，防重复分支通过；临时任务创建/移除回退测试通过。未为此再次重启机器。
- 未提交原始安全软件数据库、完整日志、实际 profile、任务导出、个人截图或凭据。

## 更新/回退

新增脚本为独立工具，原始双脚本向导未被替换。撤销计划任务使用 `Set-ProxyBridgeAutostart.ps1 -Remove`；脚本按需运行，不修改保护策略或全局系统代理。安全软件例外由用户在其支持的界面中处理。
