# Loaded into the existing WPF acceptance harness; uses its Check/Pump/Capture helpers.
Reset-Pomodoro $state;$state.quiet=$false;$state.stories=$false;$state.look=$false;$state.mode='stay'
$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility
Select-Character 'kaling';Select-Outfit 'hoodie'
$left=$w.Left;$top=$w.Top;$scale=$state.scale;$remaining=$state.pomo.remaining
Select-Character 'ren'
Check ($state.character -eq 'ren' -and $state.outfit -eq 'original' -and $frames.Count -eq 104) 'Ren loads complete independent animation catalog'
Check ($w.Left -eq $left -and $w.Top -eq $top -and $state.scale -eq $scale -and $state.pomo.remaining -eq $remaining) 'character switch preserves position size and timer'
Show-Wardrobe;Pump;Check ($wardrobeButtons.Count -eq 1 -and $wardrobeButtons.ContainsKey('original')) 'Ren wardrobe contains only her outfit';$wardrobeWindow.Close()
for($r=0;$r -lt 24;$r++){
    Set-Animation $r;Check ($img.Source.PixelWidth -eq 192 -and $img.Source.PixelHeight -eq 208) "Ren action $r renders"
}
foreach($name in @('pet','cookie','pudding','tea','sit','sleep','wake','stretch','spin','peek')){
    $script:cooldownUntil=0;$null=Invoke-Interaction $name
    Check ($bubbleText.Text -eq $character.dialogue.$name) "Ren dialogue $name"
}
Mark-Activity;Set-Animation 0 0;Capture 'ren-idle.png'
foreach($name in @('petal','combo','dragon')){
    Check (Start-Attack $name) "$name starts"
    $start=$activity.start;$duration=$activity.spec.duration
    foreach($part in @(.1,.35,.6,.85)){
        Step-Attack ([long]($start+$duration*$part));Pump
        Check ($activity.kind -eq 'attack' -and $fxWindow.IsVisible -and $row -ge 21) "$name timeline $part [kind=$($activity.kind) visible=$($fxWindow.IsVisible) row=$row allowed=$(Test-AttackAllowed) duration=$duration start=$start]"
    }
    Check (([KalingNative]::GetStyle($fxHandle,-20) -band 0x08000020) -eq 0x08000020) "$name effect is NOACTIVATE and TRANSPARENT"
    Check ($fxWindow.ShowInTaskbar -eq $false -and -not $fxWindow.IsHitTestVisible) "$name effect never accepts input"
    Step-Attack ([long]($start+$duration))
    Check ($activity.kind -eq 'idle' -and -not $fxWindow.IsVisible -and $row -eq 0) "$name completes and cleans up"
}
$null=Start-Attack 'combo';Step-Attack ($activity.start+1100);Save-Settings
Check ([math]::Abs((Read-PetState $dataDirectory).left-$activity.originLeft) -lt .01) 'saving during dash keeps resting position'
Begin-Pointer ([System.Windows.Point]::new(100,100)) .2 $false
Check ($activity.kind -eq 'idle' -and -not $fxWindow.IsVisible) 'pointer press interrupts attack'
End-Pointer;$script:pendingClick=$null
foreach($cancel in @('pet','wardrobe','quiet','timer','manual','fullscreen','resize','outfit','character','animation')){
    Reset-Pomodoro $state;$state.quiet=$false;$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility;Select-Character 'ren'
    $null=Start-Attack 'dragon'
    switch($cancel){
        'pet' {$null=Invoke-Interaction 'pet'}
        'wardrobe' {Show-Wardrobe;$wardrobeWindow.Close()}
        'quiet' {Toggle-Preference 'quiet' $quietItem}
        'timer' {Start-Timer}
        'manual' {Toggle-Visibility}
        'fullscreen' {$script:fullscreenHidden=$true;Update-Visibility}
        'resize' {Resize-Pet 2}
        'outfit' {Select-Outfit 'original'}
        'character' {Select-Character 'kaling'}
        'animation' {Set-Animation 3}
    }
    Check ($activity.kind -eq 'idle' -and -not $fxWindow.IsVisible) "interrupt attack via $cancel"
}
Select-Character 'ren';$state.quiet=$true;Check (-not (Start-Attack 'petal')) 'quiet mode blocks attacks'
$state.quiet=$false;Start-Timer;Check (-not (Start-Attack 'dragon')) 'running timer blocks attacks';Pause-Timer
$a=Get-WorkArea
foreach($edge in @('left','right')){
    $w.Left=if($edge -eq 'left'){$a.Left}else{$a.Right-$w.Width}
    $null=Start-Attack 'combo';Step-Attack ($activity.start+1200)
    Check ($fxWindow.Left -ge $a.Left -and $fxWindow.Left+$fxWindow.Width -le $a.Right+.01 -and $fxWindow.Top -ge $a.Top -and $fxWindow.Top+$fxWindow.Height -le $a.Bottom+.01) "$edge effect fits work area"
    Check ($activity.direction -eq $(if($edge -eq 'left'){1}else{-1})) "$edge attack faces available space"
    Stop-Activity
}
$w.Left=$left;$w.Top=$top;Resize-Pet 1.5
Select-Character 'kaling';Check ($state.outfit -eq 'hoodie') 'Kaling outfit restored after Ren'
Select-Character 'ren';Save-Settings;$restored=Read-PetState $dataDirectory
Check ($restored.character -eq 'ren' -and $restored.characterOutfits.kaling -eq 'hoodie') 'both character preferences persist'
# Render actual WPF actor and effect into one preview at the same timestamp.
$null=Start-Attack 'dragon';Step-Attack ($activity.start+2100);Pump
$visual=[System.Windows.Media.DrawingVisual]::new();$dc=$visual.RenderOpen()
$dc.DrawRectangle([System.Windows.Media.BrushConverter]::new().ConvertFromString('#182238'),$null,[System.Windows.Rect]::new(0,0,$fxWindow.Width,$fxWindow.Height))
$actor=[System.Windows.Media.VisualBrush]::new($panel)
$dc.DrawRectangle($actor,$null,[System.Windows.Rect]::new($w.Left-$fxWindow.Left,$w.Top-$fxWindow.Top,$w.Width,$w.Height))
$dc.DrawRectangle([System.Windows.Media.VisualBrush]::new($fxCanvas),$null,[System.Windows.Rect]::new(0,0,$fxWindow.Width,$fxWindow.Height));$dc.Close()
$render=[System.Windows.Media.Imaging.RenderTargetBitmap]::new([int]$fxWindow.Width,[int]$fxWindow.Height,96,96,[System.Windows.Media.PixelFormats]::Pbgra32);$render.Render($visual)
$encoder=[System.Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($render))
$stream=[IO.File]::Create((Join-Path $dataDirectory 'ren-dragon-wpf.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
Stop-Activity;Select-Character 'kaling'

Reset-Pomodoro $state;Select-Character 'ren';$null=Start-Attack 'dragon'
Check ($activity.kind -eq 'attack') 'closing acceptance leaves attack active for application shutdown'
