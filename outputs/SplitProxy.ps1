#requires -Version 5.1
param([switch]$SyntaxOnly)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Say([string]$Message) { Write-Host $Message }
function Fail([string]$Message) { throw $Message }
function Read-Choice([string]$Prompt, [string[]]$Allowed) {
    do { $answer = (Read-Host $Prompt).Trim().ToLowerInvariant() } until ($Allowed -contains $answer)
    return $answer
}
function Read-Exact([IO.Stream]$Stream, [int]$Count) {
    $buffer = New-Object byte[] $Count
    $offset = 0
    while ($offset -lt $Count) {
        $n = $Stream.Read($buffer, $offset, $Count - $offset)
        if ($n -le 0) { Fail '代理提前断开连接。' }
        $offset += $n
    }
    return ,$buffer
}
function Test-Proxy([string]$Kind, [int]$Port, [string]$User, [string]$Password) {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync('127.0.0.1', $Port)
        if (-not $task.Wait(5000)) { Fail '连接本地代理端口超时。' }
        $stream = $client.GetStream()
        $stream.ReadTimeout = 7000
        $stream.WriteTimeout = 7000
        if ($Kind -eq 'socks5') {
            $methods = if ($User) { [byte[]](5,2,0,2) } else { [byte[]](5,1,0) }
            $stream.Write($methods,0,$methods.Length)
            $reply = Read-Exact $stream 2
            if ($reply[0] -ne 5 -or $reply[1] -eq 255) { Fail 'SOCKS5 握手失败。' }
            if ($reply[1] -eq 2) {
                if (-not $User) { Fail '代理要求用户名密码。' }
                $u = [Text.Encoding]::UTF8.GetBytes($User); $p = [Text.Encoding]::UTF8.GetBytes($Password)
                if ($u.Length -gt 255 -or $p.Length -gt 255) { Fail 'SOCKS5 账号或密码超过 255 字节。' }
                $auth = [byte[]](1,$u.Length) + $u + [byte[]]@($p.Length) + $p
                $stream.Write($auth,0,$auth.Length)
                $ar = Read-Exact $stream 2
                if ($ar[1] -ne 0) { Fail 'SOCKS5 账号密码验证失败。' }
            } elseif ($reply[1] -ne 0) { Fail 'SOCKS5 认证方式不受支持。' }
            $hostBytes = [Text.Encoding]::ASCII.GetBytes('example.com')
            $request = [byte[]](5,1,0,3,$hostBytes.Length) + $hostBytes + [byte[]](1,187)
            $stream.Write($request,0,$request.Length)
            $result = Read-Exact $stream 4
            if ($result[1] -ne 0) { Fail "SOCKS5 无法连接测试站点，错误码 $($result[1])。" }
            $extra = switch ($result[3]) { 1 {4} 4 {16} 3 {(Read-Exact $stream 1)[0]} default {Fail 'SOCKS5 响应地址类型无效。'} }
            $null = Read-Exact $stream ($extra + 2)
        } else {
            $auth = if ($User) { 'Proxy-Authorization: Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${User}:$Password")) + "`r`n" } else { '' }
            $request = "CONNECT example.com:443 HTTP/1.1`r`nHost: example.com:443`r`n${auth}Proxy-Connection: close`r`n`r`n"
            $bytes = [Text.Encoding]::ASCII.GetBytes($request)
            $stream.Write($bytes,0,$bytes.Length)
            $line = [Text.StringBuilder]::new()
            while ($line.Length -lt 256) {
                $b = $stream.ReadByte(); if ($b -lt 0) { Fail 'HTTP 代理未返回响应。' }
                if ($b -eq 10) { break }; if ($b -ne 13) { [void]$line.Append([char]$b) }
            }
            if ($line.ToString() -notmatch '^HTTP/\d(?:\.\d)? 200(?:\s|$)') { Fail "HTTP CONNECT 失败：$line" }
        }
    } finally { $client.Dispose() }
}
function Add-Rule([Collections.Generic.List[object]]$Rules, [string]$Process, [string]$Hosts, [string]$Action) {
    $Rules.Add([ordered]@{ Name="$Process $Hosts $Action"; ProcessName=$Process; TargetHosts=$Hosts; TargetDomains='*'; TargetPorts='*'; Protocol='BOTH'; Action=$Action; IsEnabled=$true; LocalhostViaProxy=$false; ProxyConfigId=1 })
}

