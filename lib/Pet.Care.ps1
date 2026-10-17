# WPF presentation for the pure care model. A single task owns any care performance.
$script:careTask=$null;$script:careWindows=@{};$script:careRoomVisuals=@{};$script:careArtCache=@{};$script:careNotice=0.0;$script:careVisualTime=0.0
function Get-ActiveCare {return $state.care.characters[$state.character]}
function Test-CarePaused {return -not $state.care.enabled -or $closing -or $manualHidden -or $fullscreenHidden -or $state.quiet -or $state.pomo.status -eq 'running' -or $null -ne $playWindow}
function Get-CareText([string]$Key) {
    if($character.careDialogue.$Key){return [string]$character.careDialogue.$Key}
    $words=@{
        urge=@('……稍等。帶我回小屋。','等一下！快帶我回小屋！');accident=@('……別看。我來守著。','不是我……好啦，是我。');toilet=@('借過。很快回來。','廁所廁所，我來了！');done=@('記住了。謝謝。','成功了！下次我也會記得！');bath=@('洗去風塵。稍等。','泡泡好多，洗香香！');clean=@('乾淨了。謝謝。','亮晶晶！謝謝你幫忙。');full=@('吃飽了。留著晚點吧。','肚子裝不下啦，晚點再吃！');hungry=@('想吃點東西。','肚子咕嚕咕嚕了……');tired=@('歇一會。','眼皮要合起來了……');dirty=@('該清理一下了。','想洗香香，再陪你玩！');limit=@('先清理地面吧。','地板滿了，幫我清一下嘛！');disabled=@('先陪你待著。','先乖乖陪你！')
    };$i=if($state.character -eq 'ren'){0}else{1};return [string]$words[$Key][$i]
}
function Get-CareStatus {
    $c=Get-ActiveCare
    if(-not $state.care.enabled){return '電子雞生活已暫停 · 右鍵可開啟'}
    $pause=if(Test-CarePaused){' · 暫停中'}else{''}
    $need=if($c.urge -ge 0){' · 想上廁所！點泡泡或右鍵帶回小屋'}else{''}
    return ('飽足 {0:0} · 精神 {1:0} · 清潔 {2:0} · 心情 {3:0}{4}{5}' -f $c.satiety,$c.energy,$c.hygiene,$c.happiness,$pause,$need)+"`n如廁熟練 $($c.training)% · 地面便便 $($c.messes.Count)/3"
}
function Get-CareArt([string]$Name,[int]$Frame=-1) {
    $key=if($Name -eq 'reaction'){$state.character+'/'+$state.outfit+'/'+$Frame}else{$Name+'/'+$Frame};if($careArtCache.ContainsKey($key)){return $careArtCache[$key]}
    $manifest=Get-Content (Join-Path $root 'assets/care/catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if($Name -eq 'reaction'){$entry=$manifest.characters.($state.character).($state.outfit);$key=$state.character+'/'+$state.outfit+'/'+$Frame;if($careArtCache.ContainsKey($key)){return $careArtCache[$key]};$rect=$entry.rects[$Frame]}
    else{$entry=$manifest.props.$Name;$rect=$entry.rect}
    if(-not $entry){throw "Missing care art: $Name"}
    if($entry.outfitFrames){return $frames["$([int]($rect[1]/208)),$([int]($rect[0]/192))"]}
    $baseKey='source/'+$entry.file
    if(-not $careArtCache.ContainsKey($baseKey)){$b=[System.Windows.Media.Imaging.BitmapImage]::new();$b.BeginInit();$b.CacheOption='OnLoad';$b.UriSource=[Uri](Join-Path $root $entry.file);$b.EndInit();$b.Freeze();$careArtCache[$baseKey]=$b}else{$b=$careArtCache[$baseKey]}
    $crop=[System.Windows.Media.Imaging.CroppedBitmap]::new($b,[System.Windows.Int32Rect]::new($rect[0],$rect[1],$rect[2],$rect[3]));$crop.Freeze();$careArtCache[$key]=$crop;return $crop
}
function Cancel-CareActivity {
    $old=$script:careTask;$script:careTask=$null
    if($old -and $room.open -and ($room.task -in @('toilet','bath') -or $room.phase -like 'care-*')){
        $room.phase='idle';$room.task='';$room.path=@();$room.pose=$null;$room.transition=$null;$script:row=0;$script:frame=0;$script:actionUntil=0
    }
    if($img){$img.RenderTransform=[System.Windows.Media.Transform]::Identity}
}
function Test-CareFoodAllowed([string]$Food) {
    if($state.care.enabled -and -not (Test-CareFeed (Get-ActiveCare) $Food)){Show-Bubble (Get-CareText 'full');return $false};return $true
}
function Begin-CareMeal([string]$Food,[string]$Place,[double]$Seconds) {
    if($state.care.enabled){$script:careTask=@{kind='food';food=$Food;place=$Place;remaining=$Seconds;character=$state.character}}
}
function Complete-PendingCareMeal {
    if($careTask -and $careTask.kind -eq 'food' -and $careTask.character -eq $state.character){$food=$careTask.food;$script:careTask=$null;$null=Complete-CareMeal (Get-ActiveCare) $food (Get-Random -Minimum 480 -Maximum 721);Add-PlayEvent (Get-PlayCare) ('meal-'+$food) ('慢慢享用了一份'+@{cookie='餅乾';pudding='布丁';tea='茶'}[$food]+'。');Notify-Life 'snack';Save-Settings}
}
function Add-CareHappiness([double]$Amount=4) {if($state.care.enabled){$c=Get-ActiveCare;$c.happiness=[math]::Min(100.0,$c.happiness+$Amount)}}
function Request-CareAction([string]$Action,[switch]$Automatic) {
    if(-not $state.care.enabled){Show-Bubble (Get-CareText 'disabled');return $false}
    if(Test-CarePaused){Show-Bubble '電子雞生活暫停中，結束專注或安靜陪伴後再照顧。' -Important;return $false}
    if($drag -or $room.drag -or $wardrobeWindow -or $settingsWindow){return $false}
    if($Action -eq 'toilet' -and (Get-ActiveCare).urge -lt 0){Show-Bubble '現在還不用上廁所。';return $false}
    $returnToDesktop=-not $room.open
    if(-not $room.open){Show-Room -Passive:$Automatic}
    Request-RoomAction $Action -Automatic:$Automatic
    if($room.phase -ne 'walking' -or $room.task -ne $Action){return $false}
    $script:careTask=@{kind=$Action;place='room';character=$state.character;guided=(-not $Automatic);returnDesktop=$returnToDesktop}
    Set-RoomMessage (Get-CareText $Action);return $true
}
function Complete-CareRoomAction {
    if(-not $careTask -or $careTask.character -ne $state.character){Cancel-RoomActivity;return}
    $task=$careTask;$script:careTask=$null;$c=Get-ActiveCare
    if($task.kind -eq 'toilet'){$null=Complete-CareToilet $c $task.guided;Show-Bubble (Get-CareText 'done')}
    elseif($task.kind -eq 'bath'){$c.hygiene=100.0;$c.happiness=[math]::Min(100.0,$c.happiness+12);Show-Bubble (Get-CareText 'clean')}
    Add-PlayEvent (Get-PlayCare) $task.kind $(if($task.kind -eq 'bath'){'洗了泡泡澡，香香地回來了。'}else{'順利找到廁所，記住今天的小進步。'})
    Cancel-RoomActivity
    if($task.returnDesktop){Close-Room}
    $script:careTask=@{kind='relief';place=$(if($room.open){'room'}else{'desktop'});remaining=2.4;character=$state.character}
    if($room.open){$room.phase='care-relief';$room.until=$room.time+2.4}else{Set-Animation 11 2400}
    Show-Bubble (Get-CareText $(if($task.kind -eq 'toilet'){'done'}else{'clean'}));Save-Settings
}
function Start-CareAccident {
    if($room.open){Cancel-RoomActivity};Mark-Activity
    $script:careTask=@{kind='accident';place=$(if($room.open){'room'}else{'desktop'});remaining=2.4;character=$state.character}
    if($room.open){$room.phase='care-accident';$room.until=[double]::MaxValue}
    Set-Animation 6 2400;Show-Bubble (Get-CareText 'urge')
}
function Complete-CareAccident {
    $c=Get-ActiveCare;$mess=@{id=[guid]::NewGuid().ToString('N')}
    if($room.open){$mess.place='room';$mess.u=$room.u;$mess.v=$room.v;if(-not (Test-RoomFloor $mess.u $mess.v)){$mess.u=.45;$mess.v=.45}}
    else{$mess.place='desktop';$mess.x=$w.Left+$w.Width*.55;$mess.y=$w.Top+$w.Height-60}
    $null=Complete-CareToilet $c $false $mess;$script:careTask=$null
    if($room.open){Cancel-RoomActivity;$room.phase='care-relief';$room.until=$room.time+2.4}
    $script:careTask=@{kind='relief';place=$(if($room.open){'room'}else{'desktop'});remaining=2.4;character=$state.character}
    Set-Animation 11 2400;Show-Bubble (Get-CareText 'accident');Save-Settings;Sync-CareMesses
}
function Remove-CareMess([string]$Id,[switch]$All) {
    $c=Get-ActiveCare;$removed=@($c.messes | Where-Object {$All -or $_.id -eq $Id})
    if(-not $removed.Count){return}
    foreach($m in $removed){Show-CareCleanEffect $m}
    $c.messes=@($c.messes | Where-Object {-not ($All -or $_.id -eq $Id)})
    $c.hygiene=[math]::Min(100.0,$c.hygiene+4*$removed.Count);Add-CareHappiness 3;Show-Bubble (Get-CareText 'clean');Save-Settings;Sync-CareMesses
}
function Limit-CareMess($Mess,$Window) {
    $source=[System.Windows.PresentationSource]::FromVisual($w);$to=$source.CompositionTarget.TransformToDevice;$from=$source.CompositionTarget.TransformFromDevice
    $physical=$to.Transform([System.Windows.Point]::new($Mess.x,$Mess.y));$a=[System.Windows.Forms.Screen]::FromPoint([System.Drawing.Point]::new([int]$physical.X,[int]$physical.Y)).WorkingArea
    $p=$from.Transform([System.Windows.Point]::new($a.Left,$a.Top));$q=$from.Transform([System.Windows.Point]::new($a.Right,$a.Bottom))
    $pos=Limit-PetPosition $Mess.x $Mess.y $Window.Width $Window.Height @{Left=$p.X;Top=$p.Y;Right=$q.X;Bottom=$q.Y};$Mess.x=$pos.left;$Mess.y=$pos.top;$Window.Left=$pos.left;$Window.Top=$pos.top
}
function New-CareWindow($Mess,[bool]$Effect=$false) {
    $win=[System.Windows.Window]::new();$win.WindowStyle='None';$win.ResizeMode='NoResize';$win.AllowsTransparency=$true;$win.Background=[System.Windows.Media.Brushes]::Transparent;$win.ShowInTaskbar=$false;$win.ShowActivated=$false;$win.Topmost=$true;$win.Width=40*$state.scale;$win.Height=40*$state.scale;$win.Title='電子雞 · '+$(if($Effect){'清潔泡泡'}else{'便便'})
    $picture=[System.Windows.Controls.Image]::new();$picture.Source=Get-CareArt $(if($Effect){'bubbles'}else{'poop'});$picture.Stretch='Uniform';$picture.Cursor='Hand';$picture.Tag=$Mess.id;$win.Content=$picture
    if(-not $Effect){$picture.ToolTip='點一下清理 · 也可從系統匣全部清理';$picture.Add_MouseLeftButtonDown({param($s,$e);$e.Handled=$true;Remove-CareMess ([string]$s.Tag)})}
    $win.Add_SourceInitialized({param($s,$e);$handle=([System.Windows.Interop.WindowInteropHelper]::new($s)).Handle;[KalingNative]::ClickThrough($handle,($state.clickThrough -or $s.Tag -eq 'effect'))})
    if($Effect){$win.Tag='effect'};Limit-CareMess $Mess $win;return $win
}
function Close-CareWindows {
    foreach($win in @($careWindows.Values)){$win.Close()};$script:careWindows=@{}
    foreach($fx in @($script:careEffects)){if($fx.window){$fx.window.Close()};if($fx.visual){$fx.canvas.Children.Remove($fx.visual)}};$script:careEffects=@()
}
$script:careEffects=@()
function Show-CareCleanEffect($Mess) {
    if($manualHidden -or $fullscreenHidden -or -not $state.care.enabled){return}
    if($Mess.place -eq 'desktop'){$win=New-CareWindow $Mess $true;$win.Show();$script:careEffects+=@{window=$win;left=.65}}
    elseif($room.open){$im=[System.Windows.Controls.Image]::new();$im.Source=Get-CareArt 'bubbles';$im.Width=60;$im.Height=60;$im.IsHitTestVisible=$false;$p=Get-RoomPoint $Mess.u $Mess.v;Place-RoomVisual $im ($p.x-30) ($p.y-55) 1000;[void]$room.canvas.Children.Add($im);$script:careEffects+=@{visual=$im;canvas=$room.canvas;left=.65}}
}
function Sync-CareMesses {
    if(-not $loaded){return};$c=Get-ActiveCare;$visible=$state.care.enabled -and -not $manualHidden -and -not $fullscreenHidden -and -not $closing -and $null -eq $playWindow
    if(-not $visible -and $careEffects.Count){foreach($fx in @($careEffects)){if($fx.window){$fx.window.Close()};if($fx.visual){$fx.canvas.Children.Remove($fx.visual)}};$script:careEffects=@()}
    $desktop=@{};if($visible){foreach($m in $c.messes){if($m.place -eq 'desktop'){$desktop[$m.id]=$m}}}
    foreach($id in @($careWindows.Keys)){if(-not $desktop.ContainsKey($id)){$careWindows[$id].Close();$careWindows.Remove($id)}}
    foreach($id in $desktop.Keys){$m=$desktop[$id];if(-not $careWindows.ContainsKey($id)){$careWindows[$id]=New-CareWindow $m;$careWindows[$id].Show()};$win=$careWindows[$id];$win.Width=40*$state.scale;$win.Height=40*$state.scale;Limit-CareMess $m $win;[KalingNative]::ClickThrough(([System.Windows.Interop.WindowInteropHelper]::new($win)).Handle,$state.clickThrough)}
    if($room.open){
        foreach($id in @($careRoomVisuals.Keys)){if($careRoomVisuals[$id].Parent -ne $room.canvas -or -not $visible -or $id -notin @($c.messes.id)){$old=$careRoomVisuals[$id];if($old.Parent){$old.Parent.Children.Remove($old)};$careRoomVisuals.Remove($id)}}
        if($visible){foreach($m in $c.messes){if($m.place -ne 'room'){continue};if(-not $careRoomVisuals.ContainsKey($m.id)){$im=[System.Windows.Controls.Image]::new();$im.Source=Get-CareArt 'poop';$im.Width=34;$im.Height=34;$im.Tag=$m.id;$im.Cursor='Hand';$im.ToolTip='點一下清理';$im.Add_MouseLeftButtonDown({param($s,$e);$e.Handled=$true;Remove-CareMess ([string]$s.Tag)});[void]$room.canvas.Children.Add($im);$careRoomVisuals[$m.id]=$im};$p=Get-RoomPoint $m.u $m.v;Place-RoomVisual $careRoomVisuals[$m.id] ($p.x-17) ($p.y-27) ([int]$p.y)}}
    }else{$script:careRoomVisuals=@{}}
}
function Update-CareVisual {
    if(-not $loaded){return};$c=Get-ActiveCare
    $img.ToolTip=Get-CareStatus;if($room.open){$room.actor.ToolTip=Get-CareStatus}
    $bubble.IsHitTestVisible=$state.care.enabled -and $c.urge -ge 0;$bubble.Cursor='Hand'
    $kind=if($careTask){$careTask.kind}else{''}
    if($activity.kind -ne 'attack'){$img.RenderTransform=[System.Windows.Media.Transform]::Identity};if($room.open){$room.actor.RenderTransform=[System.Windows.Media.Transform]::Identity}
    if($kind -in @('accident','relief')){
        $f=([int][math]::Floor($careVisualTime/.22))%4;if($kind -eq 'relief'){$f+=4};$art=Get-CareArt 'reaction' $f
        if($room.open){$room.actor.Source=$art}else{$img.Source=$art}
    }elseif($state.care.enabled -and $c.urge -ge 0 -and -not (Test-CarePaused) -and -not $careTask -and $activity.kind -ne 'attack' -and -not $drag -and $clock.ElapsedMilliseconds -gt $actionUntil -and (-not $room.open -or $room.phase -eq 'idle')){
        $art=Get-CareArt 'reaction' (([int][math]::Floor($careVisualTime/.3))%4);if($room.open){$room.actor.Source=$art}else{$img.Source=$art}
    }
    if($state.care.enabled -and -not (Test-CarePaused) -and ($kind -in @('accident','relief') -or ($c.urge -ge 0 -and -not $careTask -and $activity.kind -ne 'attack' -and -not $drag -and (-not $room.open -or $room.phase -eq 'idle')))){
        $actor=if($room.open){$room.actor}else{$img};$actor.RenderTransformOrigin=[System.Windows.Point]::new(.5,1)
        $motion=[System.Windows.Media.TransformGroup]::new();$motion.Children.Add([System.Windows.Media.RotateTransform]::new([math]::Sin($careVisualTime*5)*1.8));$motion.Children.Add([System.Windows.Media.TranslateTransform]::new(0,-[math]::Abs([math]::Sin($careVisualTime*3))*1.5));$actor.RenderTransform=$motion
    }
    if($room.open){
        $room.careScreen.Visibility=if($room.phase -eq 'care-toilet'){'Visible'}else{'Hidden'}
        $room.careFoam.Visibility=if($room.phase -eq 'care-bath'){'Visible'}else{'Hidden'}
        if($room.phase -eq 'care-toilet'){$room.actor.Visibility='Hidden'}
        if($room.phase -eq 'care-bath'){$room.actor.Clip=[System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0,0,144,(Get-RoomClipHeight 110)));$room.careFoam.Opacity=1.0}
    }
}
function Update-Care([double]$Delta) {
    $safe=if($Delta -gt 0 -and $Delta -le 5){$Delta}else{0};$careVisualTime+=$safe;$script:careVisualTime=$careVisualTime
    foreach($fx in @($careEffects)){$fx.left-=$safe;if($fx.window){$fx.window.Opacity=[math]::Max(0.0,$fx.left/.65)};if($fx.left -le 0){if($fx.window){$fx.window.Close()};if($fx.visual){$fx.canvas.Children.Remove($fx.visual)}}};$script:careEffects=@($careEffects | Where-Object {$_.left -gt 0})
    $paused=Test-CarePaused;$c=Get-ActiveCare;$sleeping=$resting -eq 'sleeping' -or ($room.open -and $room.phase -eq 'bed-sleep')
    $busy=$drag -or $room.drag -or $wardrobeWindow -or $settingsWindow -or $menu.IsOpen -or $trayMenu.Visible -or ($room.open -and $room.foodMenu.IsOpen)
    # Pause the urge countdown during a committed trip to the toilet, never the rest of digestion.
    $heldUrge=$c.urge;$event=Step-CareModel $c $safe ($paused -or $busy) $sleeping
    if($careTask -and $careTask.kind -eq 'toilet'){$c.urge=$heldUrge}
    if($paused -or $busy){return}
    if($careTask -and $careTask.ContainsKey('remaining')){
        $careTask.remaining-=$safe
        if($careTask.remaining -le 0){switch($careTask.kind){'food'{Complete-PendingCareMeal};'accident'{Complete-CareAccident};'relief'{$script:careTask=$null;if($room.open -and $room.phase -eq 'care-relief'){Cancel-RoomActivity}}}}
    }
    $idle=-not $careTask -and $activity.kind -ne 'attack' -and (($room.open -and $room.phase -in @('idle','bed-sleep','sofa-nap')) -or (-not $room.open -and $clock.ElapsedMilliseconds -gt $actionUntil))
    if($idle -and $c.urge -ge 0){
        if(-not $c.autoTried){$c.autoTried=$true;Show-Bubble (Get-CareText 'urge') -Important;if((Get-Random -Minimum 0 -Maximum 100) -lt $c.training){$null=Request-CareAction 'toilet' -Automatic;return}}
        if($c.urge -eq 0 -and $c.messes.Count -lt 3){Start-CareAccident;return}
    }
    $script:careNotice-=$safe
    if($idle -and $careNotice -le 0){$key=if($c.messes.Count -ge 3){'limit'}elseif($c.hygiene -lt 25){'dirty'}elseif($c.satiety -lt 20){'hungry'}elseif($c.energy -lt 15 -and -not $sleeping){'tired'}else{''};if($key){Show-Bubble (Get-CareText $key);if(-not $room.open -and -not $sleeping){Set-Animation $(if($key -eq 'tired'){16}else{5}) 2200}};$script:careNotice=120.0}
}
function Toggle-Care {
    Cancel-CareActivity;if($room.open){Cancel-RoomActivity};$state.care.enabled=-not $state.care.enabled;Hide-Bubble;Set-Animation 0 0;Sync-CareMesses;Update-CareMenus;Save-Settings
}
function Update-CareMenus {
    if($script:careStatusItem){$careStatusItem.Header=Get-CareStatus;$careEnabledItem.IsChecked=$state.care.enabled;$careToiletItem.IsEnabled=$state.care.enabled -and (Get-ActiveCare).urge -ge 0 -and -not (Test-CarePaused);$careBathItem.IsEnabled=$state.care.enabled -and -not (Test-CarePaused)}
    if($script:trayCareStatus){$trayCareStatus.Text=Get-CareStatus;$trayCareEnabled.Checked=$state.care.enabled;$trayCareToilet.Enabled=$careToiletItem.IsEnabled;$trayCareBath.Enabled=$careBathItem.IsEnabled}
}
function Initialize-CareMenus {
    $group=Add-Menu '電子雞生活' $null
    $script:careStatusItem=Add-Menu '' $null $group;$careStatusItem.IsEnabled=$false
    $script:careToiletItem=Add-Menu '帶回小屋上廁所' {$null=Request-CareAction 'toilet'} $group
    $script:careBathItem=Add-Menu '回小屋洗澡' {$null=Request-CareAction 'bath'} $group
    $null=Add-Menu '全部清理' {Remove-CareMess '' -All} $group
    $script:careEnabledItem=Add-Menu '啟用電子雞生活' {Toggle-Care} $group;$careEnabledItem.IsCheckable=$true
    $script:trayCareStatus=Add-Tray '' {}; $trayCareStatus.Enabled=$false
    $script:trayCareToilet=Add-Tray '帶回小屋上廁所' {$null=Request-CareAction 'toilet'}
    $script:trayCareBath=Add-Tray '回小屋洗澡' {$null=Request-CareAction 'bath'}
    $null=Add-Tray '全部清理便便' {Remove-CareMess '' -All}
    $script:trayCareEnabled=Add-Tray '啟用電子雞生活' {Toggle-Care};Update-CareMenus
    $menu.Add_Opened({Update-CareMenus});$trayMenu.Add_Opening({Update-CareMenus})
    $bubble.Add_MouseLeftButtonDown({param($s,$e);if((Get-ActiveCare).urge -ge 0){$e.Handled=$true;$null=Request-CareAction 'toilet'}})
}
