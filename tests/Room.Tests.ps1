# Runs inside the real WPF integration session with isolated settings.
function Advance-Room([double]$Seconds){for($i=0;$i -lt [math]::Ceiling($Seconds*10);$i++){Update-Room .1};Pump}
function Await-RoomPhase([string]$Phase){for($i=0;$i -lt 250 -and $room.phase -ne $Phase;$i++){Update-Room .1};Check ($room.phase -eq $Phase) "$($state.outfit) reaches $Phase (actual=$($room.phase), step=$($room.step)/$($room.path.Count), time=$($room.time), visible=$($room.window.IsVisible), wardrobe=$($null -ne $wardrobeWindow), menu=$($menu.IsOpen), settings=$($null -ne $settingsWindow), foodMenu=$($room.foodMenu.IsOpen))";Pump}
function Capture-Room([string]$Name){
    Render-Room;$room.window.UpdateLayout();Pump
    $render=[System.Windows.Media.Imaging.RenderTargetBitmap]::new(900,650,96,96,[System.Windows.Media.PixelFormats]::Pbgra32);$render.Render($room.canvas)
    $encoder=[System.Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($render))
    $stream=[IO.File]::Create((Join-Path $dataDirectory $Name));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
Reset-Pomodoro $state;$state.stories=$false;$state.quiet=$false;$script:fullscreenHidden=$false;$script:manualHidden=$false
$desktop=@{left=$w.Left;top=$w.Top;mode=$state.mode};Show-Room;Pump
Check ($room.open -and $room.window.IsVisible -and -not $w.IsVisible) 'room replaces desktop actor'
Capture-Room 'room-overview.png'
foreach($outfit in @('uniform','pajamas','hoodie')){
    Select-Outfit $outfit
    foreach($action in @('cookie','pudding','tea')){
        Request-RoomAction $action;Await-RoomPhase 'food'
        Check ($row -eq @{cookie=12;pudding=13;tea=14}[$action] -and [object]::ReferenceEquals($room.actor.Source,$frames["$row,$frame"])) "$outfit $action uses selected outfit"
        Capture-Room ("room-$outfit-$action.png");Advance-Room 6
    }
    Request-RoomAction 'sofa';Await-RoomPhase 'sofa';Check ($row -eq 22 -and $room.pose.z -gt 425) "$outfit pillow sits in front of sofa"
    Capture-Room ("room-$outfit-sofa.png");Await-RoomPhase 'sofa-nap';Advance-Room 5
    Request-RoomAction 'bed';Await-RoomPhase 'bed-sit';Await-RoomPhase 'bed-tuck';Await-RoomPhase 'bed-sleep'
    Check ($frame -eq 3 -and $row -eq 23 -and $room.bedFront.Visibility -eq 'Visible' -and $room.pose.z -gt 450 -and $room.pose.z -lt 460) "$outfit sleeping under quilt"
    Capture-Room ("room-$outfit-bed.png");Advance-Room 3;Check ($frame -eq 3) "$outfit sleep holds closed eyes"
    Request-RoomAction 'wake';Check ($room.phase -eq 'waking' -and $room.pose) "$outfit peeks before getting up";Await-RoomPhase 'stretch';Check ($row -eq 17 -and -not $room.pose) "$outfit wake rubs eyes";Advance-Room 3
    Request-RoomAction 'box';Await-RoomPhase 'box-enter';Capture-Room ("room-$outfit-box.png");Await-RoomPhase 'box-hide'
    Check ($room.actor.Visibility -eq 'Hidden') "$outfit hides inside box";Await-RoomPhase 'box-peek';Check ($room.actor.Visibility -eq 'Visible') "$outfit pops back out";Advance-Room 4
    Request-RoomAction 'ball';Await-RoomPhase 'ball-tap';Check ($row -eq 24) "$outfit taps ball";Capture-Room ("room-$outfit-ball.png");Advance-Room 1.3
    Check ($row -eq 21 -and $room.roll) "$outfit tap rolls ball and shows smug reaction";Advance-Room 3
    Check (Test-RoomDrop 'ball' $state.home.ball.u $state.home.ball.v $state.home) "$outfit rolling ball remains on floor"
    Check (-not $w.IsVisible -and $room.window.IsVisible -and $state.outfit -eq $outfit) "$outfit never duplicates character or changes clothing"
}
Request-RoomAction 'wardrobe';for($i=0;$i -lt 200 -and -not $wardrobeWindow;$i++){Update-Room .1};Pump
Check ($null -ne $wardrobeWindow) 'room wardrobe opens existing outfit UI'
$wardrobeButtons.pajamas.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent));Pump
Check ($state.outfit -eq 'pajamas' -and -not $w.IsVisible -and $room.open) 'room wardrobe change stays in room';$wardrobeWindow.Close()
Request-RoomAction 'bed';Select-Outfit 'uniform';Check ($room.phase -eq 'reaction' -and $room.path.Count -eq 0) 'changing outfit interrupts walk safely'
Request-RoomAction 'ball';Start-Timer;Advance-Room 2
Check (-not $room.roll -and $room.path.Count -eq 0 -and $state.pomo.status -eq 'running') 'focus cancels toy chase'
Request-RoomAction 'ball';Check ($room.phase -ne 'walking') 'focus refuses ball chase'
$state.stories=$true;$room.nextAuto=0;Advance-Room 65;Check ($room.phase -eq 'idle') 'focus suppresses autonomous house activity'
Pause-Timer;$state.quiet=$true;$room.nextAuto=0;Advance-Room 65;Check ($room.phase -eq 'idle') 'quiet mode suppresses autonomous house activity'
$state.quiet=$false;$state.stories=$false
Cancel-RoomActivity;$before=@{u=$state.home.box.u;v=$state.home.box.v};$p=Get-RoomPoint $before.u $before.v
Begin-RoomToy 'box' ([System.Windows.Point]::new($p.x,$p.y));Move-RoomToy ([System.Windows.Point]::new(-500,-500));Advance-Room 4
Check ($room.phase -eq 'idle' -and $room.drag) 'drag pauses character activity';End-RoomToy
Check ($state.home.box.u -eq $before.u -and $state.home.box.v -eq $before.v) 'invalid drop returns toy to original position'
$target=Get-RoomPoint .47 .33
Begin-RoomToy 'box' ([System.Windows.Point]::new($p.x,$p.y));Move-RoomToy ([System.Windows.Point]::new($target.x,$target.y));End-RoomToy
Check ([math]::Abs($state.home.box.u-.47) -lt .001 -and [math]::Abs((Read-PetState $dataDirectory).home.box.v-.33) -lt .001) 'valid toy drop persists and responds after release'
Cancel-RoomActivity;$room.roll=@{du=3.0;dv=3.0;remaining=3.0;chase=$false};Advance-Room 4
Check (Test-RoomDrop 'ball' $state.home.ball.u $state.home.ball.v $state.home) 'ball stops at room boundary'
Request-RoomAction 'sofa';$savedTime=$room.time;$script:manualHidden=$true;Update-Visibility;Advance-Room 2
Check (-not $w.IsVisible -and -not $room.window.IsVisible -and $room.time -eq $savedTime) 'manual hide pauses room without revealing desktop'
$script:manualHidden=$false;Update-Visibility;$script:fullscreenHidden=$true;Update-Visibility
Check (-not $room.window.IsVisible -and -not $w.IsVisible) 'fullscreen result hides room and desktop together'
$script:fullscreenHidden=$false;Update-Visibility;Check ($room.window.IsVisible -and -not $w.IsVisible) 'leaving fullscreen restores only room'
foreach($phase in @('walking','bed-sleep','rolling','dragging')){
    Cancel-RoomActivity
    switch($phase){'walking'{Request-RoomAction 'bed'};'bed-sleep'{Request-RoomAction 'bed';Await-RoomPhase 'bed-sleep'};'rolling'{$room.roll=@{du=.2;dv=.1;remaining=2;chase=$true}};'dragging'{Begin-RoomToy 'box' ([System.Windows.Point]::new(300,300))}}
    if($phase -in @('rolling','dragging')){$room.window.Close()}else{Close-Room};Pump
    Check (-not $room.open -and -not $room.drag -and -not $room.roll -and $w.IsVisible -and $w.Left -eq $desktop.left -and $w.Top -eq $desktop.top -and $state.mode -eq $desktop.mode) "collapse during $phase returns original desktop state"
    Show-Room;Pump
}
foreach($phase in @('walking','bed-sleep','rolling','dragging')){
    Cancel-RoomActivity
    switch($phase){'walking'{Request-RoomAction 'bed'};'bed-sleep'{Request-RoomAction 'bed';Await-RoomPhase 'bed-sleep'};'rolling'{$room.roll=@{du=.2;dv=.1;remaining=2;chase=$true}};'dragging'{Begin-RoomToy 'box' ([System.Windows.Point]::new(300,300))}}
    Select-Outfit $(if($state.outfit -eq 'uniform'){'pajamas'}else{'uniform'})
    Check ($room.phase -eq 'reaction' -and -not $room.drag -and -not $room.roll -and $room.path.Count -eq 0 -and -not $w.IsVisible) "outfit change during $phase clears previous activity without duplicating pet"
}
Cancel-RoomActivity;$state.stories=$true;$room.nextAuto=$room.time;Update-Room .1
Check ($room.phase -eq 'walking' -and $room.task -in @('sofa','tea','box')) 'idle chooses a reachable house activity'
Request-RoomAction 'pet';Check ($room.phase -eq 'reaction' -and $room.path.Count -eq 0) 'user action interrupts autonomous activity'
Cancel-RoomActivity;$script:lastInteraction=$clock.ElapsedMilliseconds-301000;Update-Room .1
Check ($room.task -eq 'bed' -and $room.phase -eq 'walking') 'five minute idle sleep routes to bed'
$room.window.Left+=12;$room.window.Top+=8;$position=@{left=$room.window.Left;top=$room.window.Top};$room.window.Close();Pump
Check (-not $room.open -and $w.IsVisible) 'native close button safely collapses room'
Show-Room;Pump;Check ($room.window.Left -eq $position.left -and $room.window.Top -eq $position.top) 'room location restored after collapse'
Close-Room;$restored=Read-PetState $dataDirectory
Check ([math]::Abs($restored.home.left-$position.left) -lt .001 -and -not $restored.ContainsKey('homeOpen')) 'room location saved without auto-opening on restart'
$state.stories=$false;Reset-Pomodoro $state
$script:cooldownUntil=0;$null=Invoke-Interaction 'smug';Check ($row -eq 21) 'desktop smug action remains available outside house'
if($env:KALING_RECORD_PREVIEW -eq '1'){. (Join-Path $root 'tests\Room.Preview.ps1')}
Show-Room;Pump;Begin-RoomToy 'box' ([System.Windows.Point]::new(300,300))
# Integration teardown closes the application while a room drag is active.
$limitations.Add('Room interactions exercise production WPF controls and drag handlers; physical pointer dragging is not synthesized when Windows cannot guarantee the target window.')
