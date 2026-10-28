$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$scripts=Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter '*.ps1' -File
foreach($script in $scripts){
 $tokens=$null;$errors=$null
 [Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)|Out-Null
 if($errors.Count){throw "Syntax errors in $($script.Name): $($errors -join '; ')"}
}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('proxybridge-helper-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp|Out-Null
try {
 # Placeholder files are only inspected by ValidateOnly; never executed or loaded.
 Set-Content -LiteralPath (Join-Path $temp 'WinDivert.dll') -Value 'TEST_PLACEHOLDER'
 Set-Content -LiteralPath (Join-Path $temp 'ProxyBridge_CLI.exe') -Value 'TEST_PLACEHOLDER'
 $profile=Join-Path $temp 'fixture.json'
 '{"ProxyConfigs":[{"Id":1,"Type":"HTTP","Host":"127.0.0.1","Port":"18081"}],"ProxyRules":[{"ProcessName":"*","Action":"DIRECT"}]}'|Set-Content -LiteralPath $profile
 $a=& (Join-Path $root 'scripts\Test-WinDivert.ps1') -ProxyBridgeDirectory $temp -ValidateOnly
 if($a -ne 'VALIDATION=PASS; FILTER=false; FLAGS=5; DRIVER_NOT_LOADED'){throw 'Probe dry-run failed'}
 $b=& (Join-Path $root 'scripts\Start-ProxyBridgeProfile.ps1') -ProxyBridgeDirectory $temp -ProfilePath $profile -ValidateOnly
 if($b -ne 'VALIDATION=PASS; ENGINE_NOT_STARTED'){throw 'Launcher dry-run failed'}
 $c=& (Join-Path $root 'scripts\Set-ProxyBridgeAutostart.ps1') -ProxyBridgeDirectory $temp -ProfilePath $profile -ValidateOnly
 if($c -ne 'VALIDATION=PASS; TASK_NOT_CHANGED; MODE=INSTALL'){throw 'Installer dry-run failed'}
 $d=& (Join-Path $root 'scripts\Set-ProxyBridgeAutostart.ps1') -Remove -ValidateOnly
 if($d -ne 'VALIDATION=PASS; TASK_NOT_CHANGED; MODE=REMOVE'){throw 'Removal dry-run failed'}
 $rejected=$false
 try{ & (Join-Path $root 'scripts\Set-ProxyBridgeAutostart.ps1') -ValidateOnly|Out-Null }catch{$rejected=$true}
 if(!$rejected){throw 'Missing paths must be rejected'}
 "TESTS=PASS; POWERSHELL=$($PSVersionTable.PSVersion); PARSED=$($scripts.Count); DRY_RUNS=4; NEGATIVE=1; LIVE_SETTINGS_UNCHANGED"
}finally{
 $actual=[IO.Path]::GetFullPath($temp)
 $parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if(!$actual.StartsWith($parent,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($actual) -notlike 'proxybridge-helper-test-*'){throw 'Unexpected cleanup target'}
 Remove-Item -LiteralPath $actual -Recurse -Force
}
