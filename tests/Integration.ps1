# Runs inside pet.ps1 -SelfTest, using an isolated data directory.
function Invoke-IntegrationTests {
    $script:checks=[Collections.Generic.List[string]]::new()
    $limitations=[Collections.Generic.List[string]]::new()
    function Check($Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$script:checks.Add($Name)}
    function Pump {
        $f=[System.Windows.Threading.DispatcherFrame]::new()
        $null=$w.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background,[Action]{$f.Continue=$false}.GetNewClosure())
        [System.Windows.Threading.Dispatcher]::PushFrame($f)
        [System.Windows.Forms.Application]::DoEvents()
    }
    function Capture([string]$Name) {
        $w.UpdateLayout();Pump
        $render=[System.Windows.Media.Imaging.RenderTargetBitmap]::new([int]$w.Width,[int]$w.Height,96,96,[System.Windows.Media.PixelFormats]::Pbgra32)
        $render.Render($panel);$encoder=[System.Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($render))
        $stream=[IO.File]::Create((Join-Path $dataDirectory $Name));try{$encoder.Save($stream)}finally{$stream.Dispose()}
    }
    function Pump-For([int]$Milliseconds){$end=$clock.ElapsedMilliseconds+$Milliseconds;while($clock.ElapsedMilliseconds -lt $end){Pump;Start-Sleep -Milliseconds 15}}
    Check ($frames.Count -eq 73) '73 animation frames loaded'
    for($r=0;$r -lt 9;$r++){Set-Animation $r;Check ($img.Source.PixelWidth -eq 192) "animation row $r"}
    for($d=0;$d -lt 16;$d++){$img.Source=$frames["$(9+[math]::Floor($d/8)),$($d%8)"];Check ($img.Source.PixelHeight -eq 208) "gaze $d"}
    $script:cooldownUntil=0;$null=Invoke-Interaction 'pet'
    Check ($state.mood -eq 'happy' -and $bubbleText.Text -match '摸摸') 'petting response'
    Check (-not (Invoke-Interaction 'cookie')) 'interaction cooldown blocks spam'
    foreach($index in 0..2){$script:cooldownUntil=0;$feed.Items[$index].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent));Check ($bubble.Visibility -eq 'Visible') "food menu $index"}
    $script:cooldownUntil=0;$null=Invoke-Interaction 'cookie';Capture 'feeding.png'
    $script:cooldownUntil=0
    Begin-Pointer ([System.Windows.Point]::new(100,100)) 0.2 $false;End-Pointer
    Check ($pendingClick.action -eq 'pet') 'single click delayed for double-click discrimination'
    Begin-Pointer ([System.Windows.Point]::new(100,100)) 0.2 $true;End-Pointer
    Check ($null -eq $pendingClick -and $row -eq 4) 'double-click cancels pending head interaction'
    Begin-Pointer ([System.Windows.Point]::new(100,100)) 0.2 $false;Move-Pointer ([System.Windows.Point]::new(120,110));End-Pointer
    Check ($null -eq $pendingClick -and $row -eq 0) 'drag moves without interaction'
    $pomoMenu.Items[0].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))
    Check ($state.pomo.status -eq 'running' -and $badge.Visibility -eq 'Visible') 'start timer menu'
    Capture 'focus.png'
    $pomoMenu.Items[1].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))
    Check ($state.pomo.status -eq 'paused') 'pause timer menu'
    $state.pomo.remaining=1;Start-Timer;$event=Step-Pomodoro $state 1.1;Handle-TimerEvent $event;Update-Badge
    Check ($state.pomo.phase -eq 'short' -and $state.pomo.status -eq 'ready' -and $bubbleText.Text -match '完成一輪') 'completion celebration and manual break start'
    Capture 'completed.png'
    $state.quiet=$true;Hide-Bubble;Show-Bubble 'should not show'
    Check ($bubble.Visibility -eq 'Hidden') 'quiet mode suppresses optional bubbles'
    Show-Bubble 'timer completion' -Important
    Check ($bubble.Visibility -eq 'Visible') 'important timer bubble remains available'
    $state.quiet=$false
    Show-TimerSettings;Pump
    $durationBoxes.focusMinutes.Text='0'
    $saveButton=$settingsWindow.Content.Children[$settingsWindow.Content.Children.Count-1]
    $saveButton.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    Check ($null -ne $settingsWindow -and $state.focusMinutes -eq 25) 'invalid duration does not save'
    $durationBoxes.focusMinutes.Text='30';$saveButton.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    Check ($state.focusMinutes -eq 30 -and $null -eq $settingsWindow) 'duration settings save through UI'
    Resize-Pet 1;Check ($w.Width -eq 192 -and $w.Height -eq 328) 'small size includes bubble and badge'
    $w.Left=-10000;$w.Top=10000;Keep-Visible
    Check ($w.Left -gt -10000 -and $w.Top -lt 10000) 'window position clamped to visible monitor'
    Resize-Pet 1.5
    Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;
