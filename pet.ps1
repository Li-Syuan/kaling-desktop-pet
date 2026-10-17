param([switch]$SelfTest,[string]$TestDataDirectory,[switch]$PhysicalInputTest,[switch]$PlayTestsOnly,[switch]$WorldTestsOnly,[switch]$WorldPreview)
$ErrorActionPreference='Stop'
$script:root=$PSScriptRoot
if($SelfTest){
    if(-not $TestDataDirectory){$TestDataDirectory=Join-Path ([IO.Path]::GetTempPath()) ('KalingPet-Test-'+[guid]::NewGuid().ToString('N'))}
    $script:dataDirectory=[IO.Path]::GetFullPath($TestDataDirectory)
}else{$script:dataDirectory=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'KalingPet'}
[void][IO.Directory]::CreateDirectory($dataDirectory)
if($SelfTest){Write-Output "Self-test output: $dataDirectory"}
$script:log=Join-Path $dataDirectory 'pet-error.log'
trap {
    $_ | Out-String | Add-Content -LiteralPath $script:log -Encoding UTF8
    if(-not $SelfTest){[System.Windows.MessageBox]::Show("咖凌啟動遇到問題。錯誤紀錄：$script:log",'咖凌') | Out-Null}
    exit 1
}
$created=$false
$script:mutex=[Threading.Mutex]::new($true,('Local\KalingDesktopPet'+[string]$SelfTest),[ref]$created)
if(-not $created){$mutex.Dispose();exit 0}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $root 'lib\Pet.Native.cs')
Add-Type -Path @((Join-Path $root 'lib\Pet.Life.cs'),(Join-Path $root 'lib\Pet.Life.Art.cs'),(Join-Path $root 'lib\Pet.Life.Visual.cs')) -ReferencedAssemblies @([System.Windows.Media.DrawingImage].Assembly.Location,[System.Windows.Point].Assembly.Location,'System.Xaml','System.Core')
Add-Type -Path @((Join-Path $root 'lib\Pet.Play.Model.cs'),(Join-Path $root 'lib\Pet.Play.Visual.cs')) -ReferencedAssemblies @([System.Windows.Media.DrawingImage].Assembly.Location,[System.Windows.FrameworkElement].Assembly.Location,[System.Windows.Point].Assembly.Location,'System.Xaml','System.Core')
Add-Type -Path @((Join-Path $root 'lib\Pet.World.Model.cs'),(Join-Path $root 'lib\Pet.World.Visual.cs')) -ReferencedAssemblies @([System.Windows.Media.DrawingImage].Assembly.Location,[System.Windows.FrameworkElement].Assembly.Location,[System.Windows.Point].Assembly.Location,'System.Xaml','System.Core')
. (Join-Path $root 'lib\Pet.State.ps1')
. (Join-Path $root 'lib\Pet.Assets.ps1')
. (Join-Path $root 'lib\Pet.Activity.ps1')
. (Join-Path $root 'lib\Pet.Room.Theme.ps1')
. (Join-Path $root 'lib\Pet.Room.ps1')
. (Join-Path $root 'lib\Pet.Care.ps1')
. (Join-Path $root 'lib\Pet.Life.ps1')
. (Join-Path $root 'lib\Pet.Play.ps1')
. (Join-Path $root 'lib\Pet.Play.Photo.ps1')
. (Join-Path $root 'lib\Pet.World.ps1')
$script:state=Read-PetState $dataDirectory
$script:app=[System.Windows.Application]::new();$app.ShutdownMode='OnExplicitShutdown'
$script:clock=[Diagnostics.Stopwatch]::StartNew()
$script:outfitCache=@{};$script:catalog=Read-OutfitCatalog $root
Select-Outfit $state.outfit
$script:w=[System.Windows.Window]::new()
$w.Title=$character.displayName+' · 陪伴日常';$w.WindowStyle='None';$w.ResizeMode='NoResize';$w.AllowsTransparency=$true
$w.Background=[System.Windows.Media.Brushes]::Transparent;$w.Topmost=$true;$w.ShowInTaskbar=$false;$w.ShowActivated=$false
$script:panel=[System.Windows.Controls.Grid]::new()
foreach($height in @(88,312,32)){$rd=[System.Windows.Controls.RowDefinition]::new();$rd.Height=[System.Windows.GridLength]::new($height);[void]$panel.RowDefinitions.Add($rd)}
$script:bubble=[System.Windows.Controls.Border]::new()
$bubble.Background='#FFF6FA';$bubble.BorderBrush='#DFC0CF';$bubble.BorderThickness=1;$bubble.CornerRadius=14;$bubble.Padding='12,8';$bubble.Margin='4,4,4,5';$bubble.VerticalAlignment='Bottom';$bubble.Visibility='Hidden';$bubble.IsHitTestVisible=$false
$script:bubbleText=[System.Windows.Controls.TextBlock]::new();$bubbleText.Foreground='#60384E';$bubbleText.FontFamily='Microsoft JhengHei UI';$bubbleText.FontSize=13;$bubbleText.TextWrapping='Wrap';$bubbleText.TextAlignment='Center';$bubble.Child=$bubbleText
[void]$panel.Children.Add($bubble)
$script:img=[System.Windows.Controls.Image]::new();$img.Stretch='Uniform';$img.Source=$frames['0,0'];$img.Cursor='Hand'
$img.ToolTip='摸摸頭 · 點身體揮手 · 雙擊跳躍 · 拖曳移動 · 右鍵選單'
[System.Windows.Controls.Grid]::SetRow($img,1);[void]$panel.Children.Add($img)
$script:badge=[System.Windows.Controls.Border]::new();$badge.Background='#F5EAF2';$badge.CornerRadius=10;$badge.Margin='12,2';$badge.Padding='8,3';$badge.Visibility='Hidden'
$script:badgeText=[System.Windows.Controls.TextBlock]::new();$badgeText.FontFamily='Microsoft JhengHei UI';$badgeText.FontSize=12;$badgeText.TextAlignment='Center';$badgeText.Foreground='#60384E';$badge.Child=$badgeText
[System.Windows.Controls.Grid]::SetRow($badge,2);[void]$panel.Children.Add($badge);$w.Content=$panel
$script:row=0;$script:frame=0;$script:nextFrame=0L;$script:actionUntil=0L;$script:bubbleUntil=0L
$script:drag=$false;$script:moved=$false;$script:doublePress=$false;$script:pendingClick=$null
$script:cooldownUntil=0L;$script:nextWalk=0L;$script:walkEnd=0L;$script:direction=1
$script:nextStory=480000L;$script:lastTick=0L;$script:nextPoll=0L;$script:nextSave=10000L
$script:manualHidden=$false;$script:fullscreenHidden=$false;$script:closing=$false;$script:loaded=$false;$script:settingsWindow=$null
$script:hwnd=[IntPtr]::Zero;$script:hotkeys=@();$script:hotkeyErrors=@();$script:testFailed=$false;$script:savedError=$false
$script:resting='none';$script:lastInteraction=0L;$script:peeking=$false;$script:peekReturn=$null;$script:wardrobeWindow=$null;$script:wardrobeButtons=$null