if ($SyntaxOnly) { return }
try {
    $desktop = [Environment]::GetFolderPath('Desktop')
    Say '第 1 步：下载 ProxyBridge 最新 Windows x64 发布包。'
    $releases = Invoke-RestMethod 'https://api.github.com/repos/InterceptSuite/ProxyBridge/releases?per_page=30' -Headers @{'User-Agent'='SplitProxy-Windows'}
    $windows = $releases | Where-Object { -not $_.draft -and ($_.assets | Where-Object name -match '^ProxyBridge-Setup-[\d.]+\.exe$') } | Sort-Object published_at -Descending | Select-Object -First 1
    if (-not $windows) { Fail '没有找到官方 Windows x64 安装包。' }
    $asset = $windows.assets | Where-Object name -match '^ProxyBridge-Setup-[\d.]+\.exe$' | Select-Object -First 1
    $download = Join-Path $desktop $asset.name
    if (-not (Test-Path -LiteralPath $download)) {
        Say "下载到桌面：$download"
        Invoke-WebRequest $asset.browser_download_url -OutFile $download -UseBasicParsing
    }
    if ((Get-Item -LiteralPath $download).Length -ne $asset.size) { Fail '安装包大小不符，请删除损坏文件后重试。' }
    $expected = ([string]$asset.digest) -replace '^sha256:',''
    if ($expected -notmatch '^[a-fA-F0-9]{64}$') { Fail '发布信息缺少有效 SHA256，停止。' }
    $actual = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash
    if ($actual -ne $expected) { Fail '安装包 SHA256 不符，请删除损坏文件后重试。' }
    $file = [IO.File]::OpenRead($download); try { if ($file.ReadByte() -ne 77 -or $file.ReadByte() -ne 90) { Fail '文件不是 Windows EXE。' } } finally { $file.Dispose() }
    Say "校验通过：$($windows.tag_name)，SHA256 $actual"
    Say '当前官方 Windows 发布物是 EXE 安装程序，不是 ZIP；不要尝试解压 EXE。'
    Say '127.0.0.1 LISTENING 端口候选：'
    Say '命令：netstat -ano -p tcp ^| findstr /R /C:"127\.0\.0\.1:[0-9]* .*LISTENING"'
    $lines = netstat -ano -p tcp | Select-String '^\s*TCP\s+127\.0\.0\.1:\d+\s+\S+\s+LISTENING\s+\d+' | ForEach-Object { $_.Line.Trim() }
    if ($lines) { $lines | ForEach-Object { Say $_ } } else { Say '没有发现本地监听端口。请先启动你已有的本地代理服务。' }
    $null = Read-Host '请查看端口列表；按回车继续'

    Say '第 2 步：右键以管理员身份运行桌面安装包。如安装程序允许选择目录，建议 C:\ProxyBridge（无中文、无空格）。'
    Say '当前新版是安装程序，不用解压，自带驱动并在安装时创建服务。如你使用旧版解压包，先解压到无中文无空格路径；里面确有 install_driver.bat 且驱动提示缺失时，才右键管理员手动运行它。'
    $null = Read-Host '完成安装或阅读说明后按回车继续'

    Say '第 3 步：选择要使用的浏览器：1=Edge，2=Chrome。扩展只能由你在商店手动添加。'
    $browser = Read-Choice '输入 1 或 2' @('1','2')
    if ($browser -eq '1') {
        $browserExe = 'msedge.exe'; $store = 'https://microsoftedge.microsoft.com/addons/detail/zeroomegaproxy-switchy-/dmaldhchmoafliphkijbfhaomcgglmgd'
    } else {
        $browserExe = 'chrome.exe'; $store = 'https://chromewebstore.google.com/detail/pfnededegaaopdmhkdmcofjmoldfiped'
    }
    $cmd = Get-Command $browserExe -ErrorAction SilentlyContinue
    if ($cmd) { Start-Process -FilePath $cmd.Source -ArgumentList $store } else { Start-Process $store }
    Say "商店页面：$store"
    $null = Read-Host '请在商店手动添加 Proxy SwitchyOmega 3 (ZeroOmega)，完成后按回车'

    Say '第 4 步：选择本地代理协议和刚才扫描到的端口。代理地址固定为 127.0.0.1。'
    $kindInput = Read-Choice '1=SOCKS5，2=HTTP' @('1','2')
    $kind = if ($kindInput -eq '1') {'socks5'} else {'http'}
    do { $portText = Read-Host '代理端口（1-65535）'; $port = 0; $valid = [int]::TryParse($portText,[ref]$port) -and $port -ge 1 -and $port -le 65535 } until ($valid)
    $user = Read-Host '代理用户名（无则直接回车）'
    $password = ''
    if ($user) {
        $secure = Read-Host '代理密码（输入不显示）' -AsSecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
    if ($kind -eq 'socks5' -and $user) { Fail 'Edge/Chrome 不支持 SOCKS5 用户名密码认证，无法让两端共用同一代理。请选择无认证 SOCKS5 或 HTTP 端口。' }
    Say '正在测试本地代理握手和经代理 CONNECT example.com:443……'
    Test-Proxy $kind $port $user $password
    Say '连通性测试通过。'

    Say '第 5 步：生成 ProxyBridge 可导入 .pbprofile（JSON）。'
    $rules = [Collections.Generic.List[object]]::new()
    foreach ($host in @('localhost','127.0.0.0/8','::1','192.168.0.0/16','10.0.0.0/8','172.16.0.0/12','169.254.0.0/16','fe80::/10')) { Add-Rule $rules '*' $host 'DIRECT' }
    foreach ($process in @('proxybridge.exe','wechatdevtools.exe','hbuilderx.exe','chrome.exe','msedge.exe')) { Add-Rule $rules $process '*' 'DIRECT' }
    foreach ($process in @('cursor.exe','code.exe','git.exe','node.exe','python.exe')) { Add-Rule $rules $process '*' 'PROXY' }
    Add-Rule $rules '*' '*' 'DIRECT'
    $profile = [ordered]@{ Version='1.0'; Name='SplitProxy'; IsTrafficLoggingEnabled=$true; NextProxyConfigId=2; ProxyConfigs=@([ordered]@{Id=1;Name='Local Proxy';Type=$kind.ToUpperInvariant();Host='127.0.0.1';Port=[string]$port;Username=$user;Password=$password;SendDomainToProxy=$true}); ProxyRules=@($rules.ToArray()) }
    $profilePath = Join-Path $desktop 'SplitProxy.pbprofile'
    [IO.File]::WriteAllText($profilePath, ($profile | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    Say "已生成：$profilePath"
    Say '在 ProxyBridge 中打开 Profile > Import Profile，选择该文件；核对规则顺序与代理参数，然后开启 Enable ProxyBridge。'
    Say '该文件若含账号密码就是明文，仅保存在本机；不要分享或上传。'

    Say '第 6 步：生成 SwitchyOmega 备份，导入后选择 Split-Auto。'
    $proxy = [ordered]@{name='Split-Proxy';profileType='FixedProfile';color='#44aacc';revision='1';fallbackProxy=[ordered]@{scheme=$kind;host='127.0.0.1';port=$port};bypassList=@()}
    if ($user) { $proxy.auth = [ordered]@{username=$user;password=$password} }
    $domains = @('github.com','githubusercontent.com','githubassets.com','github.io','api.github.com','openai.com','chatgpt.com','oaistatic.com','oaiusercontent.com','anthropic.com','claude.ai','googleapis.com','gemini.google.com','aistudio.google.com','perplexity.ai')
    $switchRules = [Collections.Generic.List[object]]::new()
    foreach ($pattern in @('localhost','*.localhost','127.*','192.168.*','10.*','172.16.*','172.17.*','172.18.*','172.19.*','172.2?.*','172.30.*','172.31.*','169.254.*','[::1]')) {
        $switchRules.Add([ordered]@{condition=[ordered]@{conditionType='HostWildcardCondition';pattern=$pattern};profileName='direct'})
    }
    foreach ($domain in $domains) {
        foreach ($pattern in @($domain,"*.$domain")) { $switchRules.Add([ordered]@{condition=[ordered]@{conditionType='HostWildcardCondition';pattern=$pattern};profileName='Split-Proxy'}) }
    }
    $backup = [ordered]@{schemaVersion=2;'+Split-Proxy'=$proxy;'+Split-Auto'=[ordered]@{name='Split-Auto';profileType='SwitchProfile';color='#99dd99';revision='1';defaultProfileName='direct';rules=@($switchRules.ToArray())};'-startupProfileName'='Split-Auto';'-enableQuickSwitch'=$false;'-showExternalProfile'=$false}
    $backupPath = Join-Path $desktop 'OmegaOptions-SplitProxy.bak'
    [IO.File]::WriteAllText($backupPath, ($backup | ConvertTo-Json -Depth 15), [Text.UTF8Encoding]::new($false))
    Say "已生成：$backupPath"
    Say '扩展选项 > 导入/导出 > 从备份恢复，选择该 .bak；再点扩展图标选 Split-Auto。恢复备份会替换扩展现有配置，先自行备份。'
    Say 'Edge/Chrome 都不加入 ProxyBridge 的 PROXY 规则；浏览器站点分流只由扩展完成。'
    Say '第 7 步：本地、回环与局域网直连规则已排在最前，浏览器备份也有相应直连规则。'
    Say '第 8 步：逐项自检：'
    @('安装包 SHA256 与官方发布信息一致','ProxyBridge 代理地址/类型/端口均为 127.0.0.1 / '+$kind+' / '+$port,'ProxyBridge 已导入规则并开启捕获','chrome.exe / msedge.exe 命中 DIRECT','国内站点默认 DIRECT，GitHub 和海外 AI 域名命中 Split-Proxy','localhost / 127.0.0.1 / 192.168.* 命中 DIRECT','uni-app、微信开发者工具云开发、真机调试正常') | ForEach-Object { Say "[ ] $_" }
    Say '故障排查：先检查代理端口仍在 LISTENING；再检查 ProxyBridge 的连接日志和规则顺序；浏览器检查扩展已选 Split-Auto、无其他扩展抢占代理设置；代理认证失败时核对账号密码；本地开发异常时先停用捕获并检查局域网直连规则。'
    exit 0
} catch {
    Write-Host "已停止：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
