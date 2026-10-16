# Same renderer/model as production; no fake control or alternative implementation.
Close-Room;Select-Character 'ren';Reset-Pomodoro $state
$state.quiet=$false;$state.stories=$true;$state.look=$true;$state.mode='stay';$state.care.enabled=$false
$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility;Set-Animation 0 0
$model=[RenLifeState]::new(7)
$model.Step(.1,1,.5,$true,$true,$true,$false,$true,$false)
Check ($model.EyeX -gt .5 -and $model.HeadX -eq 0) 'life: eyes respond before head dwell'
foreach($i in 1..20){$model.Step(.05,1,.5,$true,$true,$true,$false,$true,$false)}
Check ($model.HeadX -gt .8) 'life: sustained cursor attention smoothly turns head'
$before=$model.HeadX;$model.Step(.1,0,0,$false,$true,$true,$false,$true,$false)
Check ($model.HeadX -ge $before) 'life: glance lingers briefly after cursor leaves'
foreach($i in 1..40){$model.Step(.05,0,0,$false,$true,$true,$false,$true,$false)}
Check ([math]::Abs($model.EyeX) -lt .01 -and [math]::Abs($model.HeadX) -lt .03) 'life: attention recenters without snapping'
$time=$model.Time;$model.Step(60,1,1,$true,$true,$true,$false,$true,$false)
Check ($model.Time -eq $time) 'life: elapsed suspend gap cannot fast forward motion'
$model.Step(.1,1,1,$true,$true,$true,$false,$false,$false)
Check ($model.Time -eq $time) 'life: hidden time is paused'
$model.Press();Check ($model.Acknowledge -gt 0) 'life: pointer press has immediate visual acknowledgement'
$model.Pet();$model.Pet();$model.Pet()
Check ($model.Warmth -eq 6 -and $model.PetCount -eq 3) 'life: petting retains warmth and distinguishes repeated teasing'
$model.Snack();Check ($model.Warmth -eq 3) 'life: completed snack leaves relaxed expression'
$model=[RenLifeState]::new(17);$maxBlink=0;$gestures=[Collections.Generic.List[string]]::new();$last='';$deadlinesValid=$true;$intervalsValid=$true
foreach($i in 1..12000){
 $model.Step(.05,0,0,$false,$true,$true,$false,$true,$false)
 if($model.Blink -gt $maxBlink){$maxBlink=$model.Blink}
 if($model.Gesture -and $model.Gesture -ne $last){$gestures.Add($model.Gesture);$last=$model.Gesture;$deadlinesValid=$deadlinesValid -and $model.NextGesture -le $model.Time}
 if(-not $model.Gesture){$last='';$intervalsValid=$intervalsValid -and $model.NextGesture-$model.Time -le 50.01}
}
Check ($deadlinesValid -and $intervalsValid) 'life: autonomous schedules stay within intended range'
Check ($gestures.Count -ge 10 -and $maxBlink -gt .8) 'life: ten minute simulation keeps blinking and living'
for($i=2;$i -lt $gestures.Count;$i++){Check ($gestures[$i] -ne $gestures[$i-1] -and $gestures[$i] -ne $gestures[$i-2]) 'life: avoids last two gestures'}
$model.Gesture='listen';$model.Step(.05,1,1,$true,$true,$true,$true,$true,$false)
Check ($model.Gesture -eq '') 'life: quiet focus cancels an autonomous gesture'
$model.NextBlink=$model.Time
$model.Step(.05,1,1,$true,$true,$true,$true,$true,$false);$model.Step(.05,1,1,$true,$true,$true,$true,$true,$false)
Check ($model.Blink -gt 0) 'life: focus preserves blinking'
$a=[RenLifeState]::new(42);$b=[RenLifeState]::new(42)
foreach($i in 1..60){$a.Step((1.0/30),1,0,$true,$true,$false,$false,$true,$false)}
foreach($i in 1..120){$b.Step((1.0/60),1,0,$true,$true,$false,$false,$true,$false)}
Check ([math]::Abs($a.EyeX-$b.EyeX) -lt .0001 -and [math]::Abs($a.HeadX-$b.HeadX) -lt .005) 'life: attention response independent of refresh rate'