function Save-Settings {
    if($loaded){if($peeking){$state.left=$peekReturn.left;$state.top=$peekReturn.top}else{$state.left=$w.Left;$state.top=$w.Top}}
    if($activity.kind -eq 'attack'){$state.left=$activity.originLeft}
    try{Write-PetState $state $dataDirectory;$script:savedError=$false}catch{
        $_ | Out-String | Add-Content -LiteralPath $log -Encoding UTF8
        if(-not $savedError){$script:savedError=$true;Show-Bubble '設定暫時無法儲存，請檢查資料夾權限。' -Important}
    }
}
function Set-Animation([int]$Row,[int]$Milliseconds=2000) {
    if($activity.kind -eq 'attack'){Stop-Activity}
    $script:row=$Row;$script:frame=0;$script:nextFrame=$clock.ElapsedMilliseconds+$durations[$Row][0]
    $script:actionUntil=$clock.ElapsedMilliseconds+$Milliseconds;$img.Source=$frames["$Row,0"]
    if($room.open){$room.nextFrame=$room.time+$durations[$Row][0]/1000.0}
}
function Show-Bubble([string]$Text,[switch]$Important) {
    if($manualHidden -or $fullscreenHidden){return}
    if(-not $Important -and (-not $state.bubbles -or $state.quiet)){return}
    if($room.open){Set-RoomMessage $Text;return}
    $bubbleText.Text=$Text;$bubble.Visibility='Visible';$script:bubbleUntil=$clock.ElapsedMilliseconds+$(if($Important){7000}else{4000})
}
function Hide-Bubble {$bubble.Visibility='Hidden';$script:bubbleUntil=0}
function Keep-Visible {
    if($hwnd -eq [IntPtr]::Zero -or $peeking){return}
    $area=[System.Windows.Forms.Screen]::FromHandle($hwnd).WorkingArea
    $m=([System.Windows.PresentationSource]::FromVisual($w)).CompositionTarget.TransformFromDevice
    $a=$m.Transform([System.Windows.Point]::new($area.Left,$area.Top));$b=$m.Transform([System.Windows.Point]::new($area.Right,$area.Bottom))
    $pos=Limit-PetPosition $w.Left $w.Top $w.Width $w.Height @{Left=$a.X;Top=$a.Y;Right=$b.X;Bottom=$b.Y}
    $w.Left=$pos.left;$w.Top=$pos.top
}
function Cursor-Position {
    $p=[KalingNative+Point]::new();[void][KalingNative]::GetCursorPos([ref]$p)
    return ([System.Windows.PresentationSource]::FromVisual($w)).CompositionTarget.TransformFromDevice.Transform([System.Windows.Point]::new($p.X,$p.Y))
}
function Resize-Pet([double]$Scale) {
    if($loaded){Mark-Activity}
    $bottom=$w.Top+$w.Height;$state.scale=$Scale;$w.Width=192*$Scale;$w.Height=208*$Scale+120
    $panel.RowDefinitions[1].Height=[System.Windows.GridLength]::new(208*$Scale)
    if($loaded){$w.Top=$bottom-$w.Height;Keep-Visible;Save-Settings}
}
function Exit-Peek {
    if($script:peeking){$script:peeking=$false;$w.Left=$peekReturn.left;$w.Top=$peekReturn.top;$script:peekReturn=$null;Keep-Visible}
}
function Mark-Activity {Stop-Activity;Stop-LifeGesture;Exit-Peek;$script:resting='none';$script:lastInteraction=$clock.ElapsedMilliseconds}
function Begin-Peek {
    $script:peekReturn=@{left=$w.Left;top=$w.Top}
    $area=[System.Windows.Forms.Screen]::FromHandle($hwnd).WorkingArea;$m=([System.Windows.PresentationSource]::FromVisual($w)).CompositionTarget.TransformFromDevice
    $edge=$m.Transform([System.Windows.Point]::new($area.Left,$area.Top));$script:peeking=$true;$w.Left=$edge.X-$w.Width*0.25
    Set-Animation 20 2240
}
function Invoke-Interaction([string]$Action) {
    if($Action -in @('cookie','pudding','tea') -and -not (Test-CareFoodAllowed $Action)){return $false}
    if($activity.kind -eq 'attack'){Stop-Activity;$script:cooldownUntil=0}
    if($room.open){Request-RoomAction $(switch($Action){'sleep'{'bed'};'sit'{'sofa'};default{$Action}});return $true}
    if($clock.ElapsedMilliseconds -lt $cooldownUntil -and $Action -ne 'wake'){return $false}
    Mark-Activity
    switch($Action){
        'pet' {$state.mood='happy';Set-Animation 11 2640;Show-Bubble (@('♥ 謝謝摸摸，今天也一起加油！','嘿嘿，有點害羞呢。','再摸一下也可以喔。') | Get-Random)}
        'smug' {Set-Animation (Resolve-RoomRow 21) 2200;Show-Bubble '嘿嘿，被你發現了。'}
        'wave' {Set-Animation 3 1600;Show-Bubble '嗨！我一直都在這裡。'}
        'jump' {Set-Animation 4 840;Show-Bubble '嘿咻！活動一下！'}
        'cookie' {$state.mood='happy';Set-Animation 12 2400;Show-Bubble '🍪 咔滋！這塊餅乾好香呀。'}
        'pudding' {$state.mood='happy';Set-Animation 13 2800;Show-Bubble '🍮 甜甜的布丁，心情也變甜了！'}
        'tea' {$state.mood='calm';Set-Animation 14 3200;Show-Bubble '🍵 喝口茶，我們慢慢來。'}
        'sit' {$script:resting='sitting';Set-Animation 15 1200;Show-Bubble '坐一下，晃晃腳陪著你。'}
        'sleep' {$script:resting='sleeping';Set-Animation 16 2600;Show-Bubble '借我打個小盹，點一下就醒來。'}
        'wake' {Set-Animation 17 2400;Show-Bubble '嗯…我醒了！你叫我嗎？'}
        'stretch' {Set-Animation 17 2400;Show-Bubble '伸個懶腰，再繼續吧。'}
        'spin' {Set-Animation 18 1440;Show-Bubble '開心轉一圈！'}
        'peek' {Begin-Peek;Show-Bubble '被你發現了！'}
        'waiting' {Set-Animation 6 3500}
        'thinking' {Set-Animation 7 3500}
        'review' {Set-Animation 8 3500}
        'sad' {Set-Animation 5 1600}
        default {return $false}
    }
    if($Action -in @('cookie','pudding','tea')){Begin-CareMeal $Action 'desktop' (@{cookie=2.4;pudding=2.8;tea=3.2}[$Action])}
    if($Action -eq 'pet'){Add-CareHappiness;Notify-Life 'pet'}
    $script:cooldownUntil=$clock.ElapsedMilliseconds+$(if($Action -in @('cookie','pudding','tea')){3500}else{1200})
    if($character.dialogue.$Action){Show-Bubble ([string]$character.dialogue.$Action)}
    Save-Settings;return $true
}
function Begin-Pointer($Point,[double]$Y,[bool]$Double) {
    $script:wasSleepingOnPress=$resting -eq 'sleeping';Mark-Activity
    Notify-Life 'press'
    $script:press=$Point;$script:lastX=$Point.X;$script:origin=[System.Windows.Point]::new($w.Left,$w.Top)
    $script:pressY=$Y;$script:drag=$true;$script:moved=$false;$script:doublePress=$Double
    if($Double){$script:pendingClick=$null}
}
function Move-Pointer($Point) {
    if(-not $drag){return}
    $dx=$Point.X-$press.X;$dy=$Point.Y-$press.Y
    if([math]::Abs($dx)+[math]::Abs($dy) -gt 5){$script:moved=$true;$script:pendingClick=$null}
    if($moved){$w.Left=$origin.X+$dx;$w.Top=$origin.Y+$dy;if($row -ne 19){Set-Animation 19 500};$script:lastX=$Point.X}
}
function End-Pointer {
    if(-not $drag){return}
    $script:lastInteraction=$clock.ElapsedMilliseconds
    $script:drag=$false;$img.ReleaseMouseCapture();Keep-Visible
    $kind=Get-ClickAction $moved $doublePress $pressY
    if($kind -eq 'drag'){$script:pendingClick=$null;Set-Animation 0 0;Save-Settings}
    elseif($kind -eq 'jump'){$script:pendingClick=$null;$null=Invoke-Interaction 'jump'}
    else{$script:pendingClick=@{action=$(if($wasSleepingOnPress){'wake'}else{$kind});due=$clock.ElapsedMilliseconds+[KalingNative]::GetDoubleClickTime()}}
}
function Update-Visibility {
    if(($manualHidden -or $fullscreenHidden) -and $careTask){Cancel-CareActivity}
    Sync-CareMesses
    if($worldWindow){
        if($manualHidden -or $fullscreenHidden){Close-World;return}
        if($w.IsVisible){$w.Hide()};if($room.open -and $room.window.IsVisible){$room.window.Hide()};return
    }
    if($playWindow){
        if($manualHidden -or $fullscreenHidden){Close-Play;return}
        if($w.IsVisible){$w.Hide()};if($room.open -and $room.window.IsVisible){$room.window.Hide()};return
    }
    if($room.open){if($w.IsVisible){$w.Hide()};if($manualHidden -or $fullscreenHidden){$room.window.Hide()}elseif(-not $room.window.IsVisible){$room.window.Show();Keep-RoomVisible};return}
    if($manualHidden -or $fullscreenHidden){Stop-Activity;Hide-Bubble;if($w.IsVisible){$w.Hide()}}
    elseif(-not $w.IsVisible -and -not $closing){$w.Show();Keep-Visible}
}
function Toggle-Visibility {$script:manualHidden=-not $manualHidden;Update-Visibility}
function Toggle-Through {
    $state.clickThrough=-not $state.clickThrough;[KalingNative]::ClickThrough($hwnd,$state.clickThrough)
    $throughItem.IsChecked=$state.clickThrough;Sync-CareMesses;Save-Settings
    if($room.open){Set-RoomMessage $(if($state.clickThrough){'桌面穿透已開啟，回桌面後套用。小屋保留家具與玩具互動。'}else{'桌面穿透已關閉。'});return}
    Show-Bubble $(if($state.clickThrough){'滑鼠穿透已開啟。Ctrl+Alt+K 或系統匣可恢復。'}else{'滑鼠互動已恢復。'}) -Important
}
function Start-Timer {
    if($room.open){Cancel-RoomActivity;Set-RoomMessage '安靜陪你專注，休息時再一起玩。'}
    Mark-Activity
    Start-Pomodoro $state;$script:lastTick=$clock.ElapsedMilliseconds;Hide-Bubble;Set-Animation 8 1200;Save-Settings;Update-Badge
}
function Pause-Timer {Pause-Pomodoro $state;Save-Settings;Update-Badge}
function Cancel-Timer {Reset-Pomodoro $state;Save-Settings;Update-Badge;Show-Bubble '好，我們先休息一下。'}
function Update-Badge {
    Update-CharacterMenus
    $p=$state.pomo
    if($p.status -eq 'ready' -and $p.phase -eq 'focus'){$badge.Visibility='Hidden';$tray.Text=($character.displayName+' · 陪伴日常');if($room.open){$room.timerText.Text='右鍵可切換安靜陪伴、日常小劇場與番茄鐘設定'};return}
    $label=switch($p.phase){'focus'{'專注'};'short'{'休息'};'long'{'長休息'}}
    $sec=[int][math]::Ceiling($p.remaining);$time='{0:00}:{1:00}' -f [int][math]::Floor($sec/60),($sec%60)
    $suffix=switch($p.status){'paused'{' · 暫停'};'ready'{' · 待開始'};default{''}}
    $badgeText.Text="$label $time$suffix";$badge.Visibility='Visible';$badge.ToolTip='右鍵選單：開始、暫停、取消或調整時間';$tray.Text=($character.displayName+' · '+$badgeText.Text)
    if($room.open){$room.timerText.Text=$badgeText.Text+' · 右鍵可調整陪伴偏好'}
}
function Handle-TimerEvent([string]$Event) {
    if($room.open -and $Event -in @('focus','short','long')){Cancel-RoomActivity;$room.phase='reaction';$room.until=$room.time+2.4}
    switch($Event){
        'focus' {Mark-Activity;Set-Animation 18 1440;Show-Bubble (Get-CharacterText 'focus' '完成一輪！休息準備好了，右鍵開始吧。') -Important;Save-Settings}
        {$_ -in @('short','long')} {Mark-Activity;Set-Animation 17 2400;Show-Bubble (Get-CharacterText 'rest' '休息結束，準備好再開始下一輪。') -Important;Save-Settings}
        'suspended' {Show-Bubble '剛才暫停了一會兒，番茄鐘已保留進度。' -Important;Save-Settings}
    }
}
function Set-Mode([string]$Mode) {if($room.open){Cancel-RoomActivity};Mark-Activity;$state.mode=$Mode;$script:nextWalk=0;Set-Animation 0 0;Update-CharacterMenus;Save-Settings}
function Toggle-Preference([string]$Name,$Item) {if($Name -eq 'quiet'){Mark-Activity};$state[$Name]=-not $state[$Name];$Item.IsChecked=$state[$Name];if($Name -in @('quiet','bubbles')){Hide-Bubble};if($room.open -and $Name -eq 'quiet' -and $state.quiet){Cancel-RoomActivity;Set-RoomMessage '安靜陪你，需要我時再點一下。'};Update-CharacterMenus;Save-Settings}
function Show-TimerSettings {
    Mark-Activity
    if($settingsWindow){[void]$settingsWindow.Activate();return}
    $script:settingsWindow=[System.Windows.Window]::new();$dialog=$settingsWindow
    $dialog.Title='咖凌 · 番茄鐘設定';$dialog.Width=330;$dialog.Height=290;$dialog.ResizeMode='NoResize';$dialog.WindowStartupLocation='CenterScreen';$dialog.Background='#FFF6FA'
    $stack=[System.Windows.Controls.StackPanel]::new();$stack.Margin=20;$dialog.Content=$stack;$script:durationBoxes=@{}
    foreach($entry in @(@('focusMinutes','專注（分鐘）'),@('shortMinutes','短休息（分鐘）'),@('longMinutes','長休息（分鐘）'))){
        $line=[System.Windows.Controls.DockPanel]::new();$line.Margin='0,0,0,10';$label=[System.Windows.Controls.TextBlock]::new();$label.Text=$entry[1];$label.Width=170
        $box=[System.Windows.Controls.TextBox]::new();$box.Text=[string]$state[$entry[0]];$box.Width=80
        [void]$line.Children.Add($label);[void]$line.Children.Add($box);[void]$stack.Children.Add($line);$durationBoxes[$entry[0]]=$box
    }
    $script:settingsMessage=[System.Windows.Controls.TextBlock]::new();$settingsMessage.Text='1–180 分鐘；進行中的這一輪不改變。';$settingsMessage.TextWrapping='Wrap';$settingsMessage.Margin='0,4,0,12';[void]$stack.Children.Add($settingsMessage)
    $save=[System.Windows.Controls.Button]::new();$save.Content='儲存';$save.Height=32
    $save.Add_Click({
        $values=@{};foreach($key in $durationBoxes.Keys){$number=0;if(-not [int]::TryParse($durationBoxes[$key].Text,[ref]$number) -or $number -lt 1 -or $number -gt 180){$settingsMessage.Text='請輸入 1–180 的整數分鐘。';return};$values[$key]=$number}
        foreach($key in $values.Keys){$state[$key]=$values[$key]}
        if($state.pomo.status -eq 'ready'){$state.pomo.remaining=Get-PhaseSeconds $state $state.pomo.phase}
        Save-Settings;Update-Badge;$settingsWindow.Close()
    });[void]$stack.Children.Add($save)
    $dialog.Add_Closed({$script:settingsWindow=$null});$dialog.Show();[void]$dialog.Activate()
}
function Close-Pet {if(-not $closing){$w.Close()}}
$script:menu=[System.Windows.Controls.ContextMenu]::new()
function Add-Menu([string]$Label,[scriptblock]$Action,$Parent=$menu) {
    $item=[System.Windows.Controls.MenuItem]::new();$item.Header=$Label;if($Action){$item.Add_Click($Action)};[void]$Parent.Items.Add($item);return $item
}
$null=Add-Menu '摸摸頭 ♥' {$null=Invoke-Interaction 'pet'}
$feed=Add-Menu '點心' $null
$null=Add-Menu '🍪 餅乾' {$null=Invoke-Interaction 'cookie'} $feed
$null=Add-Menu '🍮 布丁' {$null=Invoke-Interaction 'pudding'} $feed
$null=Add-Menu '🍵 茶' {$null=Invoke-Interaction 'tea'} $feed
$null=Add-Menu '打開生活小屋…' {Show-Room}
$null=Add-Menu '衣櫃…' {Show-Wardrobe}
$pomoMenu=Add-Menu '陪伴番茄鐘' $null
$null=Add-Menu '開始／繼續這一輪' {Start-Timer} $pomoMenu
$null=Add-Menu '暫停' {Pause-Timer} $pomoMenu
$null=Add-Menu '取消本輪' {Cancel-Timer} $pomoMenu
$null=Add-Menu '調整時間…' {Show-TimerSettings} $pomoMenu
$actions=Add-Menu '動作' $null
$null=Add-Menu '得意歪頭' {$null=Invoke-Interaction 'smug'} $actions
$null=Add-Menu '坐下晃腳' {$null=Invoke-Interaction 'sit'} $actions
$null=Add-Menu '抱膝打瞌睡' {$null=Invoke-Interaction 'sleep'} $actions
$null=Add-Menu '伸懶腰、揉眼睛' {$null=Invoke-Interaction 'stretch'} $actions
$null=Add-Menu '開心轉一圈' {$null=Invoke-Interaction 'spin'} $actions
$null=Add-Menu '躲貓貓、探頭' {$null=Invoke-Interaction 'peek'} $actions
$null=Add-Menu '揮手' {$null=Invoke-Interaction 'wave'} $actions
$null=Add-Menu '跳一下' {$null=Invoke-Interaction 'jump'} $actions
$null=Add-Menu '等你一下' {$null=Invoke-Interaction 'waiting'} $actions
$null=Add-Menu '認真思考' {$null=Invoke-Interaction 'thinking'} $actions
$null=Add-Menu '仔細檢查' {$null=Invoke-Interaction 'review'} $actions
$null=Add-Menu '有點失落' {$null=Invoke-Interaction 'sad'} $actions
$movement=Add-Menu '移動與尺寸' $null
$null=Add-Menu '留在原地' {Set-Mode 'stay'} $movement
$null=Add-Menu '自由散步' {Set-Mode 'wander'} $movement
$null=Add-Menu '跟著滑鼠' {Set-Mode 'follow'} $movement
$null=Add-Menu '小隻 · 100%' {Resize-Pet 1} $movement
$null=Add-Menu '標準 · 150%' {Resize-Pet 1.5} $movement
$null=Add-Menu '大隻 · 200%' {Resize-Pet 2} $movement
$script:lookItem=Add-Menu '看向滑鼠' {Toggle-Preference 'look' $lookItem}
$script:bubblesItem=Add-Menu '心情泡泡' {Toggle-Preference 'bubbles' $bubblesItem}
$script:storiesItem=Add-Menu '日常小劇場' {Toggle-Preference 'stories' $storiesItem}
$script:quietItem=Add-Menu '安靜陪伴' {Toggle-Preference 'quiet' $quietItem}
$script:autoHideItem=Add-Menu '全螢幕時自動隱藏' {Toggle-Preference 'autoHide' $autoHideItem}
foreach($pair in @(@($lookItem,'look'),@($bubblesItem,'bubbles'),@($storiesItem,'stories'),@($quietItem,'quiet'),@($autoHideItem,'autoHide'))){$pair[0].IsCheckable=$true;$pair[0].IsChecked=$state[$pair[1]]}
$script:throughItem=Add-Menu '滑鼠穿透 · Ctrl+Alt+K' {Toggle-Through};$throughItem.IsCheckable=$true;$throughItem.IsChecked=$state.clickThrough
$null=Add-Menu '隱藏 · Ctrl+Alt+H' {Toggle-Visibility}
$null=Add-Menu '打開動畫圖鑑' {Start-Process -FilePath (Join-Path $root 'preview.html')}
$null=Add-Menu '蓮的日常 · 60 秒新舊對照' {Start-Process -FilePath (Join-Path $root 'life-preview.html')}
$null=Add-Menu '關閉桌面寵物' {Close-Pet}
Initialize-CharacterMenu
$img.ContextMenu=$menu;$badge.ContextMenu=$menu
$script:tray=[System.Windows.Forms.NotifyIcon]::new();$tray.Icon=[System.Drawing.SystemIcons]::Information;$tray.Text=$character.displayName+' · 陪伴日常'
$script:trayMenu=[System.Windows.Forms.ContextMenuStrip]::new()
function Add-Tray([string]$Text,[scriptblock]$Action){$item=[System.Windows.Forms.ToolStripMenuItem]::new($Text);$item.Add_Click($Action);[void]$trayMenu.Items.Add($item);return $item}
$null=Add-Tray '顯示／隱藏 · Ctrl+Alt+H' {Toggle-Visibility}
$script:trayThrough=Add-Tray '開啟／關閉滑鼠穿透 · Ctrl+Alt+K' {Toggle-Through}
$null=Add-Tray '叫角色回來（重設顯示與位置）' {if($room.open){Close-Room};Mark-Activity;$script:manualHidden=$false;$state.autoHide=$false;$autoHideItem.IsChecked=$false;if($state.clickThrough){Toggle-Through};$script:fullscreenHidden=$false;Update-Visibility;$a=[System.Windows.SystemParameters]::WorkArea;$w.Left=$a.Right-$w.Width-24;$w.Top=$a.Bottom-$w.Height-16;Keep-Visible;Save-Settings}
$null=Add-Tray '開始／繼續番茄鐘' {Start-Timer}
$null=Add-Tray '打開／回到生活小屋' {Show-Room}
$null=Add-Tray '收合小屋，回桌面' {Close-Room}
$null=Add-Tray '衣櫃…' {Show-Wardrobe}
$null=Add-Tray '蓮的日常 · 60 秒新舊對照' {Start-Process -FilePath (Join-Path $root 'life-preview.html')}
$null=Add-Tray '暫停番茄鐘' {Pause-Timer}
$null=Add-Tray '取消本輪' {Cancel-Timer}
$null=Add-Tray '調整番茄鐘時間…' {Show-TimerSettings}
$null=Add-Tray '關閉桌面寵物' {Close-Pet}
Initialize-CharacterTray
Initialize-CareMenus
Initialize-PlayMenus
Initialize-WorldMenus
$tray.ContextMenuStrip=$trayMenu;$tray.Add_DoubleClick({$script:manualHidden=$false;Update-Visibility});$tray.Visible=$true
$img.Add_MouseLeftButtonDown({param($s,$e);Begin-Pointer (Cursor-Position) ($e.GetPosition($img).Y/$img.ActualHeight) ($e.ClickCount -eq 2);[void]$img.CaptureMouse();$e.Handled=$true})
$img.Add_MouseMove({if($drag){Move-Pointer (Cursor-Position)}})
$img.Add_MouseLeftButtonUp({param($s,$e);End-Pointer;$e.Handled=$true})
$img.Add_LostMouseCapture({$script:drag=$false})
[KalingNative]::OnHotkey=[Action[int]]{param($id);if($id -eq 1){Toggle-Through}elseif($id -eq 2){Toggle-Visibility}}
[KalingNative]::OnSuspend=[Action]{Pause-Timer}
$script:hook=[Delegate]::CreateDelegate([System.Windows.Interop.HwndSourceHook],[KalingNative].GetMethod('HandleMessage'))
$w.Add_SourceInitialized({
    $script:hwnd=([System.Windows.Interop.WindowInteropHelper]::new($w)).Handle
    $script:hwndSource=[System.Windows.Interop.HwndSource]::FromHwnd($hwnd);$hwndSource.AddHook($hook)
    [KalingNative]::ClickThrough($hwnd,$state.clickThrough)
    foreach($pair in @(@(1,0x4B),@(2,0x48))){if([KalingNative]::RegisterHotKey($hwnd,$pair[0],0x4003,$pair[1])){$script:hotkeys+=,$pair[0]}else{$script:hotkeyErrors+=([string]$pair[0]+':'+[Runtime.InteropServices.Marshal]::GetLastWin32Error())}}
})
Resize-Pet $state.scale
$w.Add_Loaded({
    if($script:loaded){return}
    $a=[System.Windows.SystemParameters]::WorkArea
    $w.Left=if($null -ne $state.left){$state.left}else{$a.Right-$w.Width-36}
    $w.Top=if($null -ne $state.top){$state.top}else{$a.Bottom-$w.Height-16}
    $script:loaded=$true;Keep-Visible;Set-Animation 3 1600;Update-Badge;$script:lastTick=$clock.ElapsedMilliseconds
    if($hotkeys.Count -lt 2){Show-Bubble '部分快捷鍵已被占用，請使用系統匣的咖凌選單。' -Important}else{Show-Bubble (Get-CharacterText 'hello' '你好！摸摸頭，或右鍵選一份點心吧。')}
    if($SelfTest){$timer.Stop();$null=$w.Dispatcher.BeginInvoke([Action]{try{. (Join-Path $root 'tests\Integration.ps1');Invoke-IntegrationTests}catch{$script:testFailed=$true;$_ | Out-String | Set-Content (Join-Path $dataDirectory 'test-failure.txt') -Encoding UTF8}finally{Close-Pet}})}
})
$script:timer=[System.Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(16)
$timer.Add_Tick({
    try {
        if(-not $loaded -or $closing){return}
        $now=$clock.ElapsedMilliseconds;$delta=($now-$lastTick)/1000.0;$script:lastTick=$now
        $event=Step-Pomodoro $state $delta;Handle-TimerEvent $event
        Update-Care $delta
        Update-Play $delta
        Update-World $delta
        if($peeking -and $now -ge $actionUntil){Exit-Peek}
        if($now -ge $nextPoll){
            $script:nextPoll=$now+500;$monitorHandle=if($worldWindow){$world.hwnd}elseif($room.open){$room.hwnd}else{$hwnd};$script:fullscreenHidden=$state.autoHide -and [KalingNative]::IsFullscreen([KalingNative]::GetForegroundWindow(),$monitorHandle)
            Update-Visibility;Update-Badge;if($room.open){Keep-RoomVisible}elseif(-not $drag){Keep-Visible}
        }
        if($now -ge $nextSave){Save-Settings;$script:nextSave=$now+10000}
        if($bubble.Visibility -eq 'Visible' -and $now -ge $bubbleUntil){Hide-Bubble}
        if($worldWindow){return}
        if($room.open){Update-Room $delta;return}
        if($pendingClick -and -not $drag -and $now -ge $pendingClick.due){$action=$pendingClick.action;$script:pendingClick=$null;$null=Invoke-Interaction $action}
        if($activity.kind -eq 'attack'){Step-Attack $now;return}
        if(-not $w.IsVisible -or $menu.IsOpen -or $trayMenu.Visible){return}
        $focus=$state.pomo.status -eq 'running'
        if(-not $drag -and $now -gt $actionUntil){
            if(($state.character -ne 'ren' -or -not $lifeArtworkEnabled) -and $state.stories -and -not $state.quiet -and -not $focus -and $resting -ne 'sleeping' -and -not $settingsWindow -and -not $wardrobeWindow -and $now -ge $nextStory){
                $story=Get-Story (Get-Date).Hour $state.mood;if($character.stories){$story.text=Get-Random -InputObject @($character.stories)};$state.mood=$story.mood;Set-Animation $story.row 2200;Show-Bubble $story.text;$script:nextStory=$now+(Get-Random -Minimum 480000 -Maximum 900001)
            }else{
                $p=Cursor-Position;$dx=$p.X-($w.Left+$w.Width/2);$dy=$p.Y-($w.Top+88+($w.Height-120)*0.37);$moving=$false
                $canRest=-not $focus -and -not $state.quiet -and $state.stories -and -not $settingsWindow -and -not $wardrobeWindow
                if($canRest -and $resting -eq 'none' -and $now-$lastInteraction -gt 120000){$script:resting='sitting'}
                if($canRest -and $now-$lastInteraction -gt 300000 -and $resting -ne 'sleeping'){$script:resting='sleeping';Set-Animation 16 2600}
                if(-not $focus -and -not $state.quiet -and $resting -eq 'none' -and (-not $state.care.enabled -or ((Get-ActiveCare).urge -lt 0 -and (Test-CarePlay (Get-ActiveCare))))){
                    if($state.mode -eq 'follow' -and [math]::Abs($dx) -gt $w.Width*0.7){$script:direction=[math]::Sign($dx);$w.Left+=$direction*75.76*[math]::Min(.1,[math]::Max(0,$delta));$moving=$true}
                    elseif($state.mode -eq 'wander'){
                        if($now -gt $nextWalk){$script:direction=if((Get-Random -Maximum 2) -eq 0){-1}else{1};$script:nextWalk=$now+6000;$script:walkEnd=$now+1600}
                        if($now -lt $walkEnd){$w.Left+=$direction*54.55*[math]::Min(.1,[math]::Max(0,$delta));$moving=$true}
                    }
                }
                if($moving){Keep-Visible;$r=if($direction -lt 0){2}else{1};if($row -ne $r){Set-Animation $r 0}}
                elseif(($state.character -ne 'ren' -or -not $lifeArtworkEnabled) -and $state.look -and -not $focus -and -not $state.quiet -and $resting -eq 'none' -and [math]::Sqrt($dx*$dx+$dy*$dy) -gt 70 -and [math]::Sqrt($dx*$dx+$dy*$dy) -lt 750){
                    $angle=([math]::Atan2($dx,-$dy)*180/[math]::PI+360)%360;$d=[int][math]::Floor(($angle+11.25)/22.5)%16;$img.Source=$frames["$(9+[math]::Floor($d/8)),$($d%8)"];return
                }else{$r=if($focus -and $state.pomo.phase -eq 'focus'){8}elseif($resting -eq 'sleeping'){16}elseif($resting -eq 'sitting'){15}else{0};if($row -ne $r){Set-Animation $r 0}}
            }
        }
        if($now-$nextFrame -gt 1000){$script:nextFrame=$now}
        while($now -ge $nextFrame){$script:frame=if($row -eq 16){[math]::Min($frame+1,$counts[$row]-1)}else{($frame+1)%$counts[$row]};$img.Source=$frames["$row,$frame"];$script:nextFrame+=$durations[$row][$frame]}
    }catch{$_ | Out-String | Add-Content -LiteralPath $log -Encoding UTF8;Close-Pet}finally{if(-not $closing){try{Update-CareVisual;Update-LifeVisual}catch{$_ | Out-String | Add-Content -LiteralPath $log -Encoding UTF8;Close-Pet}}}
})
$w.Add_Closing({$script:closing=$true;Close-World;Close-Play;Close-CareWindows;Stop-Activity;if($fxWindow){$fxWindow.Close();$script:fxWindow=$null};Pause-Pomodoro $state;Save-Settings})
$w.Add_Closed({
    $timer.Stop();if($room.open){Close-Room};if($settingsWindow){$settingsWindow.Close()};if($wardrobeWindow){$wardrobeWindow.Close()}
    foreach($id in $hotkeys){[void][KalingNative]::UnregisterHotKey($hwnd,$id)}
    if($hwndSource){$hwndSource.RemoveHook($hook)}
    $tray.Visible=$false;$tray.Dispose();$trayMenu.Dispose();$mutex.ReleaseMutex();$mutex.Dispose();$app.Shutdown()
})
$timer.Start();[void]$app.Run($w)
if($testFailed){exit 1}
