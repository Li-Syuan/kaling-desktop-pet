# Exercise collisions between the room and character/attack controllers.
Reset-Pomodoro $state;Select-Character 'ren';$null=Start-Attack 'combo'
Step-Attack ($activity.start+800);$origin=$activity.originLeft;Show-Room;Pump
Check ($room.open -and -not $w.IsVisible -and -not $fxWindow.IsVisible -and $activity.kind -eq 'idle' -and $w.Left -eq $origin) 'entering room cancels dash and hides both desktop layers'
Check (-not (Start-Attack 'dragon')) 'room blocks desktop sword effects'
foreach($entry in @(@('sofa','sofa',15),@('bed','bed-sleep',16),@('box','box-peek',20),@('ball','ball-tap',3),@('tea','food',14))){
    Request-RoomAction $entry[0];Await-RoomPhase $entry[1]
    Check ($row -eq $entry[2] -and $row -lt 21 -and $room.actor.Source -and -not $w.IsVisible) "Ren $($entry[0]) uses daily pose without attack-row collision"
}
Request-RoomAction 'bed';Await-RoomPhase 'bed-sleep';Request-RoomAction 'wake'
Check ($row -eq 20 -and $room.phase -eq 'waking') 'Ren wakes with peek instead of attack pose'
Capture-Room 'ren-room-wake.png'
foreach($phase in @('walking','bed-sleep','dragging')){
    Cancel-RoomActivity
    switch($phase){'walking'{Request-RoomAction 'sofa'};'bed-sleep'{Request-RoomAction 'bed';Await-RoomPhase 'bed-sleep'};'dragging'{Begin-RoomToy 'box' ([System.Windows.Point]::new(300,300))}}
    Start-Pomodoro $state;$remaining=$state.pomo.remaining
    Select-Character $(if($state.character -eq 'ren'){'kaling'}else{'ren'})
    Check ($room.open -and -not $room.drag -and $room.path.Count -eq 0 -and -not $w.IsVisible -and $row -eq 0 -and $state.pomo.remaining -eq $remaining -and $state.pomo.status -eq 'running') "room switch during $phase clears action and preserves timer"
    Reset-Pomodoro $state
}
Select-Character 'ren';Show-Wardrobe;Pump
Check ($wardrobeButtons.Count -eq 1 -and -not $w.IsVisible) 'room wardrobe follows Ren character';$wardrobeWindow.Close()
$state.home.box=@{u=.45;v=.35};Save-Settings;$restored=Read-PetState $dataDirectory
Check ($restored.character -eq 'ren' -and $restored.home.box.u -eq .45 -and $restored.home.box.v -eq .35) 'character and house preferences persist together'
Close-Room;Check ($w.IsVisible -and (Start-Attack 'petal')) 'returning to desktop re-enables sword effects'
Stop-Activity;$script:cooldownUntil=0;$null=Invoke-Interaction 'smug'
Check ($row -eq 11 -and -not $fxWindow.IsVisible) 'Ren smug menu uses a daily reaction rather than sword animation'
# Leave a live attack for shutdown cleanup, as in the original Ren harness.
$null=Start-Attack 'dragon'