Reset-Life;$script:lifeLast=$clock.ElapsedMilliseconds-33;Update-CareVisual;Update-LifeVisual
Check ($lifeActive -and $img.Source -is [System.Windows.Media.DrawingImage]) 'life: actual desktop uses layered WPF renderer'
$reference=$lifeVisual.Image;$before=$life.Time;$timer.Start();Pump-For 300;$timer.Stop()
Check ($life.Time -gt $before -and [object]::ReferenceEquals($reference,$lifeVisual.Image)) 'life: real dispatcher advances retained drawing without allocating another actor'
Capture 'ren-life-desktop.png'
$script:cooldownUntil=0;$null=Invoke-Interaction 'pet';Update-CareVisual;Update-LifeVisual
Check ($life.Warmth -gt 5 -and $lifeActive -and $row -eq 11) 'life: head pat stays on same rig'
Capture 'ren-life-pet.png'
Begin-Pointer ([System.Windows.Point]::new(100,100)) .2 $false;Move-Pointer ([System.Windows.Point]::new(120,110));Update-CareVisual;Update-LifeVisual
Check (-not $lifeActive -and $row -eq 19 -and $null -eq $lifeTransition) 'life: drag owns sprite and clears blend'
End-Pointer;$script:pendingClick=$null
foreach($attack in @('petal','combo','dragon')){
 $null=Start-Attack $attack;Step-Attack ($activity.start+500);Update-CareVisual;Update-LifeVisual
 Check (-not $lifeActive -and $activity.kind -eq 'attack' -and $fxWindow.IsVisible) "life: does not overwrite $attack"
 Stop-Activity
}
Set-Animation 0 0;$state.care.enabled=$true;(Get-ActiveCare).urge=10
Update-CareVisual;$art=$img.Source;Update-LifeVisual
Check (-not $lifeActive -and [object]::ReferenceEquals($img.Source,$art)) 'life: care urgency retains its own art'
(Get-ActiveCare).urge=-1;$state.care.enabled=$false
Start-Timer;Set-Animation 8 0;Update-CareVisual;Update-LifeVisual
Check ($lifeActive -and $state.pomo.status -eq 'running' -and $life.Gesture -eq '') 'life: focus keeps subtle rig without autonomous performance'
$timer.Start();Pump-For 220;$timer.Stop();Capture 'ren-life-focus.png';Reset-Pomodoro $state
Set-Animation 15 1000;Update-CareVisual;Update-LifeVisual
$timer.Start();Pump-For 220;$timer.Stop()
Check ($null -eq $lifeTransition -and $img.Source -is [System.Windows.Media.Imaging.BitmapSource]) 'life: blend resolves to a real legacy frame without recursive ghosting'
Set-Animation 0 0;Update-CareVisual;Update-LifeVisual
$script:manualHidden=$true;Update-Visibility;Update-LifeVisual
Check (-not $lifeActive -and -not $w.IsVisible -and $null -eq $lifeTransition) 'life: manual hiding leaves no visible ambient actor'
$script:manualHidden=$false;Update-Visibility
$script:fullscreenHidden=$true;Update-Visibility;Update-LifeVisual
Check (-not $lifeActive -and -not $w.IsVisible) 'life: fullscreen hide excludes ambient presentation'
$script:fullscreenHidden=$false;Update-Visibility
Show-Room;Update-LifeVisual
Check (-not $lifeActive -and -not $w.IsVisible -and $room.window.IsVisible) 'life: entering room leaves only room actor'
Close-Room;Set-Animation 0 0;Update-CareVisual;Update-LifeVisual
Check ($lifeActive) 'life: closing room returns to layered desktop'
foreach($id in @('kaling','mushroom','ribbon-pig','ren')){
 Select-Character $id;Update-CareVisual;Update-LifeVisual
 Check ($lifeActive -eq ($id -eq 'ren') -and $null -eq $lifeTransition) "life: switch $id has no leftover rig or blend"
}
# Capture actual model+WPF throughput separately from OS/compositor frame rate.
$bench=[Diagnostics.Stopwatch]::StartNew()
foreach($i in 1..300){$life.Step((1.0/60),.4,0,$true,$true,$true,$false,$true,$false);$lifeVisual.Render($life,$false,$false)}
$bench.Stop()
@{frames=300;milliseconds=$bench.Elapsed.TotalMilliseconds;millisecondsPerUpdate=$bench.Elapsed.TotalMilliseconds/300;note='model + retained WPF drawing throughput; not physical display FPS'} | ConvertTo-Json | Set-Content (Join-Path $dataDirectory 'life-render-timing.json') -Encoding UTF8
$state.care.enabled=$true
