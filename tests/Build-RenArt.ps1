$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$repo=Split-Path $PSScriptRoot -Parent
Add-Type -Path @((Join-Path $repo 'lib/Pet.Life.cs'),(Join-Path $repo 'lib/Pet.Life.Art.cs'),(Join-Path $repo 'lib/Pet.Life.Visual.cs')) -ReferencedAssemblies @([Windows.Media.DrawingImage].Assembly.Location,[Windows.Point].Assembly.Location,'System.Xaml','System.Core')
$rig=[RenLifeVisual]::new((Join-Path $repo 'assets/characters/ren/life'))
function Save-Png($Image,[string]$Path){$e=[Windows.Media.Imaging.PngBitmapEncoder]::new();$e.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($Image));$s=[IO.File]::Create($Path);try{$e.Save($s)}finally{$s.Dispose()}}
$v=[Windows.Media.DrawingVisual]::new();$d=$v.RenderOpen()
for($r=0;$r -lt 24;$r++){for($f=0;$f -lt $(if($r -in @(9,10)){8}else{4});$f++){$d.DrawImage($rig.Frame($r,$f),[Windows.Rect]::new($f*192,$r*208,192,208))}}
$d.Close();$b=[Windows.Media.Imaging.RenderTargetBitmap]::new(1536,4992,96,96,[Windows.Media.PixelFormats]::Pbgra32);$b.Render($v)
Save-Png $b (Join-Path $repo 'assets/characters/ren/atlas.png')
Save-Png ($rig.Frame(0,0)) (Join-Path $repo 'assets/characters/ren/portrait.png')
Write-Output 'Built Ren atlas and portrait.'