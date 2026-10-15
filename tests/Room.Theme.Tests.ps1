# Runs after the existing room and character acceptance tests.
Stop-Activity;Reset-Pomodoro $state;$state.quiet=$false;$state.stories=$false
Select-Character 'ren';Show-Room;Pump
$ren=Get-RoomTheme;$savedRoomWindow=$room.window
Check ($room.theme -eq 'ren' -and $room.window.Title -eq $ren.title) 'Ren opens own named room theme'
Check ($room.window.Background.ToString() -eq '#FFF1EEE5' -and $room.message.Foreground.ToString() -eq '#FF35534C') 'Ren applies ivory and jade window colors'
foreach($name in @('room','bed','sofa','wardrobe','table','box','ball')){
    $image=Get-RoomBitmap $name
    Check ($image.IsFrozen -and $image.PixelWidth -gt 0 -and $image.PixelHeight -gt 0) "Ren themed asset $name loads and freezes"
    Check ([object]::ReferenceEquals($image,(Get-RoomBitmap $name))) "Ren themed asset $name reuses cache"
}
Request-RoomAction 'bed';Check ($room.message.Text -eq $ren.dialogue.bed) 'Ren room uses its own calm dialogue'
Await-RoomPhase 'bed-sleep';Capture-Room 'ren-home-bed.png'
Check ([object]::ReferenceEquals($room.bedFront.Source,(Get-RoomBitmap 'bed')) -and $room.bedFront.Visibility -eq 'Visible') 'bed occlusion uses Ren bedding'
Request-RoomAction 'wake';Await-RoomPhase 'stretch';Request-RoomAction 'sofa';Await-RoomPhase 'sofa';Capture-Room 'ren-home-sofa.png'
Request-RoomAction 'box';Await-RoomPhase 'box-peek';Capture-Room 'ren-home-box.png'
Check ([object]::ReferenceEquals($room.boxFront.Source,(Get-RoomBitmap 'box'))) 'hiding occlusion uses Ren travel chest'
Cancel-RoomActivity;Capture-Room 'ren-home-overview.png'
$renBackground=$room.backgroundVisual.Source;$renBed=$room.visuals.bed.Source
foreach($mode in @('visible','hidden','dragging')){
    Select-Character 'ren'
    if($mode -eq 'hidden'){$script:manualHidden=$true;Update-Visibility}
    if($mode -eq 'dragging'){Begin-RoomToy 'box' ([System.Windows.Point]::new(300,300))}
    $ballU=$state.home.ball.u;$boxV=$state.home.box.v
    Select-Character 'kaling'
    Check ($room.theme -eq 'kaling' -and $room.window.Title -eq (Get-RoomTheme).title -and -not [object]::ReferenceEquals($room.visuals.bed.Source,$renBed)) "switch $mode replaces Ren room and furniture with Kaling assets"
    Check (-not $room.drag -and -not $w.IsVisible -and [object]::ReferenceEquals($savedRoomWindow,$room.window) -and $state.home.ball.u -eq $ballU -and $state.home.box.v -eq $boxV) "switch $mode keeps one room and toy locations"
    Select-Character 'ren'
    Check ([object]::ReferenceEquals($renBackground,$room.backgroundVisual.Source) -and [object]::ReferenceEquals($renBed,$room.bedFront.Source)) "switch $mode restores cached Ren background and occlusion"
    if($mode -eq 'hidden'){Check (-not $room.window.IsVisible -and -not $w.IsVisible) 'theme switch never reveals hidden room';$script:manualHidden=$false;Update-Visibility}
}
Close-Room;Show-Room;Pump
Check ($room.theme -eq 'ren' -and -not $w.IsVisible) 'reopen preserves selected character theme without duplicate actor'
Close-Room;$null=Start-Attack 'dragon'
