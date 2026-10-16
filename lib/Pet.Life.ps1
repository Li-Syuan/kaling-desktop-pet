# Ambient life runs after care presentation, so neither overwrites the other.
# Approved whole-character artwork, with the same silhouette in every activity.
$script:lifeArtworkEnabled=$true
$script:life=$null;$script:lifeVisual=$null;$script:lifeLast=0L;$script:lifeActive=$false
$script:lifeTransition=$null;$script:lifeLastSource=$null;$script:lifeWasRig=$false
function Reset-Life {
    $script:life=[RenLifeState]::new((Get-Random -Maximum 2147483647))
    $script:lifeLast=$clock.ElapsedMilliseconds;$script:lifeActive=$false
    $script:lifeTransition=$null;$script:lifeLastSource=$null;$script:lifeWasRig=$false
}
function Stop-LifeGesture {if($life){$life.Interrupt()}}
function Notify-Life([string]$Event) {
    if($state.character -ne 'ren'){return};if(-not $life){Reset-Life}
    switch($Event){'press'{$life.Press()};'pet'{$life.Pet()};'snack'{$life.Snack()};default{$life.Interrupt()}}
}
function Test-LifeRig {
    return $lifeArtworkEnabled -and $state.character -eq 'ren' -and -not $room.open -and -not ($drag -and $moved) -and $activity.kind -ne 'attack' -and -not $careTask -and (-not $state.care.enabled -or (Get-ActiveCare).urge -lt 0) -and $row -in @(0,8,11)
}
function Update-LifeVisual {
    if(-not $lifeArtworkEnabled){$script:lifeActive=$false;$script:lifeTransition=$null;$script:lifeLastSource=$null;$script:lifeWasRig=$false;return}
    if(-not $loaded -or $state.character -ne 'ren'){$script:lifeActive=$false;return}
    if(-not $life){Reset-Life}
    $now=$clock.ElapsedMilliseconds;$dt=($now-$lifeLast)/1000.0;$script:lifeLast=$now
    $visible=-not $manualHidden -and -not $fullscreenHidden -and -not $closing -and $w.IsVisible -and -not $room.open
    $quiet=$state.quiet -or $state.pomo.status -eq 'running'
    $blocked=$menu.IsOpen -or $trayMenu.Visible -or $settingsWindow -or $wardrobeWindow
    $rig=Test-LifeRig
    $near=$false;$x=0.0;$y=0.0
    if($visible -and $rig -and -not $blocked -and $state.look -and -not $quiet){
        $p=Cursor-Position;$dx=$p.X-($w.Left+$w.Width*.5);$dy=$p.Y-($w.Top+88+($w.Height-120)*.45)
        $near=[math]::Sqrt($dx*$dx+$dy*$dy) -lt 600;$x=$dx/240;$y=$dy/220
    }
    $busy=-not $rig -or $row -eq 11 -or $blocked -or $drag
    $life.Step($dt,$x,$y,$near,$state.look,($state.stories -and $row -eq 0),$quiet,($visible -and -not $blocked),$busy)
    $script:lifeActive=$visible -and $rig
    if(-not $visible){$life.ResetAttention();$life.Interrupt();$script:lifeTransition=$null;return}
    if($rig){
        if(-not $lifeVisual){$script:lifeVisual=[RenLifeVisual]::new((Join-Path $root 'assets/characters/ren/life'))}
        $lifeVisual.Render($life,$quiet,($row -eq 11));$img.Source=$lifeVisual.Image
    }elseif($row -in @(15,16) -and -not $careTask -and (-not $state.care.enabled -or (Get-ActiveCare).urge -lt 0) -and -not $drag -and $activity.kind -ne 'attack'){
        $img.RenderTransformOrigin=[System.Windows.Point]::new(.5,1)
        $img.RenderTransform=[System.Windows.Media.ScaleTransform]::new(1,(1+[math]::Sin($life.Time*1.65)*.004))
    }
    # Brief pose blend only at the boundary of rig and legacy action. Never blend
    # across character/scene/care/attack/drag changes; those own their presentation.
    $allowBlend=$activity.kind -ne 'attack' -and -not $drag -and -not $careTask -and (-not $state.care.enabled -or (Get-ActiveCare).urge -lt 0)
    if($rig -ne $lifeWasRig -and $lifeLastSource -and $allowBlend){
        $snapshot=$lifeLastSource
        if($snapshot -is [System.Windows.Media.DrawingImage]){$snapshot=$snapshot.CloneCurrentValue();$snapshot.Freeze()}
        $script:lifeTransition=@{from=$snapshot;start=$now}
    }
    if(-not $allowBlend){$script:lifeTransition=$null}
    if($allowBlend -and -not $rig){$img.Source=$frames["$row,$frame"]}
    $target=$img.Source
    if($lifeTransition){
        $p=[math]::Min(1.0,($now-$lifeTransition.start)/160.0);$p=$p*$p*(3-2*$p)
        if($p -ge 1){$script:lifeTransition=$null}else{
            $g=[System.Windows.Media.DrawingGroup]::new();$dc=$g.Open();$r=[System.Windows.Rect]::new(0,0,192,208)
            $dc.PushOpacity(1-$p);$dc.DrawImage($lifeTransition.from,$r);$dc.Pop();$dc.PushOpacity($p);$dc.DrawImage($target,$r);$dc.Pop();$dc.Close()
            $img.Source=[System.Windows.Media.DrawingImage]::new($g)
        }
    }
    $script:lifeLastSource=$target;$script:lifeWasRig=$rig
}
