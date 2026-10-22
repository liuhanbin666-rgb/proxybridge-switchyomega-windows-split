# ProxyBridge + SwitchyOmega Windows 分流向导

桌面双击 `Start_SplitProxy.bat`，并保持 `SplitProxy.ps1` 与 BAT 在同一目录。脚本只做分流配置，不修改 Windows 系统代理。安装 ProxyBridge 和浏览器扩展需要用户手动完成。

## 使用步骤

1. BAT 调起 PowerShell，按 GitHub 发布信息选取最新 Windows 安装包，下载到桌面并核对文件大小、SHA256 和 EXE 文件头；打印 `127.0.0.1` 的 `LISTENING` TCP 端口并暂停。
2. 管理员运行 ProxyBridge 安装包。当前官方 Windows 版是安装程序，不是压缩包；安装器如允许选目录，建议 `C:\ProxyBridge`。旧版压缩包需解压到无中文无空格路径，且仅在驱动确实缺失时手动管理员运行包内 `install_driver.bat`。
3. 选择 Edge 或 Chrome，脚本打开相应官方扩展商店页面。用户手动安装 **Proxy SwitchyOmega 3 (ZeroOmega)**。
4. 选择本地 SOCKS5 或 HTTP 端口，输入可选认证信息。脚本连接本地代理并通过代理向 `example.com:443` 发起 CONNECT；失败立即停止。
5. 测试通过后在桌面生成 `SplitProxy.pbprofile` 与 `OmegaOptions-SplitProxy.bak`。分别在 ProxyBridge 的 **Profile > Import Profile** 和扩展的导入/导出页面导入，选择 `Split-Auto` 并核对后开启捕获。

## 规则

ProxyBridge 规则从上到下：回环和私有网络直连；ProxyBridge 自身、微信开发者工具、HBuilderX、Chrome、Edge 直连；Cursor、VS Code、Git、Node、Python 走选定代理；其他进程直连。浏览器由扩展按站点分流：GitHub 和列出的海外 AI 域名走代理，其他站点（包括国内站点）默认直连。本地和局域网规则置顶。

Chrome/Edge 不支持 SOCKS5 用户名密码认证。脚本遇到此组合时停止，请选择无认证 SOCKS5 或 HTTP 端口。HTTP 认证信息会保存在本机生成的配置文件中；这些文件包含明文凭据时不得分享、上传或提交 Git。

## 自检与故障排查

- 检查安装包校验通过、本地代理端口仍为 `LISTENING`。
- 核对 ProxyBridge 和扩展均为 `127.0.0.1`、相同类型和端口。
- 在 ProxyBridge 中确认已导入规则、规则顺序正确并启用捕获；Chrome/Edge 命中 `DIRECT`。
- 在扩展中确认启用 `Split-Auto`，没有其他扩展争用代理控制权。
- 访问 GitHub、国内站点、本地开发服务和 `192.168.*` 真机调试地址，核对分流结果。
- 如代理连接失败，检查端口、协议、认证与测试站点可达性。如开发服务异常，先停止 ProxyBridge 捕获，再检查局域网直连规则。

## 依据与版本差异

- [ProxyBridge Windows Profiles 文档](https://proxybridge.interceptsuite.com/docs/windows-profiles/)：`.pbprofile` JSON 格式及导入菜单。
- [ProxyBridge 官方 Windows Releases](https://github.com/InterceptSuite/ProxyBridge/releases)：脚本动态选择 Windows 安装包及发布资产摘要。2026-10-22 核对到最新 Windows 发布为 `v4.2.0_Windows`，资产 `ProxyBridge-Setup-4.2.0.exe`。
- [ZeroOmega 项目主页](https://github.com/zero-peak/ZeroOmega)：Edge 和 Chrome 官方商店链接。
- [SwitchyOmega 官方 FAQ](https://github.com/FelisCatus/SwitchyOmega/wiki/FAQ)：Chromium 的 SOCKS 认证限制。

## 本地验证

已用 Windows PowerShell 5.1 解析器检查脚本语法，并用本地模拟服务测试 HTTP CONNECT 与 SOCKS5 CONNECT 握手；核对 GitHub API 的 Windows 发布资产和 SHA256 字段。下载、安装、扩展导入和真实代理连通性需在用户双击 BAT 后按向导完成。
