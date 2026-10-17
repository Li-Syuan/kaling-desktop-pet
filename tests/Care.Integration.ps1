# Live WPF coverage; model time is explicit and no real desktop input is sent.
Stop-Activity;Close-Room;Reset-Pomodoro $state;$state.quiet=$false;$state.autoHide=$false;$state.stories=$false;$state.care=New-CareState
$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility
function Care-Step([int]$Count){for($k=0;$k -lt $Count;$k++){Update-Care .1;if($room.open){Update-Room .1};Update-CareVisual};Pump}
function Care-Ready {Cancel-CareActivity;if($room.open){Cancel-RoomActivity};$script:cooldownUntil=0;$script:actionUntil=0;$script:drag=$false;$script:pendingClick=$null;$script:careNotice=120}
foreach($pair in @(@('ren','original'),@('kaling','uniform'),@('kaling','pajamas'),@('kaling','hoodie'),@('mushroom','original'),@('ribbon-pig','original'),@('slime','original'))){
 Select-Character $pair[0];Select-Outfit $pair[1];$state.care.characters[$state.character]=New-CharacterCare;$c=Get-ActiveCare;Care-Ready
 foreach($f in 0..7){$art=Get-CareArt 'reaction' $f;Check ($art.IsFrozen -and $art.PixelHeight -gt 0) "$($pair -join '/') care frame $f is valid"}
 $before=$c.satiety;$null=Invoke-Interaction 'cookie';Check ($c.satiety -eq $before -and $careTask.kind -eq 'food') 'feeding waits for completed animation'
 Begin-Pointer ([System.Windows.Point]::new(100,100)) .2 $false;End-Pointer;Care-Ready;Care-Step 30
 Check ($c.meals -eq 0 -and $c.satiety -le $before) 'drag interrupts food without credit'
 Care-Ready;$null=Invoke-Interaction 'pudding';Care-Step 30
 Check ($c.meals -eq 1 -and $c.satiety -gt $before) "$($pair -join '/') completed desktop food updates care"
 $c.urge=0;$c.autoTried=$true;Care-Ready;Update-Care .1;Update-CareVisual
 Check ($careTask.kind -eq 'accident' -and [object]::ReferenceEquals($img.Source,(Get-CareArt 'reaction' (([int][math]::Floor($careVisualTime/.22))%4)))) "$($pair -join '/') accident uses matching costume"
 Care-Step 26;Sync-CareMesses
 Check ($c.messes.Count -eq 1 -and $careWindows.Count -eq 1 -and $careTask.kind -eq 'relief') "$($pair -join '/') accident spawns one clickable desktop mess"
 Capture ('care-'+$state.character+'-'+$state.outfit+'-accident.png')
 $win=@($careWindows.Values)[0];$handle=([System.Windows.Interop.WindowInteropHelper]::new($win)).Handle
 Check (([KalingNative]::GetStyle($handle,-20) -band 0x08000000) -ne 0) 'mess window never activates'
 Toggle-Through;Check (([KalingNative]::GetStyle($handle,-20) -band 0x20) -ne 0) 'mess follows click-through preference';Toggle-Through
 # Route a real WPF left-button event with its routed identifier.
 $click=[System.Windows.Input.MouseButtonEventArgs]::new([System.Windows.Input.Mouse]::PrimaryDevice,0,[System.Windows.Input.MouseButton]::Left);$click.RoutedEvent=[System.Windows.UIElement]::MouseLeftButtonDownEvent;$win.Content.RaiseEvent($click)
 Check ($c.messes.Count -eq 0 -and $careWindows.Count -eq 0 -and $careEffects.Count -gt 0) 'click removes mess and creates short bubble effect'
 Care-Step 8;Check ($careEffects.Count -eq 0) 'cleaning effect closes promptly'
 Care-Ready;$c.urge=20;$c.meals=1;$c.autoTried=$true;$left=$w.Left;$top=$w.Top;$training=$c.training
 Check (Request-CareAction 'toilet') 'guided toilet opens room from desktop'
 Check ($room.open -and -not $w.IsVisible -and $careTask.returnDesktop) 'temporary room owns the only character'
 for($k=0;$k -lt 200 -and $room.phase -ne 'care-toilet';$k++){Care-Step 1}
 Check ($room.phase -eq 'care-toilet' -and $room.actor.Visibility -eq 'Hidden' -and $room.careScreen.Visibility -eq 'Visible') 'toilet screen fully conceals actor'
 Render-Room;Check ($room.actor.Visibility -eq 'Hidden') 'redraw retains toilet occlusion';if($state.character -eq 'ren'){Capture-Room 'care-ren-toilet.png'}
 Care-Step 65
 Check (-not $room.open -and $w.IsVisible -and $c.training -eq ($training+10) -and $c.urge -lt 0 -and $w.Left -eq $left -and $w.Top -eq $top) 'completed guided toilet returns to exact desktop position and trains once'
 Care-Ready;$c.hygiene=12;Show-Room;Pump
 Check (Request-CareAction 'bath') 'bath available from room'
 for($k=0;$k -lt 240 -and $room.phase -ne 'care-bath';$k++){Care-Step 1}
 Check ($room.phase -eq 'care-bath' -and $room.actor.Clip.Rect.Height -eq $(if($state.character -eq 'slime'){144}else{110}) -and $room.careFoam.Visibility -eq 'Visible') 'bath uses head-only clipping and foam occlusion'
 Care-Step 8;Render-Room;Check ($room.actor.Clip.Rect.Height -eq $(if($state.character -eq 'slime'){144}else{110})) 'redraw retains bath clipping';if($state.character -in @('ren','slime')){Capture-Room ('care-'+$state.character+'-bath.png')}
 Care-Step 90;Check ($room.open -and -not $w.IsVisible -and $c.hygiene -gt 99) 'bath restores hygiene and stays in already-open house'
 Care-Ready;$c.satiety=40;$c.meals=0;Request-RoomAction 'cookie';Await-RoomPhase 'food';Check ($c.meals -eq 0) 'room meal also waits until finished';Care-Step 35;Check ($c.meals -eq 1) 'room meal commits exactly once'
 Care-Ready;$c.urge=0;$c.autoTried=$true;Update-Care .1;Care-Step 26;Sync-CareMesses
 Check ($c.messes.Count -eq 1 -and $c.messes[0].place -eq 'room' -and (Test-RoomFloor $c.messes[0].u $c.messes[0].v) -and $careRoomVisuals.Count -eq 1) 'room accident stays on reachable floor'
 Remove-CareMess '' -All;Check ($careRoomVisuals.Count -eq 0) 'room mess removed with shared cleanup'
 Close-Room;Care-Ready
}
Select-Character 'ren';$state.care.characters.ren=New-CharacterCare;$c=Get-ActiveCare
foreach($case in @('focus','quiet','hidden','fullscreen','disabled')){
 Care-Ready;$c.digest=100.0;$c.meals=1;$before=$c.satiety
 switch($case){'focus'{Start-Timer};'quiet'{$state.quiet=$true};'hidden'{$script:manualHidden=$true};'fullscreen'{$script:fullscreenHidden=$true};'disabled'{$state.care.enabled=$false}}
 Update-Care 2;Check ($c.digest -eq 100 -and $c.satiety -eq $before) "$case pauses needs and digestion"
 $state.quiet=$false;$script:manualHidden=$false;$script:fullscreenHidden=$false;$state.care.enabled=$true;Reset-Pomodoro $state;Update-Visibility
}
foreach($interrupt in @('drag','switch','pet','hide','attack','close-room','outfit','focus','quiet')){
 Select-Character 'ren';Care-Ready;$c=Get-ActiveCare;$c.urge=25;$c.autoTried=$true;$c.meals=1;$training=$c.training;$null=Request-CareAction 'toilet'
 switch($interrupt){
  'drag'{Begin-RoomToy 'box' ([System.Windows.Point]::new(300,300));End-RoomToy}
  'switch'{Select-Character 'kaling'}
  'pet'{$null=Invoke-Interaction 'pet'}
  'hide'{$script:manualHidden=$true;Update-Visibility}
  'attack'{$null=Request-Attack 'petal'}
  'close-room'{Close-Room}
  'outfit'{Select-Outfit 'original'}
  'focus'{Start-Timer}
  'quiet'{Toggle-Preference 'quiet' $quietItem}
 }
 Check (-not $careTask -and $c.training -eq $training -and $c.urge -ge 0) "toilet interrupted by $interrupt without premature credit"
 Stop-Activity;Close-Room;$script:manualHidden=$false;$state.quiet=$false;Reset-Pomodoro $state;Update-Visibility
}
Select-Character 'ren';Care-Ready;$c=Get-ActiveCare;$c.urge=30;$c.meals=1;$c.autoTried=$true;$training=$c.training
Check (Request-CareAction 'toilet' -Automatic) 'autonomous toilet starts through shared controller'
Check (-not $room.window.ShowActivated) 'autonomous house opening does not request foreground focus'
Care-Step 200
Check (-not $room.open -and $c.urge -lt 0 -and $c.training -eq $training) 'autonomous toilet returns without granting guided training'
Care-Ready;$c.hygiene=10;$null=Request-CareAction 'bath';Care-Step 70;Close-Room
Check ($c.hygiene -lt 11 -and -not $careTask) 'closing during bath never awards unfinished cleaning'
Select-Character 'ren';Care-Ready;$c=Get-ActiveCare;$c.messes=@(@{id='offscreen';place='desktop';x=-99000.0;y=99000.0});Sync-CareMesses
Check ($c.messes[0].x -gt -99000 -and $c.messes[0].y -lt 99000) 'saved mess is clamped to an available monitor'
Save-Settings;$reload=Read-PetState $dataDirectory;Check ($reload.care.characters.ren.messes.Count -eq 1) 'care save includes persistent mess'
$script:manualHidden=$true;Update-Visibility;Check ($careWindows.Count -eq 0) 'manual hide clears visible mess windows'
$script:manualHidden=$false;Update-Visibility;Check ($careWindows.Count -eq 1) 'show restores same mess'
Select-Character 'kaling';Check ($careWindows.Count -eq 0) 'switching character hides inactive messes'
Select-Character 'ren';Check ($careWindows.Count -eq 1) 'returning character restores own messes'
Toggle-Care;Check ($careWindows.Count -eq 0 -and -not $state.care.enabled) 'disable hides messes without losing state';Toggle-Care
Update-CareMenus;Check ($careEnabledItem.IsChecked -and $trayCareEnabled.Checked -and $careStatusItem.Header -match '飽足') 'context and tray share care status and toggle'
Remove-CareMess '' -All;Care-Step 10;Care-Ready
foreach($skill in @('petal','combo','dragon')){Check (Request-Attack $skill) "care integration preserves $skill";Stop-Activity}
Show-Room;Pump;Capture-Room 'care-ren-overview.png';Close-Room
# Exercise the actual dispatcher with care enabled, then restore the user's safe test fixture.
$script:actionUntil=0;$timer.Start();Pump-For 700;$timer.Stop();Check (-not $closing -and -not (Test-Path $log)) 'live care dispatcher runs without exceptions'
Close-CareWindows;Check ($careWindows.Count -eq 0 -and $careEffects.Count -eq 0) 'shutdown helper disposes every care window'
