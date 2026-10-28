[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ProxyBridgeDirectory,
 [Parameter(Mandatory=$true)][string]$ProfilePath,
 [ValidateRange(1,65535)][int]$ProxyPort=18081,
 [string]$LogDirectory=(Join-Path $env:LOCALAPPDATA 'ProxyBridgeLauncher'),
 [switch]$ValidateOnly
)
$ErrorActionPreference='Stop'
$exe=Join-Path ([IO.Path]::GetFullPath($ProxyBridgeDirectory)) 'ProxyBridge_CLI.exe'
$profile=[IO.Path]::GetFullPath($ProfilePath)
if(!(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'ProxyBridge_CLI.exe not found'}
if(!(Test-Path -LiteralPath $profile -PathType Leaf)){throw 'Profile not found'}
$config=Get-Content -LiteralPath $profile -Raw -Encoding UTF8|ConvertFrom-Json
if(!@($config.ProxyConfigs).Count -or !@($config.ProxyRules).Count){throw 'Profile needs proxy configurations and routing rules'}
if($ValidateOnly){'VALIDATION=PASS; ENGINE_NOT_STARTED';return}
New-Item -ItemType Directory -Path $LogDirectory -Force|Out-Null
function Status([string]$text){"$(Get-Date -Format o) $text"|Add-Content -LiteralPath (Join-Path $LogDirectory 'startup.log') -Encoding UTF8}
try {
 if(Get-Process -Name ProxyBridge,ProxyBridge_CLI -ErrorAction SilentlyContinue){Status 'ALREADY_RUNNING; NO_DUPLICATE_STARTED';exit 0}
 $ready=$false
 for($i=0;$i -lt 24;$i++){
  if(Get-NetTCPConnection -LocalPort $ProxyPort -State Listen -ErrorAction SilentlyContinue){$ready=$true;break}
  Start-Sleep -Seconds 5
 }
 if(!$ready){Status 'UPSTREAM_NOT_READY';exit 1}
 Status 'STARTING_PROFILE'
 Set-Location -LiteralPath $ProxyBridgeDirectory
 & $exe --profile $profile --verbose 3 *> (Join-Path $LogDirectory 'engine.log')
 $code=$LASTEXITCODE
 Status "ENGINE_EXIT=$code"
 if($code -ne 0){exit 1}
}catch{Status "ERROR=$($_.Exception.Message)";exit 1}
