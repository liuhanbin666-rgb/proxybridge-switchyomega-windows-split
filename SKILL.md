---
name: proxybridge-switchyomega-windows-split
description: 在 Windows 上用 ProxyBridge 和 SwitchyOmega 3（ZeroOmega）给指定程序与浏览器域名分流。用户想通过已有的本地 SOCKS5/HTTP 代理，同时保持本地和局域网直连时使用此技能。
version: 1.0.0
author: liuhanbin666-rgb
---

# ProxyBridge + SwitchyOmega Windows 流量分流

## 用途说明

引导 Windows 用户运行仓库自带的双脚本向导，生成 ProxyBridge 的 `SplitProxy.pbprofile` 和 SwitchyOmega 3（ZeroOmega）的 `OmegaOptions-SplitProxy.bak`，再由用户在两个应用中导入。用户须已有正在运行的 `127.0.0.1` SOCKS5/HTTP 上游代理。详细安装说明见 [README.md](README.md)。

## 使用的工具清单

| 工具 | 是什么 | 作用 | 获取方式 |
| --- | --- | --- | --- |
| ProxyBridge | Windows 进程级流量分流工具 | 劫持指定 exe 的流量并按规则转发到本地代理或直连 | 向导从[官方 GitHub Releases](https://github.com/InterceptSuite/ProxyBridge/releases)下载安装包并校验；已核对的文件名为 `ProxyBridge-Setup-4.2.0.exe`，由用户右键以管理员身份运行。 |
| `scripts/Start_SplitProxy.bat` + `scripts/SplitProxy.ps1` | 本技能自带的一键向导 | 下载并校验安装包 SHA256、扫描 `127.0.0.1` 端口、测试代理、生成两份配置 | 随仓库提供，保持两文件同目录。 |
| SwitchyOmega 3（ZeroOmega） | Edge/Chrome 浏览器域名分流扩展 | 导入备份后用 `Split-Auto` 按站点分流 | 向导打开官方扩展商店，由用户免费安装。 |
| WinDivert 驱动 | ProxyBridge 底层网络驱动 | 支持进程流量捕获 | 新版 ProxyBridge 安装包自动安装，无需单独操作。 |
| 上游代理（SOCKS5/HTTP） | 用户已有的本地代理服务 | 接收本方案转发的流量 | 用户自行准备并启动 `127.0.0.1` 端口。 |
| PowerShell、`netstat` | Windows 自带工具 | 执行向导、查看监听端口 | 无需安装。 |

## 分步执行流程

1. 确认用户使用 Windows，已有可用的本地 SOCKS5/HTTP 代理，并确认两个 `scripts/` 文件在同一目录。
2. 请用户双击 BAT 并按提示操作。向导从官方发布页获取 Windows 安装包，检查大小、SHA256 与 EXE 文件头；校验失败即停止。
3. 请用户右键以管理员身份运行桌面安装包。继续向导，选择 Edge 或 Chrome；请用户在官方商店页面手动安装 SwitchyOmega 3（ZeroOmega）。
4. 填写已有上游代理的类型、端口和可选认证。向导测试本地连接及经代理连接 `example.com:443`；失败时先排查。
5. 在 ProxyBridge 的 **Profile > Import Profile** 导入桌面的 `SplitProxy.pbprofile`，核对规则顺序、代理类型、`127.0.0.1` 和端口，然后启用捕获。
6. 先备份扩展原配置，再在扩展的**选项 > 导入/导出 > 从备份恢复**导入桌面的 `OmegaOptions-SplitProxy.bak`，选择 `Split-Auto`。
7. 实际验证本地服务、局域网和目标网站。预设中浏览器进程在 ProxyBridge 里直连，浏览器域名分流由扩展处理；导入成功不代表真实代理已验证。

## 硬性约束

- 保持两个脚本原始内容及同目录关系；整理文档时不得重写脚本逻辑。
- 不修改 Windows 系统代理，不代替用户安装扩展，不声称本技能提供上游代理。
- 只使用 ProxyBridge + SwitchyOmega 3（ZeroOmega）方案。
- SOCKS5 用户名密码组合会被向导拒绝；改用无认证 SOCKS5 或 HTTP 端口。
- 恢复扩展备份会替换现有配置，恢复前提醒用户自行备份。
- 生成的配置若含账号密码即为明文；不得分享、上传、提交 Git 或写入公开日志。
- 安装包校验、代理握手或 CONNECT 失败时停止并排查，不绕过检查。

## 自检清单

- [ ] 官方 Windows 安装包的大小、SHA256 和 EXE 文件头校验通过。
- [ ] 上游代理仍在 `127.0.0.1` 监听，两份配置的类型与端口一致。
- [ ] ProxyBridge 已导入 `.pbprofile`，规则顺序正确，已启用捕获。
- [ ] `chrome.exe` / `msedge.exe` 在 ProxyBridge 中为直连。
- [ ] SwitchyOmega 已导入 `.bak` 并选中 `Split-Auto`。
- [ ] 本地、回环、局域网直连；目标域名按配置走代理；其他站点按配置默认直连。
- [ ] 若用户依赖本地开发或真机调试，已在其环境中实际检查。

## 故障排查

| 现象 | 检查与处理 |
| --- | --- |
| BAT 找不到 PowerShell 脚本 | 确认两个脚本在同一目录。 |
| 下载或校验失败 | 不运行安装包；删除损坏的桌面文件后重新运行向导，检查官方发布页是否可访问。 |
| 端口列表为空或连接失败 | 启动已有上游代理，确认监听 `127.0.0.1`，核对协议、端口和认证。 |
| 浏览器分流未生效 | 确认扩展选中 `Split-Auto`，没有其他扩展争用代理设置，浏览器进程在 ProxyBridge 中直连。 |
| 本地服务或局域网异常 | 先停止 ProxyBridge 捕获确认影响，再核对两端直连规则及顺序。 |
| 认证失败 | 检查账号密码；SOCKS5 认证不能用于本方案中的 Edge/Chrome，改用无认证 SOCKS5 或 HTTP。 |
