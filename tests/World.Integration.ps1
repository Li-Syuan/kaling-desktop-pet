Close-World;Close-Play;Close-Room;Stop-Activity;Reset-Pomodoro $state
$state.quiet=$false;$state.stories=$false;$state.care.enabled=$false;$state.autoHide=$false;$script:manualHidden=$false;$script:fullscreenHidden=$false
$state.world=New-WorldState
function World-Click($Button){$event=if($Button -is [Windows.Controls.MenuItem]){[Windows.Controls.MenuItem]::ClickEvent}else{[Windows.Controls.Button]::ClickEvent};$Button.RaiseEvent([Windows.RoutedEventArgs]::new($event));Pump}
function World-Advance([double]$Seconds){for($i=0;$i -lt [math]::Ceiling($Seconds/.1);$i++){Update-World .1};Pump}
function Capture-World([string]$Name,[switch]$Window){
    $worldWindow.UpdateLayout();Pump
    if($Window){$image=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$worldWindow.ActualWidth,[int]$worldWindow.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$image.Render($worldWindow)}else{$image=$world.stage.Snapshot()}
    $enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($image));$stream=[IO.File]::Create((Join-Path $dataDirectory $Name));try{$enc.Save($stream)}finally{$stream.Dispose()}
}
foreach($id in @('ren','kaling','mushroom','ribbon-pig','slime')){
    Select-Character $id;$left=$w.Left;$top=$w.Top;World-Click $worldMenuItem
    Check ($worldWindow.IsVisible -and -not $w.IsVisible -and $world.session.Actors.Count -eq 1) "$id enters world as only visible actor"
    Check ($world.stage.Art[0].Id -eq $id -and $state.character -eq $id) "$id loads without mutating main identity"
    World-Click $world.buttons.signature;World-Advance 2;Capture-World ('world-'+$id+'.png')
    $timer.Start();Pump-For 180;$timer.Stop();Check (-not $closing -and -not (Test-Path $log)) "$id world live dispatcher is healthy"
    Close-World;Check ($w.IsVisible -and $w.Left -eq $left -and $w.Top -eq $top) "$id returns to original desktop"
}
Select-Character 'ren';$state.world.companion='slime';Show-World;Pump
Check ($world.session.Actors.Count -eq 2 -and $world.stage.Art[1].Id -eq 'slime') 'two independently loaded actors inhabit garden'
$world.stage.Press(145,270);$world.stage.Release(145,270);Check ($world.session.UsingSlot -eq 0) 'clicking visible hammock starts furniture use'
World-Click $world.buttons['story-sword'];World-Advance 2;Capture-World 'world-sword-care.png';Capture-World 'world-window.png' -Window
World-Advance 15;Capture-World 'world-leaf-chase.png'
World-Click $world.buttons.tea;World-Advance 6;Check ($state.world.habits.ren.tea -eq 1) 'tea records completed interaction'
$world.actor.SelectedIndex=1;World-Click $world.buttons.tea;World-Advance 2;World-Click $world.buttons.cancel;World-Advance 6;Check ($state.world.habits.slime.tea -eq 0) 'cancelled companion tea does not record'
World-Click $world.buttons.tea;World-Advance 6;Check ($state.world.habits.slime.tea -eq 1) 'companion habits remain separate'
$state.play.characters.ren.fish[1]=1;$state.play.characters.slime.flowers[2]=1;Refresh-World
Check ($world.stage.Fish[1] -eq 1 -and $world.stage.Flowers[2] -eq 1) 'existing fish and flowers appear in shared furnishings'
$world.decorate.IsChecked=$true;$before=[string]::Join(',',$world.session.Layout);$world.stage.Press(145,330);$world.stage.Move(450,420);$world.stage.Release(450,420)
Check ([string]::Join(',',$world.session.Layout) -eq $before) 'actual stage rejects blocked furniture drop'
$world.stage.Press(145,330);$world.stage.Move(755,535);$world.stage.Release(755,535);Refresh-World
Check ($world.session.Layout[5] -eq 'hammock') 'actual stage swaps placed furniture'
Save-WorldLayout;Save-Settings;$restored=Read-PetState $dataDirectory
Check ($restored.world.layout[5] -eq 'hammock' -and $restored.world.habits.slime.tea -eq 1) 'layout and independent habits persist'
$world.decorate.IsChecked=$false;World-Click $world.buttons.forest;World-Advance 6
for($n=0;$n -lt 3;$n++){Check ($world.choices.Children.Count -eq 2) "forest choice UI $n is reachable";World-Click $world.choices.Children[0];World-Advance 10}
Check ($state.world.trips -eq 1 -and $state.world.collections.mushroom -eq 1) 'three actual choices grant a forest souvenir'
Refresh-World;Check ($state.world.trips -eq 1) 'UI refresh cannot duplicate expedition reward';Capture-World 'world-forest-complete.png'
World-Click $world.buttons.cancel;$world.furniture.SelectedIndex=8;World-Click $world.buttons.place;$world.stage.Press(145,330);$world.stage.Release(145,330);Refresh-World
Check ($world.session.Layout[0] -eq 'mushroom') 'earned souvenir can be placed in a slot'
World-Click $world.buttons.photo;Check (@((Get-PlayCare).photos|Where-Object caption -eq '我們的小世界').Count -eq 1) 'world snapshot enters existing album'
$world.decorate.IsChecked=$false;World-Click $world.buttons['story-box'];World-Advance 7
$world.stage.Press($world.session.BoxX,$world.session.BoxY);$world.stage.Move(500,430);$world.stage.Release(500,430);Refresh-World
Check ($world.session.Branch -eq 'box') 'dragging box changes ongoing story';Capture-World 'world-box-branch.png'
$left=$w.Left;Start-Timer;Check ($null -eq $worldWindow -and $state.pomo.status -eq 'running' -and $w.Left -eq $left) 'focus closes world without resetting timer'
Pause-Timer;Show-World;Toggle-Visibility;Check ($null -eq $worldWindow -and -not $w.IsVisible) 'manual hide clears whole world';Toggle-Visibility
Show-Room;Show-World;Check ($worldWindow.IsVisible -and -not $room.window.IsVisible -and -not $w.IsVisible) 'world takes room ownership without duplicate actor';Close-World;Check ($room.window.IsVisible -and -not $w.IsVisible) 'world close restores previous house';Close-Room
Show-World;Select-Character 'mushroom';Check ($null -eq $worldWindow -and $state.character -eq 'mushroom' -and $w.IsVisible) 'character switch closes both world actors'
foreach($outfit in @('uniform','pajamas','hoodie')){Select-Character 'kaling';Select-Outfit $outfit;Show-World;Check ([object]::ReferenceEquals($world.stage.Art[0].Frames['0,0'],$frames['0,0'])) "world preserves Kaling $outfit";Check ($world.stage.Art[0].Signature.Count -eq 6) "Kaling $outfit has dedicated continuous signature poses";World-Click $world.buttons.signature;World-Advance 2;Capture-World ('world-kaling-'+$outfit+'.png');Close-World}
foreach($id in @('ren','kaling','mushroom','ribbon-pig','slime')){foreach($partner in @('ren','kaling','mushroom','ribbon-pig','slime')){if($id -eq $partner){continue};Select-Character $id;$state.world.companion=$partner;Show-World;Pump;Check ($world.stage.Art[0].Id -eq $id -and $world.stage.Art[1].Id -eq $partner -and $world.session.Actors.Count -eq 2) "$id and $partner load distinct art without switching primary";Close-World}}
Select-Character 'ren';$state.world.companion='slime';Show-World;World-Click $world.buttons.pond;World-Advance 6;Capture-World 'world-pond.png';$before=$state.world.trips;World-Click $world.buttons.cancel;World-Advance 8;Check ($state.world.trips -eq $before) 'cancelled pond trip has no reward'
$world.session.Interact('tea',0);$time=$world.session.Time;$worldWindow.WindowState='Minimized';World-Advance 4;Check ($world.session.Time -eq $time) 'minimizing pauses all world actions';$worldWindow.WindowState='Normal';Pump
$world.session.Paused=$true;World-Advance 4;Check ($world.session.Time -eq $time) 'world pause freezes actor and interaction clocks';$world.session.Paused=$false
$script:fullscreenHidden=$true;Update-Visibility;Check ($null -eq $worldWindow -and -not $w.IsVisible) 'fullscreen hide removes both actors';$script:fullscreenHidden=$false;Update-Visibility
Show-World;$state.quiet=$true;Update-World .1;Check ($null -eq $worldWindow) 'quiet mode stops the entire world';$state.quiet=$false
Show-World;$world.session.BeginDrag(6);Close-World;Check ($null -eq $worldWindow -and $w.IsVisible) 'closing during box drag releases world and restores desktop'
Show-World;$worldWindow.Close();Check ($null -eq $worldWindow -and $w.IsVisible) 'native window close follows same restoration path'
$state.world.companion='';$state.care.enabled=$true;Reset-Pomodoro $state;Select-Character 'ren';Show-World
$care=$state.care.characters.ren;$care.meals=1;$care.urge=.2;$care.digest=-1;$care.messes=@();World-Advance 1
Check (@($care.messes|Where-Object place -eq 'world').Count -eq 1 -and $world.stage.Messes.Count -eq 1) 'world consumes care once and displays actual mess'
World-Click $world.buttons.clean;Check (@($care.messes|Where-Object place -eq 'world').Count -eq 0) 'clean button removes world mess'
Close-World;Reset-Pomodoro $state;$state.care.enabled=$false
