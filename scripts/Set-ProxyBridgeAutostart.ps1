[CmdletBinding(SupportsShouldProcess=$true)]
param(
 [string]$ProxyBridgeDirectory,
 [string]$ProfilePath,
 [ValidateRange(1,65535)][int]$ProxyPort=18081,
 [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$TaskName='ProxyBridge-Profile-Autostart',
 [switch]$Remove,
 [switch]$ValidateOnly
)
$ErrorActionPreference='Stop'
$launcher=Join-Path $PSScriptRoot 'Start-ProxyBridgeProfile.ps1'
if(!$Remove){
 if(!$ProxyBridgeDirectory -or !$ProfilePath){throw 'ProxyBridgeDirectory and ProfilePath are required'}
 $directory=[IO.Path]::GetFullPath($ProxyBridgeDirectory)
 $profile=[IO.Path]::GetFullPath($ProfilePath)
 & $launcher -ProxyBridgeDirectory $directory -ProfilePath $profile -ProxyPort $ProxyPort -ValidateOnly|Out-Null
 foreach($value in @($directory,$profile,$launcher)){if($value.Contains('"')){throw 'Double quotes are not allowed in task paths'}}
}
if($ValidateOnly){"VALIDATION=PASS; TASK_NOT_CHANGED; MODE=$(if($Remove){'REMOVE'}else{'INSTALL'})";return}
if(!$PSCmdlet.ShouldProcess($TaskName,$(if($Remove){'Remove autostart task'}else{'Create autostart task'}))){return}
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
if(!([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run task installation/removal in an administrator PowerShell'}
if($Remove){
 if(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false}
 'AUTOSTART=REMOVED; RUNNING_ENGINE_NOT_STOPPED';return
}
if(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){throw 'Task already exists; remove or choose another task name first'}
$sid=$id.User.Value
$args='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -ProxyBridgeDirectory "{1}" -ProfilePath "{2}" -ProxyPort {3}' -f $launcher,$directory,$profile,$ProxyPort
$action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $args -WorkingDirectory $directory
$trigger=New-ScheduledTaskTrigger -AtLogOn -User $sid
$trigger.Delay='PT20S'
$principal=New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 10 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'User logon ProxyBridge profile launcher; no system proxy/firewall/security policy modifications'|Out-Null
'AUTOSTART=INSTALLED; LOGON_DELAY=20S; PASSWORD_NOT_STORED'
