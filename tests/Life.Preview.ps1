param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase
$repo=Split-Path $PSScriptRoot -Parent
Add-Type -Path (Join-Path $repo 'lib/Pet.Life.cs') -ReferencedAssemblies @([System.Windows.Media.DrawingImage].Assembly.Location,[System.Windows.Point].Assembly.Location,'System.Xaml')
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$life=[RenLifeState]::new(42);$rig=[RenLifeVisual]::new((Join-Path $repo 'assets/characters/ren/life-parts.png'))
$atlas=[System.Windows.Media.Imaging.BitmapImage]::new();$atlas.BeginInit();$atlas.CacheOption='OnLoad';$atlas.UriSource=[Uri](Join-Path $repo 'assets/characters/ren/atlas.png');$atlas.EndInit();$atlas.Freeze()
$frames=@{};foreach($row in @(0,8,10,11)){foreach($f in 0..7){$p=[System.Windows.Media.Imaging.CroppedBitmap]::new($atlas,[System.Windows.Int32Rect]::new($f*192,$row*208,192,208));$p.Freeze();$frames["$row,$f"]=$p}}
$font=[System.Windows.Media.Typeface]::new('Microsoft JhengHei UI')
function Label($DC,[string]$Text,[double]$X,[double]$Y,[double]$Size,$Color){
 $f=[System.Windows.Media.FormattedText]::new($Text,[Globalization.CultureInfo]::GetCultureInfo('zh-TW'),[System.Windows.FlowDirection]::LeftToRight,$font,$Size,([System.Windows.Media.BrushConverter]::new()).ConvertFromString($Color));$DC.DrawText($f,[System.Windows.Point]::new($X,$Y))
}
for($i=0;$i -lt 1800;$i++){
 $t=$i/30.0;$near=$t -ge 26 -and $t -lt 40;$quiet=$t -ge 46 -and $t -lt 56;$pet=$t -ge 34 -and $t -lt 36.64
 if($i -eq 1020){$life.Press();$life.Pet()}
 $life.Step((1.0/30),-.85,-.2,$near,$true,$true,$quiet,$true,$pet);$rig.Render($life,$quiet,$pet)
 $r=0;$f=([int][math]::Floor($t/.22))%4
 if($pet){$r=11;$f=([int][math]::Floor(($t-34)/.33))%4}elseif($near){$r=10;$f=4}elseif($quiet){$r=8;$f=([int][math]::Floor($t/.3))%4}
 $phase=if($t -lt 26){'安靜待機 · 呼吸、眨眼與自主小動作'}elseif($t -lt 34){'滑鼠靠近 · 先看一眼，再轉頭'}elseif($pet){'摸摸頭 · 立即回應'}elseif($t -lt 40){'摸完之後 · 放鬆的表情延續幾秒'}elseif($t -lt 46){'滑鼠離開 · 稍作停留，自然回正'}elseif($quiet){'專注模式 · 保留呼吸眨眼，暫停小劇場'}else{'繼續陪伴 · 回到日常節奏'}
 $v=[System.Windows.Media.DrawingVisual]::new();$d=$v.RenderOpen()
 $d.DrawRectangle(([System.Windows.Media.BrushConverter]::new()).ConvertFromString('#111e2c'),$null,[System.Windows.Rect]::new(0,0,960,540))
 $d.DrawRectangle(([System.Windows.Media.BrushConverter]::new()).ConvertFromString('#fff3e8'),$null,[System.Windows.Rect]::new(480,0,480,468))
 Label $d '原版 v1.5' 32 22 20 '#c0d0de';Label $d '新版 · 蓮的日常' 512 22 20 '#485548'
 $d.DrawImage($frames["$r,$f"],[System.Windows.Rect]::new(96,95,288,312));$d.DrawImage($rig.Image,[System.Windows.Rect]::new(576,95,288,312))
 if($near){foreach($x in @(62,542)){$d.DrawEllipse([System.Windows.Media.Brushes]::Gold,$null,[System.Windows.Point]::new($x,210),5,5)}}
 Label $d $phase 32 482 21 '#f7e7c9';Label $d ('{0:00} / 60 秒' -f [int]$t) 800 489 14 '#b2c7d1'
 Label $d 'WPF 共用渲染器 · 示範時間軸，非桌面錄影' 32 447 12 '#91a6b7'
 $d.Close();$render=[System.Windows.Media.Imaging.RenderTargetBitmap]::new(960,540,96,96,[System.Windows.Media.PixelFormats]::Pbgra32);$render.Render($v)
 $enc=[System.Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($render));$stream=[IO.File]::Create((Join-Path $OutputDirectory ('frame-{0:0000}.png' -f $i)));try{$enc.Save($stream)}finally{$stream.Dispose()}
 if($i%300 -eq 0){Write-Output "Rendered $i / 1800 frames"}
}
