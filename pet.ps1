param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
$script:root=$PSScriptRoot
$script:log=Join-Path $root 'pet-error.log'
$created=$false
$script:instanceMutex=[Threading.Mutex]::new($true, ('Local\KalingDesktopPet'+[string]$SelfTest), [ref]$created)
if(-not $created){$instanceMutex.Dispose();exit 0}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PetCursor {
 [StructLayout(LayoutKind.Sequential)] public struct Point { public int X; public int Y; }
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
}
'@
$script:root = $PSScriptRoot
$script:log = Join-Path $root 'pet-error.log'
trap { $_ | Out-String | Set-Content -LiteralPath $script:log -Encoding UTF8; if(-not $SelfTest){[System.Windows.MessageBox]::Show("咖凌啟動遇到問題。請查看資料夾內的 pet-error.log。", '咖凌')}; exit 1 }
$script:atlas = New-Object System.Windows.Media.Imaging.BitmapImage
$atlas.BeginInit(); $atlas.CacheOption = 'OnLoad'; $atlas.UriSource = [Uri](Join-Path $root 'spritesheet.png'); $atlas.EndInit(); $atlas.Freeze()
if ($atlas.PixelWidth -ne 1536 -or $atlas.PixelHeight -ne 2288) { throw 'Invalid sprite atlas dimensions' }
$script:counts = @(6,8,8,4,5,8,6,6,6,8,8)
$script:durations = @(@(280,110,110,140,140,320),@(120,120,120,120,120,120,120,220),@(120,120,120,120,120,120,120,220),@(140,140,140,280),@(140,140,140,140,280),@(140,140,140,140,140,140,140,240),@(150,150,150,150,150,260),@(120,120,120,120,120,220),@(150,150,150,150,150,280))
$script:frames = @{}
for($r=0;$r -lt 11;$r++){ for($c=0;$c -lt $counts[$r];$c++){
 $b = New-Object System.Windows.Media.Imaging.CroppedBitmap($atlas, ([System.Windows.Int32Rect]::new($c*192,$r*208,192,208)))
 $b.Freeze(); $frames["$r,$c"] = $b
}}
$script:w = New-Object System.Windows.Window
$w.Title='咖凌・桌面寵物'; $w.WindowStyle='None'; $w.ResizeMode='NoResize'; $w.AllowsTransparency=$true
$w.Background=[System.Windows.Media.Brushes]::Transparent; $w.Topmost=$true; $w.ShowInTaskbar=$false; $w.ShowActivated=$false
$w.Width=288; $w.Height=312
$script:img=New-Object System.Windows.Controls.Image
$img.Stretch='Uniform'; $img.Source=$frames['0,0']; $img.Cursor='Hand'; $img.ToolTip='拖曳移動 · 點一下揮手 · 點兩下跳躍 · 右鍵選單'
$w.Content=$img
$script:clock=[Diagnostics.Stopwatch]::StartNew()
$script:row=0; $script:frame=0; $script:nextFrame=0L; $script:until=0L; $script:mode='stay'; $script:look=$true
$script:drag=$false; $script:moved=$false; $script:press=$null; $script:lastX=0.0; $script:nextAction=6000L; $script:direction=1
$script:testIndex=0; $script:testDeadline=0L; $script:testRecords=New-Object System.Collections.Generic.List[string]
$script:reportedRunning=$false
function Set-State([int]$row,[int]$milliseconds=2000) {
 $script:row=$row; $script:frame=0; $script:nextFrame=$clock.ElapsedMilliseconds+$durations[$row][0]
 $script:until=$clock.ElapsedMilliseconds+$milliseconds; $img.Source=$frames["$row,0"]
}
function Keep-Visible {
 $handle=(New-Object System.Windows.Interop.WindowInteropHelper($w)).Handle
 $area=[System.Windows.Forms.Screen]::FromHandle($handle).WorkingArea
 $source=[System.Windows.PresentationSource]::FromVisual($w)
 if ($source) { $m=$source.CompositionTarget.TransformFromDevice } else { $m=[System.Windows.Media.Matrix]::Identity }
 $a=$m.Transform([System.Windows.Point]::new($area.Left,$area.Top)); $b=$m.Transform([System.Windows.Point]::new($area.Right,$area.Bottom))
 $w.Left=[Math]::Max($a.X,[Math]::Min($w.Left,$b.X-$w.Width)); $w.Top=[Math]::Max($a.Y,[Math]::Min($w.Top,$b.Y-$w.Height))
}
function Cursor-Position {
 $p=New-Object PetCursor+Point; [void][PetCursor]::GetCursorPos([ref]$p)
 $source=[System.Windows.PresentationSource]::FromVisual($w)
 if($source){return $source.CompositionTarget.TransformFromDevice.Transform([System.Windows.Point]::new($p.X,$p.Y))}
 return [System.Windows.Point]::new($p.X,$p.Y)
}
function Resize-Pet([double]$scale) { $bottom=$w.Top+$w.Height; $w.Width=192*$scale; $w.Height=208*$scale; $w.Top=$bottom-$w.Height; Keep-Visible }
$script:menu=New-Object System.Windows.Controls.ContextMenu
function Menu-Item([string]$label,[scriptblock]$action){$item=New-Object System.Windows.Controls.MenuItem; $item.Header=$label; $item.Add_Click($action); [void]$menu.Items.Add($item);return $item}
$null=Menu-Item '咖凌 · 你好呀！' { Set-State 3 }
$null=Menu-Item '跳一下' { Set-State 4 840 }
$null=Menu-Item '等你一下' { Set-State 6 3500 }
$null=Menu-Item '認真思考' { Set-State 7 3500 }
$null=Menu-Item '仔細檢查' { Set-State 8 3500 }
$null=Menu-Item '有點失落' { Set-State 5 1600 }
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
$null=Menu-Item '留在原地' { $script:mode='stay'; Set-State 0 0 }
$null=Menu-Item '自由散步' { $script:mode='wander'; $script:nextAction=0 }
$null=Menu-Item '跟著滑鼠' { $script:mode='follow'; Set-State 0 0 }
$script:lookItem=Menu-Item '看向滑鼠' { $script:look=$lookItem.IsChecked }
$lookItem.IsCheckable=$true; $lookItem.IsChecked=$true
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
$null=Menu-Item '小隻 · 100%' { Resize-Pet 1 }
$null=Menu-Item '標準 · 150%' { Resize-Pet 1.5 }
$null=Menu-Item '大隻 · 200%' { Resize-Pet 2 }
$null=Menu-Item '打開動畫圖鑑' { Start-Process -FilePath (Join-Path $root 'preview.html') }
$null=Menu-Item '關閉咖凌' { $w.Close() }
$img.ContextMenu=$menu
$img.Add_MouseLeftButtonDown({
 param($sender,$e)
 if($e.ClickCount -eq 2){Set-State 4 840; $e.Handled=$true; return}
 $script:press=Cursor-Position; $script:lastX=$press.X; $script:origin=[System.Windows.Point]::new($w.Left,$w.Top)
 $script:drag=$true; $script:moved=$false; [void]$img.CaptureMouse(); $e.Handled=$true
})
$img.Add_MouseMove({
 if(-not $script:drag){return}; $p=Cursor-Position; $dx=$p.X-$press.X; $dy=$p.Y-$press.Y
 if([Math]::Abs($dx)+[Math]::Abs($dy) -gt 5){$script:moved=$true}
 if($moved){$w.Left=$origin.X+$dx;$w.Top=$origin.Y+$dy; $r=if($p.X -lt $lastX){2}else{1};if($row -ne $r){Set-State $r 500};$script:lastX=$p.X}
})
$img.Add_MouseLeftButtonUp({
 if(-not $drag){return}; $script:drag=$false; $img.ReleaseMouseCapture(); Keep-Visible
 if($moved){Set-State 0 0}else{Set-State 3 1800}
})
$img.Add_LostMouseCapture({$script:drag=$false})
$w.Add_KeyDown({param($s,$e); if($e.Key -eq 'Escape'){$w.Close()}})
$w.Add_Loaded({$area=[System.Windows.SystemParameters]::WorkArea; $w.Left=$area.Right-$w.Width-36; $w.Top=$area.Bottom-$w.Height-16; Keep-Visible; Set-State 3 1600})
$script:timer=New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(33)
$timer.Add_Tick({
 try {
 $now=$clock.ElapsedMilliseconds
 if(-not $SelfTest -and -not $reportedRunning -and $now -gt 3000){
  @{pid=$PID;visible=$w.IsVisible;frames=$frames.Count;mode=$mode;status='running';time=(Get-Date -Format o)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'runtime-status.json') -Encoding UTF8
  $script:reportedRunning=$true
 }
 if($SelfTest){
  if($now -ge $script:testDeadline){
   if($script:testIndex -lt 9){Set-State $script:testIndex 500; $testRecords.Add("state:$script:testIndex")}
   elseif($script:testIndex -lt 25){$d=$script:testIndex-9; $img.Source=$frames["$(9+[Math]::Floor($d/8)),$($d%8)"]; $testRecords.Add("look:$d")}
   elseif($script:testIndex -eq 25){Resize-Pet 1; $testRecords.Add("resize:$($w.Width)x$($w.Height)")}
   elseif($script:testIndex -eq 26){Resize-Pet 2; $w.Left=-10000; Keep-Visible; $testRecords.Add("clamped:$($w.Left)")}
   elseif($script:testIndex -eq 27){
    $menu.Items[0].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))
    if($row -ne 3){throw 'Wave menu event failed'};$testRecords.Add('menu-wave:pass')
    $menu.Items[1].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))
    if($row -ne 4){throw 'Jump menu event failed'};$testRecords.Add('menu-jump:pass')
    $img.Source=$frames['3,2'];$w.UpdateLayout()
    $render=[System.Windows.Media.Imaging.RenderTargetBitmap]::new([int]$w.Width,[int]$w.Height,96,96,[System.Windows.Media.PixelFormats]::Pbgra32)
    $render.Render($img);$encoder=New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($render))
    $stream=[IO.File]::Create((Join-Path $root 'desktop-render-test.png'));$encoder.Save($stream);$stream.Dispose()
   }
   else{$testRecords.Add("frames:$($frames.Count)");$testRecords | Set-Content (Join-Path $root 'selftest.log') -Encoding UTF8;$w.Close();return}
   $script:testDeadline=$now+$(if($script:testIndex -lt 9){1600}else{250});$script:testIndex++
  }
  if($script:testIndex -gt 9){return}
 }
 if($menu.IsOpen){return}
 if(-not $SelfTest -and -not $drag -and $now -gt $until){
  $p=Cursor-Position; $cx=$w.Left+$w.Width/2; $cy=$w.Top+$w.Height*0.37; $dx=$p.X-$cx;$dy=$p.Y-$cy
  $moving=$false
  if($mode -eq 'follow' -and [Math]::Abs($dx) -gt $w.Width*0.7){$direction=[Math]::Sign($dx);$w.Left+=$direction*2.5;$moving=$true}
  elseif($mode -eq 'wander'){
   if($now -gt $nextAction){$script:direction=if((Get-Random -Maximum 2) -eq 0){-1}else{1};$script:nextAction=$now+6000;$script:walkEnd=$now+1600}
   if($now -lt $script:walkEnd){$w.Left+=$direction*1.8;$moving=$true}
  }
  if($moving){Keep-Visible;$r=if($direction -lt 0){2}else{1};if($row -ne $r){Set-State $r 0}}
  elseif($look -and [Math]::Sqrt($dx*$dx+$dy*$dy) -gt 70 -and [Math]::Sqrt($dx*$dx+$dy*$dy) -lt 750){
   $angle=([Math]::Atan2($dx,-$dy)*180/[Math]::PI+360)%360; $d=[int][Math]::Floor(($angle+11.25)/22.5)%16
   $img.Source=$frames["$(9+[Math]::Floor($d/8)),$($d%8)"];return
  } elseif($row -ne 0){Set-State 0 0}
 }
 if($now -ge $nextFrame){$script:frame=($frame+1)%$counts[$row];$img.Source=$frames["$row,$frame"];$script:nextFrame=$now+$durations[$row][$frame]}
 } catch { $_ | Out-String | Add-Content -LiteralPath $script:log -Encoding UTF8; $timer.Stop();$w.Close() }
})
$w.Add_Closed({$timer.Stop();$instanceMutex.ReleaseMutex();$instanceMutex.Dispose()})
$timer.Start()
[void]$w.ShowDialog()
