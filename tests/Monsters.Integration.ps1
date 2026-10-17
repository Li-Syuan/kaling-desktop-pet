# Real WPF rendering, room lifecycle and catalogue-driven menu switching.
Close-Room;Close-CareWindows;Stop-Activity;Reset-Pomodoro $state
$state.quiet=$false;$state.stories=$false;$state.look=$false;$state.mode='stay';$state.care.enabled=$false
$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility
Check ($characterCatalog.characters.Count -eq 5 -and $characterItems.Count -eq 10) 'five identities available in context and tray menus'
foreach($id in @('mushroom','ribbon-pig','slime')){
    Select-Character 'ren';$null=Start-Attack 'dragon';$left=$activity.originLeft;$top=$w.Top
    $pair=@($characterItems | Where-Object {$_.id -eq $id -and $_.item -is [System.Windows.Controls.MenuItem]})[0]
    $pair.item.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent));Pump
    Check ($state.character -eq $id -and $activity.kind -eq 'idle' -and -not $fxWindow.IsVisible) "$id menu cancels Ren effect and selects own identity"
    Check ($w.Left -eq $left -and $w.Top -eq $top -and $frames.Count -eq 112) "$id preserves position and loads all 112 frame keys"
    Check (-not (Request-Attack 'dragon')) "$id cannot accidentally perform Ren attacks"
    $entry=(Get-OutfitAssets 'original').entry
    for($r=0;$r -lt $counts.Count;$r++){
        $hashes=@{}
        for($f=0;$f -lt $counts[$r];$f++){
            $bitmap=$frames["$r,$f"];$bytes=New-Object byte[] (192*208*4);$bitmap.CopyPixels($bytes,768,0)
            $sha=[Security.Cryptography.SHA256]::Create();try{$hash=[Convert]::ToBase64String($sha.ComputeHash($bytes))}finally{$sha.Dispose()};$hashes[$hash]=$true
            $nonempty=$false;for($px=3;$px -lt $bytes.Length;$px+=4){if($bytes[$px] -gt 0){$nonempty=$true;break}}
            Check ($bitmap.IsFrozen -and $bitmap.PixelWidth -eq 192 -and $bitmap.PixelHeight -eq 208 -and $nonempty) "$id action $r frame $f renders nonempty frozen art"
        }
        Check ($hashes.Count -gt 1) "$id action $r has changing frames"
    }
    $script:cooldownUntil=0;$null=Invoke-Interaction 'pet';Check ($bubbleText.Text -eq $character.dialogue.pet) "$id uses own desktop voice"
    Hide-Bubble;Set-Animation 0 0;Capture ($id+'-desktop.png')
    # Capture actual frame rendering on light and dark backgrounds in a WPF contact sheet.
    $sheet=[System.Windows.Controls.WrapPanel]::new();$sheet.Width=768;$sheet.Height=832
    foreach($r in @(0,1,2,4,6,11,12,13,14,15,16,17,20,21,24,25)){
        $tile=[System.Windows.Controls.Border]::new();$tile.Width=192;$tile.Height=208;$tile.Background=if($r%2){'#182839'}else{'#FFF1DF'}
        $pic=[System.Windows.Controls.Image]::new();$pic.Source=$frames["$r,1"];$tile.Child=$pic;[void]$sheet.Children.Add($tile)
    }
    $sheet.Measure([System.Windows.Size]::new(768,832));$sheet.Arrange([System.Windows.Rect]::new(0,0,768,832));$sheet.UpdateLayout()
    $render=[System.Windows.Media.Imaging.RenderTargetBitmap]::new(768,832,96,96,[System.Windows.Media.PixelFormats]::Pbgra32);$render.Render($sheet)
    $enc=[System.Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($render));$stream=[IO.File]::Create((Join-Path $dataDirectory ($id+'-actions.png')));try{$enc.Save($stream)}finally{$stream.Dispose()}
    Show-Wardrobe;Pump;Check ($wardrobeButtons.Count -eq 1 -and $wardrobeButtons.ContainsKey('original')) "$id appearance menu has own form only";$wardrobeWindow.Close()
    Show-Room;Pump;Check ($room.theme -eq $id -and -not $w.IsVisible) "$id forest home has single actor";Capture-Room ($id+'-home-overview.png')
    Request-RoomAction 'bed';Await-RoomPhase 'bed-sleep';Capture-Room ($id+'-home-bed.png')
    if($id -eq 'slime'){Check ($room.actor.Clip.Rect.Height -eq 144 -and [Windows.Controls.Canvas]::GetTop($room.actor) -eq ($room.pose.y-180)) 'Slime bed keeps short face visible above blanket'}
    Request-RoomAction 'wake';Await-RoomPhase 'stretch'
    Request-RoomAction 'sofa';Await-RoomPhase 'sofa';Check ($row -eq 22) "$id sofa stays on rest animation"
    foreach($food in @('cookie','pudding','tea')){Request-RoomAction $food;Await-RoomPhase 'food';Check ($row -eq @{cookie=12;pudding=13;tea=14}[$food]) "$id room $food uses matching pose"}
    Request-RoomAction 'ball';Await-RoomPhase 'ball-tap';Check ($row -eq 24) "$id pushes toy with its own animation"
    Request-RoomAction 'box';Await-RoomPhase 'box-hide';Check ($room.actor.Visibility -eq 'Hidden') "$id fully hides inside box";Await-RoomPhase 'box-peek';Capture-Room ($id+'-home-box.png')
    if($id -eq 'slime'){Check ([Windows.Controls.Canvas]::GetTop($room.actor) -eq ($room.pose.y-177)) 'Slime peeks above box front'}
    Start-Timer;$remain=$state.pomo.remaining;Select-Character 'ren';Select-Character $id
    Check ($state.pomo.status -eq 'running' -and $state.pomo.remaining -eq $remain -and -not $w.IsVisible) "$id switch keeps focus and a single room actor";Reset-Pomodoro $state
    $script:manualHidden=$true;Update-Visibility;Select-Character $id;Check (-not $room.window.IsVisible -and -not $w.IsVisible) "$id switch respects hidden state"
    $script:manualHidden=$false;Update-Visibility;Close-Room
    $timer.Start();Pump-For 400;$timer.Stop();Check (-not $closing -and -not (Test-Path $log)) "$id runs through real dispatcher"
}
Select-Character 'ren';$state.care.enabled=$true
