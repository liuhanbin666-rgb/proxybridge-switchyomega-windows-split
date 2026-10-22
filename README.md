# ProxyBridge + SwitchyOmega Windows 流量分流

想让 Windows 上指定程序和浏览器里的指定网站使用你已有的本地代理，同时让本地开发、局域网和其他流量直连？本项目提供一键向导，生成 ProxyBridge 与 SwitchyOmega 3（ZeroOmega）各自可导入的配置。

使用前，你需要已有在本机 `127.0.0.1` 提供 SOCKS5 或 HTTP 端口的上游代理。本项目不提供上游代理服务，也不修改 Windows 系统代理。

## 使用的工具清单

| 工具 | 是什么 | 作用 | 小白怎么获得 |
| --- | --- | --- | --- |
| ProxyBridge | 进程级流量分流工具 | 劫持指定 `.exe` 进程的流量，按规则转发到本地代理或直连 | 向导从[官方 GitHub Releases](https://github.com/InterceptSuite/ProxyBridge/releases)下载 Windows 安装包。已核对版本的文件名为 `ProxyBridge-Setup-4.2.0.exe`；下载后右键**以管理员身份运行**。新版安装包自带 WinDivert 驱动。 |
| `Start_SplitProxy.bat` + `SplitProxy.ps1` | 本技能自带的一键向导，两个文件须在同一目录 | 自动下载并按官方 SHA256 校验 ProxyBridge 安装包、扫描 `127.0.0.1` 监听端口、测试代理连通、生成两份配置 | 下载本仓库 `scripts/` 目录中的两个文件，放在同一文件夹；也可下载仓库 ZIP 后进入 `scripts/`。 |
| SwitchyOmega 3（ZeroOmega） | 浏览器域名分流扩展 | 让 Edge/Chrome 按网站决定走本地代理或直连 | 按向导选择浏览器，它会打开对应官方扩展商店页面；在 Edge/Chrome 商店免费安装。 |
| WinDivert 驱动 | ProxyBridge 底层网络驱动 | 支持 ProxyBridge 捕获程序流量 | 新版 ProxyBridge 安装包自动安装，无需单独处理。 |
| 上游代理（SOCKS5/HTTP） | 用户自己已有的本地代理服务 | 接收需要转发的流量；本技能只负责把流量分给它 | 使用你已有服务提供的 `127.0.0.1` 端口；没有时先自行准备。 |
| PowerShell、`netstat` | Windows 自带命令行工具 | 运行向导、列出本地监听端口 | Windows 自带，无需安装。 |

## 使用步骤

1. 将 `scripts/Start_SplitProxy.bat` 和 `scripts/SplitProxy.ps1` 下载到同一文件夹，并启动你已有的本地代理服务。
2. 双击 BAT，按窗口提示操作。向导下载 ProxyBridge 安装包到桌面，检查大小、SHA256 和 EXE 文件头；校验失败时不要安装。
3. 在桌面找到安装包，右键选择**以管理员身份运行**，完成安装后回到向导继续。
4. 选择 Edge 或 Chrome，在向导打开的官方商店页面手动安装 SwitchyOmega 3（ZeroOmega）。选择本地 SOCKS5/HTTP 类型与端口。向导会测试本地连接及经代理连接 `example.com:443`；测试失败会停止。
5. 测试通过后，桌面会生成 `SplitProxy.pbprofile` 和 `OmegaOptions-SplitProxy.bak`。在 ProxyBridge 的 **Profile > Import Profile** 导入前者，检查规则和代理参数后启用 **Enable ProxyBridge**。
6. 在扩展的**选项 > 导入/导出 > 从备份恢复**中导入后者，再选择 `Split-Auto`。恢复备份会替换扩展现有配置；如有原配置，请先在扩展内自行备份。
7. 检查本地服务、局域网地址与目标网站的实际分流结果。预设规则让指定进程或域名使用代理，其他流量默认直连；具体规则以生成配置为准。

## 常见问题 Q&A

**Q：双击 BAT 提示缺少 `SplitProxy.ps1`？**

A：确认两个文件在同一文件夹，并双击该文件夹里的 BAT。

**Q：扫描不到端口，或代理测试失败？**

A：先启动已有的上游代理，确认它监听 `127.0.0.1`，再核对协议、端口和认证。向导还会通过代理测试 `example.com:443`，该连接不可达时也会停止。

**Q：为什么 SOCKS5 用户名密码不能用？**

A：本方案需要浏览器和 ProxyBridge 共用同一端口；Edge/Chrome 不支持此类 SOCKS5 认证。请选择无认证 SOCKS5 或 HTTP 端口。

**Q：浏览器没有按规则分流？**

A：确认扩展已导入备份并选中 `Split-Auto`，检查是否有其他扩展控制浏览器代理，并核对 ProxyBridge 中 `chrome.exe` / `msedge.exe` 为直连。

**Q：本地服务或局域网访问异常？**

A：先停止 ProxyBridge 捕获确认影响，再检查 ProxyBridge 规则顺序及扩展中的本地直连规则。

**Q：安装包校验失败？**

A：不要运行它。删除桌面上的损坏文件，重新执行向导下载校验。

## 安全提醒

生成的 `.pbprofile` 与 `.bak` 若含账号密码，内容是**明文**。不要分享、上传或提交 Git。仓库的 `.gitignore` 会排除这些文件名，在其他仓库中仍须自行检查。

## 项目文件

- [SKILL.md](SKILL.md)：AI 助手的执行说明和自检清单。
- [BAT](scripts/Start_SplitProxy.bat) 与 [PowerShell 脚本](scripts/SplitProxy.ps1)：原样保留的向导。

本项目按 [MIT License](LICENSE) 开源。

## 本次整理与验证

- **问题**：原仓库把已验证的向导放在 `outputs/`，缺少可供技能目录识别的根目录 `SKILL.md`，新手说明也未列齐所需工具。
- **处理**：把两个脚本逐字节复制到 `scripts/`，用 `.gitattributes` 保持脚本原始字节；新增技能说明、工具清单和许可证，并让 `.gitignore` 排除本地 `outputs/` 与 `work/`。
- **验证**：两个 `scripts/` 文件与对应 `outputs/` 源文件的 SHA256 各自一致；PowerShell 5.1 语法解析无错误；`git diff --check` 通过；提交清单仅含技能分发文件。未在本次文档整理中安装 ProxyBridge、导入扩展或测试真实上游代理；这些操作需按上面的步骤在使用者电脑上完成。
