[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ProxyBridgeDirectory,
 [switch]$ValidateOnly
)
$ErrorActionPreference='Stop'
$dll=Join-Path ([IO.Path]::GetFullPath($ProxyBridgeDirectory)) 'WinDivert.dll'
if(!(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'WinDivert.dll not found'}
if($ValidateOnly){'VALIDATION=PASS; FILTER=false; FLAGS=5; DRIVER_NOT_LOADED';return}
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
if(!([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run this driver probe in an administrator PowerShell'}
$literal=$dll.Replace('\','\\').Replace('"','\"')
$type='WinDivertProbe'+[guid]::NewGuid().ToString('N')
$source=@"
using System;
using System.Runtime.InteropServices;
public static class $type {
 [DllImport("$literal",CallingConvention=CallingConvention.Cdecl,SetLastError=true)]
 public static extern IntPtr WinDivertOpen([MarshalAs(UnmanagedType.LPStr)]string filter,int layer,short priority,ulong flags);
 [DllImport("$literal",CallingConvention=CallingConvention.Cdecl,SetLastError=true)]
 [return:MarshalAs(UnmanagedType.Bool)]public static extern bool WinDivertClose(IntPtr handle);
}
"@
$native=Add-Type -TypeDefinition $source -PassThru
# false matches no packets; SNIFF|RECV_ONLY does not modify traffic.
$handle=$native::WinDivertOpen('false',0,0,5)
$errorCode=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
if($handle -eq [IntPtr](-1)){"OPEN=FAILED; WIN32_ERROR=$errorCode; FILTER=false; FLAGS=5";exit 2}
$closed=$native::WinDivertClose($handle)
"OPEN=PASS; CLOSE=$closed; FILTER=false; FLAGS=5"
if(!$closed){exit 3}
