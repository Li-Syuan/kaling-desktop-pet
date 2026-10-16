# Exercise the actual WPF and tray event handlers, rather than only Start-Attack.
Stop-Activity;Close-Room;Reset-Pomodoro $state;$state.quiet=$false;$state.autoHide=$false
$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility;Select-Character 'ren'
function Click-SwordItem($Item){
    if($Item -is [System.Windows.Controls.MenuItem]){$Item.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))}
    else{$Item.PerformClick()}
}
Check ($attackItems.Count -eq 3 -and $trayAttackItems.Count -eq 3) 'both menus contain all three sword skills'
foreach($surface in @('context','tray')){
    $items=if($surface -eq 'context'){$attackItems}else{$trayAttackItems}
    foreach($item in $items){
        Update-CharacterMenus;Click-SwordItem $item;Pump
        Check ($activity.kind -eq 'attack' -and $activity.spec.id -eq $item.Tag -and $fxWindow.IsVisible) "$surface desktop menu launches $($item.Tag) with effect window"
        Stop-Activity
        Show-Room;Pump;Update-CharacterMenus
        $label=if($surface -eq 'context'){$item.Header}else{$item.Text}
        $enabled=if($surface -eq 'context'){$item.IsEnabled}else{$item.Enabled}
        Check ($enabled -and $label -match '回桌面施放') "$surface room menu explains return-to-desktop action"
        Click-SwordItem $item;Pump
        Check (-not $room.open -and $w.IsVisible -and $activity.kind -eq 'attack' -and $activity.spec.id -eq $item.Tag -and $fxWindow.IsVisible) "$surface room menu closes room and launches $($item.Tag)"
        Stop-Activity
    }
}
foreach($case in @('character','quiet','timer','hidden','wardrobe','toy-drag')){
    Reset-Pomodoro $state;Select-Character 'ren';Show-Room
    switch($case){
        'character'{Select-Character 'kaling'}
        'quiet'{$state.quiet=$true}
        'timer'{Start-Timer}
        'hidden'{$script:manualHidden=$true;Update-Visibility}
        'wardrobe'{Show-Wardrobe}
        'toy-drag'{Begin-RoomToy 'box' ([System.Windows.Point]::new(300,300))}
    }
    Update-CharacterMenus;$reason=Get-AttackBlockReason -AllowRoom
    Check ($reason -and -not $attackItems[0].IsEnabled -and -not $trayAttackItems[0].Enabled -and $attackStatusItem.Header -eq $reason -and $trayAttackStatusItem.Text -eq $reason) "$case shows matching reason in both skill menus"
    Check (-not (Request-Attack 'petal') -and $room.open -and -not $fxWindow.IsVisible) "$case blocks request without collapsing room or leaving effect"
    if($case -eq 'timer'){Check ($state.pomo.status -eq 'running') 'blocked skill request does not stop timer'}
    if($wardrobeWindow){$wardrobeWindow.Close()}
    $state.quiet=$false;$script:manualHidden=$false;Update-Visibility;Close-Room
}
Reset-Pomodoro $state;Select-Character 'ren';Update-CharacterMenus
Check ($attackItems[0].IsEnabled -and $trayAttackItems[0].Enabled) 'skills recover when blocking conditions are removed'
$null=Start-Attack 'dragon'