public class KalingProbe : Form {
    public int Clicks;
    public KalingProbe(){FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;BackColor=System.Drawing.Color.FromArgb(235,230,245);MouseDown+=(s,e)=>{Clicks++;};}
}
public static class KalingTestNative {
    [StructLayout(LayoutKind.Sequential)] public struct Point {public int X,Y;}
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint process);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a,uint b,bool attach);
    public static bool ActivateProbe(IntPtr h){
        uint pid;uint other=GetWindowThreadProcessId(GetForegroundWindow(),out pid);uint current=GetCurrentThreadId();
        bool attached=other!=current && AttachThreadInput(current,other,true);
        try{return SetForegroundWindow(h);}finally{if(attached)AttachThreadInput(current,other,false);}
    }
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
    [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
    public static void Hotkey(byte key){keybd_event(0x11,0,0,UIntPtr.Zero);keybd_event(0x12,0,0,UIntPtr.Zero);keybd_event(key,0,0,UIntPtr.Zero);keybd_event(key,0,2,UIntPtr.Zero);keybd_event(0x12,0,2,UIntPtr.Zero);keybd_event(0x11,0,2,UIntPtr.Zero);}
}
'@
    # Test production hotkey dispatch by posting WM_HOTKEY only to our own window.
    Check ($hotkeys.Count -eq 2) "both global hotkeys registered (errors: $hotkeyErrors)"
    [void][KalingTestNative]::PostMessage($hwnd,0x312,[IntPtr]1,[IntPtr]::Zero);Pump
    Check ($state.clickThrough -and (([KalingNative]::GetStyle($hwnd,-20) -band 0x20) -ne 0)) 'hotkey enables native click-through style'
    $trayThrough.PerformClick();Pump
    Check (-not $state.clickThrough -and (([KalingNative]::GetStyle($hwnd,-20) -band 0x20) -eq 0)) 'tray recovers mouse interaction'
    [void][KalingTestNative]::PostMessage($hwnd,0x312,[IntPtr]2,[IntPtr]::Zero);Pump
    Check (-not $w.IsVisible) 'hide hotkey keeps app running'
    [void][KalingTestNative]::PostMessage($hwnd,0x312,[IntPtr]2,[IntPtr]::Zero);Pump
    Check ($w.IsVisible) 'show hotkey restores hidden window'
    $probe=[KalingProbe]::new()
    try {
        $bounds=[System.Windows.Forms.Screen]::FromHandle($hwnd).Bounds
        $probe.Bounds=$bounds;$probe.Show();$activated=[KalingTestNative]::ActivateProbe($probe.Handle);Pump
        $conflict=[KalingNative]::RegisterHotKey($probe.Handle,91,0x4003,0x4B)
        if($conflict){[void][KalingNative]::UnregisterHotKey($probe.Handle,91)}
        Check (-not $conflict -and $tray.Visible) 'hotkey conflict is rejected while tray recovery remains available'
        [pscustomobject]@{activated=$activated;foreground=[KalingNative]::GetForegroundWindow().ToInt64();probe=$probe.Handle.ToInt64();pet=$hwnd.ToInt64()} | ConvertTo-Json | Set-Content (Join-Path $dataDirectory 'foreground-diagnostic.json')
        Check ([KalingNative]::IsFullscreen($probe.Handle,$hwnd)) 'native fullscreen recognition on pet monitor'
        if($activated){
            $state.autoHide=$true;$script:nextPoll=0;$timer.Start();Pump-For 700
            Check (-not $w.IsVisible -and $bubble.Visibility -eq 'Hidden') 'foreground fullscreen polling hides pet and bubble'
        }else{
            $limitations.Add('Windows denied foreground activation of the test window; automatic foreground polling could not be exercised end to end.')
            $script:fullscreenHidden=[KalingNative]::IsFullscreen($probe.Handle,$hwnd);Update-Visibility
            Check (-not $w.IsVisible -and $bubble.Visibility -eq 'Hidden') 'native fullscreen result hides pet and bubble'
        }
        $probe.Width=[int]($bounds.Width/2);Pump-For 700
        Check (-not [KalingNative]::IsFullscreen($probe.Handle,$hwnd)) 'ordinary window is not fullscreen'
        if(-not $activated){$script:fullscreenHidden=[KalingNative]::IsFullscreen($probe.Handle,$hwnd);Update-Visibility}
        Check ($w.IsVisible) 'exit fullscreen restores pet'
    }finally{$timer.Stop();$probe.Close();$probe.Dispose()}
    # Real desktop input is sent only after hit-testing our own disposable probe process.
    $savedCursor=[KalingTestNative+Point]::new();[void][KalingTestNative]::GetCursorPos([ref]$savedCursor)
    $child=$null
    try {
        $script:fullscreenHidden=$false;Update-Visibility;Set-Animation 0 0;Hide-Bubble;$w.UpdateLayout();Pump-For 150
        $target=$img.PointToScreen([System.Windows.Point]::new($img.ActualWidth*0.5,$img.ActualHeight*0.35))
        $point=[KalingTestNative+Point]::new();$point.X=[int]$target.X;$point.Y=[int]$target.Y
        $probeDirectory=Join-Path $dataDirectory ('probe-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($probeDirectory)
        $probeScript=Join-Path $PSScriptRoot 'DesktopProbe.ps1'
        $exe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arguments='-NoProfile -STA -ExecutionPolicy Bypass -File "'+$probeScript+'" -Directory "'+$probeDirectory+'" -X '+($point.X-100)+' -Y '+($point.Y-100)
        $child=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
        $deadline=$clock.ElapsedMilliseconds+6000
        while(-not (Test-Path (Join-Path $probeDirectory 'probe-handle.txt')) -and $clock.ElapsedMilliseconds -lt $deadline){Pump-For 50}
        $probeHandle=[IntPtr]::new([long][IO.File]::ReadAllText((Join-Path $probeDirectory 'probe-handle.txt')))
        [void][KalingTestNative]::ActivateProbe($probeHandle);Pump-For 200
        if([KalingTestNative]::WindowFromPoint($point) -eq $hwnd){
            Check $true 'opaque pet intercepts hit-test before click-through'
            [KalingTestNative]::Hotkey(0x4B);Pump-For 200
            Check ($state.clickThrough) 'physical Ctrl+Alt+K reaches registered hotkey'
            Check ([KalingTestNative]::WindowFromPoint($point) -eq $probeHandle) 'click-through hit-test reaches another process'
            [void][KalingTestNative]::SetCursorPos($point.X,$point.Y)
            [KalingTestNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[KalingTestNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero);Pump-For 250
            Check (Test-Path (Join-Path $probeDirectory 'probe-click.txt')) 'actual click delivered to underlying process'
            [KalingTestNative]::Hotkey(0x4B);Pump-For 150
            Check (-not $state.clickThrough) 'physical shortcut restores interaction'
        }else{$limitations.Add('The test window was not the OS hit-test target; physical input was skipped to avoid clicking another application.')}
    }finally{
        [void][KalingTestNative]::SetCursorPos($savedCursor.X,$savedCursor.Y)
        if($state.clickThrough){Toggle-Through}
        if($child -and -not $child.HasExited){[void][KalingTestNative]::PostMessage($probeHandle,0x10,[IntPtr]::Zero,[IntPtr]::Zero);[void]$child.WaitForExit(3000);if(-not $child.HasExited){$child.Kill()}}
    }
    Reset-Pomodoro $state;Start-Timer;$before=$state.pomo.remaining;$script:nextStory=0;$script:actionUntil=0;$state.stories=$true;Hide-Bubble
    $timer.Start();Pump-For 400;$timer.Stop()
    Check ($state.pomo.remaining -lt $before -and $bubble.Visibility -eq 'Hidden' -and $nextStory -eq 0) 'live timer advances while suppressing spontaneous story'
    Pause-Timer;$script:actionUntil=0;$script:nextStory=0;$timer.Start();Pump-For 200;$timer.Stop()
    Check ($nextStory -gt $clock.ElapsedMilliseconds -and $bubble.Visibility -eq 'Visible') 'spontaneous story uses live dispatcher and cooldown'
    $state.quiet=$true;$script:actionUntil=0;$script:nextStory=0;Hide-Bubble;$timer.Start();Pump-For 200;$timer.Stop()
    Check ($bubble.Visibility -eq 'Hidden' -and $nextStory -eq 0) 'quiet mode suppresses live story';$state.quiet=$false
    $state.mode='follow';$state.look=$false;$state.stories=$false;Save-Settings
    $restored=Read-PetState $dataDirectory
    Check ($restored.mode -eq 'follow' -and -not $restored.look -and -not $restored.stories -and $restored.scale -eq 1.5) 'UI preferences persist'
    $script:cooldownUntil=0;$null=Invoke-Interaction 'pet';Capture 'petting.png'
    $limitations.Add('Physical mixed-DPI multi-monitor transitions are not covered by this single-desktop test.')
    $limitations.Add('Sleep is tested through elapsed-gap logic; physical suspend/resume is not forced.')
    @{ok=$true;count=$checks.Count;checks=@($checks);limitations=@($limitations)} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $dataDirectory 'integration.json') -Encoding UTF8
}
