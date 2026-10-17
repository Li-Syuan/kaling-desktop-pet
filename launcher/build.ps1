$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if(-not (Test-Path -LiteralPath $compiler)){$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'}
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll ('/out:'+(Join-Path $repo 'Start.exe')) (Join-Path $PSScriptRoot 'Launcher.cs')
if($LASTEXITCODE -ne 0){throw 'Launcher compilation failed'}
Get-Item -LiteralPath (Join-Path $repo 'Start.exe')|Select-Object Name,Length,@{n='Version';e={$_.VersionInfo.FileVersion}}
