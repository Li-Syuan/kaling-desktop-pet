param([string]$OutputDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
Add-Type -Path (Join-Path $root 'lib/Pet.World.Model.cs')
. (Join-Path $root 'lib/Pet.State.ps1')
$checks=[Collections.Generic.List[string]]::new()
function Assert($Condition,[string]$Name){if(-not $Condition){throw $Name};$checks.Add($Name)}
function Advance($Session,[double]$Seconds){for($i=0;$i -lt [math]::Ceiling($Seconds/.1);$i++){$Session.Step(.1)}}
foreach($id in [KalingWorld.Session]::Ids){
    foreach($partner in @('')+[KalingWorld.Session]::Ids){if($id -eq $partner){continue}
        $s=[KalingWorld.Session]::new($id,$partner,21);$s.Auto=$false
        foreach($story in @('sword','snack','leaves','tea','box','rain')){
            Assert ($s.StartStory($story)) "$id/$partner starts $story";Advance $s 45
            Assert ($s.Story -eq '' -and @($s.Events|Where-Object Kind -eq 'story').Count -eq $s.Actors.Count) "$id/$partner completes $story for both actors"
            $s.Events.Clear();foreach($actor in $s.Actors){Assert ($actor.X -ge 95 -and $actor.X -le 805 -and -not $actor.Hidden) "$id/$partner recovers visible actor after $story"}
        }
    }
}
$s=[KalingWorld.Session]::new('ren','slime',6);$s.Auto=$false
$null=$s.StartStory('sword');Advance $s 1;$x=$s.Actors[1].X;$s.Paused=$true;Advance $s 10;Assert ($s.Actors[1].X -eq $x -and $s.Time -lt 2) 'paused story does not advance';$s.Paused=$false
$t=$s.Time;$s.Step(600);Assert ($s.Time -eq $t) 'sleep gap ignored'
$s.Cancel();$null=$s.Place('leaves',5);$null=$s.StartStory('sword');Advance $s 8.2
$bx=$s.BallX;$by=$s.BallY;$s.Step(.1);Assert ([math]::Sqrt([math]::Pow($s.BallX-$bx,2)+[math]::Pow($s.BallY-$by,2)) -le 13.01) 'story ball moves continuously at bounded speed'
for($i=0;$i -lt 300 -and $s.Phase -lt 3;$i++){$s.Step(.1)};Assert ($s.Actors[$s.Buddy].TargetX -eq 755 -and $s.Actors[$s.Buddy].TargetY -eq 480) 'chase and peek follow relocated leaf pile'
$s.Cancel();foreach($slot in 0..5){Assert ($s.UseFurniture($slot,1)) "furniture $slot is usable";Advance $s 20;Assert ($s.UsingSlot -eq -1 -and $s.Actors[1].TargetY -eq 420) "furniture $slot returns to walkway"};$s.Events.Clear()
foreach($branch in @('pet','bait','clean','box')){$null=$s.StartStory('snack');Advance $s 17;$s.Interact($branch,1);Assert ($s.Branch -eq $branch -and -not $s.Actors[0].Hidden) "branch $branch opens hiding actor";Advance $s 6;Assert ($s.Story -eq '') "branch $branch ends cleanly";$s.Events.Clear()}
$s.Interact('tea',0);Advance $s 2;$s.Cancel();Advance $s 6;Assert ($s.Events.Count -eq 0) 'interrupted tea never records a habit'
$s.Interact('tea',1);Advance $s 6;Assert (@($s.Events|Where-Object {$_.Kind -eq 'habit' -and $_.Character -eq 'slime' -and $_.Value -eq 'tea'}).Count -eq 1) 'completed tea belongs to chosen companion once';$s.Events.Clear();Advance $s 9;Assert ($s.Events.Count -eq 0) 'completed habit not awarded again'
$before=[string]::Join(',',$s.Layout);$s.BeginDrag(0);$ok=$s.EndDrag(450,420);Assert (-not $ok -and [string]::Join(',',$s.Layout) -eq $before) 'central walkway rejects furniture'
$s.BeginDrag(0);$ok=$s.EndDrag(755,535);Assert ($ok -and $s.Layout[5] -eq 'hammock') 'drag swaps valid furniture slots'
$s.BeginDrag(6);$ok=$s.EndDrag(0,0);Assert (-not $ok -and $s.BoxX -eq 650) 'invalid box drop restores origin'
$null=$s.StartStory('box');Advance $s 7;$s.BeginDrag(6);$t=$s.Time;Advance $s 3;Assert ($s.Time -eq $t) 'drag freezes ongoing story';$null=$s.EndDrag(500,430);Assert ($s.Branch -eq 'box') 'moving the hiding box changes story'
foreach($route in @('forest','pond')){
    $s.Events.Clear();$s.StartExpedition($route);Advance $s 6;Assert ($s.Choices.Length -eq 2) "$route stops for a meaningful choice"
    for($i=0;$i -lt 3;$i++){Assert ($s.Choose($i%2)) "$route choice $i accepted";Assert (-not $s.Choose(0)) "$route repeated choice $i rejected";Advance $s 10}
    Assert ($s.ExpeditionComplete -and $s.ExpeditionStep -eq 3 -and @($s.Events|Where-Object Kind -eq 'expedition').Count -eq 1) "$route grants a single completion reward";Advance $s 20;Assert (@($s.Events|Where-Object Kind -eq 'expedition').Count -eq 1) "$route reward cannot repeat"
    $s.Events.Clear();$s.StartExpedition($route);Advance $s 6;$s.Cancel();Advance $s 30;Assert ($s.Events.Count -eq 0) "$route interrupted trip gives no reward"
}
$s=[KalingWorld.Session]::new('ren','slime',10);$s.Auto=$false;$s.PointerX=760;$s.Interact('ball',0);$s.SelectedActor=1;Advance $s 20
Assert (@($s.Events|Where-Object {$_.Kind -eq 'habit' -and $_.Character -eq 'ren' -and $_.Value -eq 'ball'}).Count -eq 1 -and $s.Actors[1].X -eq 580 -and $s.Actors[0].X -gt 650) 'changing selection does not transfer an ongoing chase or its reward'
$s.Cancel();$s.Events.Clear();$s.SelectedActor=0;$null=$s.StartStory('snack');$s.Interact('bait',1);Advance $s 10
Assert (@($s.Events|Where-Object {$_.Kind -eq 'meal' -and $_.Character -eq 'ren'}).Count -eq 1 -and @($s.Events|Where-Object {$_.Kind -eq 'meal' -and $_.Character -eq 'slime'}).Count -eq 0) 'story bait feeds the actor visibly eating'
$s.Cancel();$s.Actors[0].X=800;$s.Actors[0].TargetX=800;$s.Interact('signature',0);$s.Actors[0].TargetX=120;Advance $s 4
Assert ($s.Actors[0].Moving -and $s.Actors[0].Action -eq 'signature') 'approaching actor keeps pending gesture'
Advance $s 2;Assert ($s.Actors[0].Age -lt 2 -and $s.Actors[0].Action -eq 'signature') 'gesture preparation begins after arrival'
$w=New-WorldState;Assert ($w.companion -eq '' -and $w.layout.Count -eq 6) 'fresh world is solo with six furniture slots'
$frequencies=@();foreach($tea in @(0,50)){$auto=[KalingWorld.Session]::new('ren','',123);$auto.Habits['ren']=[int[]]@(0,$tea,0,0);$count=0;for($i=0;$i -lt 300;$i++){$auto.Cancel();$auto.NextAuto=$auto.Time;$auto.LastStory='';$auto.Step(.1);if($auto.Story -eq 'tea'){$count++}};$frequencies+=,$count}
Assert ($frequencies[1] -gt $frequencies[0]+25) 'observed tea habit materially changes autonomous choices'
$null=Add-WorldHabit $w 'slime' 'ball';$w.collections.stone=1;$w.layout[0]='stone';$w.companion='slime'
$round=Read-WorldState ($w|ConvertTo-Json -Depth 9|ConvertFrom-Json);Assert ($round.habits.slime.ball -eq 1 -and $round.layout[0] -eq 'stone' -and $round.companion -eq 'slime') 'world survives JSON round trip'
$bad=Read-WorldState ([pscustomobject]@{companion='unknown';boxX=[double]::NaN;layout=@('stone','stone','oops','flowers','flowers','');habits=@{ren=@{pet=-5}}})
Assert ($bad.companion -eq '' -and $bad.boxX -eq 650 -and $bad.layout[0] -eq '' -and $bad.layout[1] -eq '' -and $bad.habits.ren.pet -eq 0) 'invalid world fields reset locally'
if($OutputDirectory){
    [void][IO.Directory]::CreateDirectory($OutputDirectory)
    $migration=Join-Path $OutputDirectory 'legacy';$old=New-PetState;$old.Remove('world');$old.character='kaling';$old.outfit='hoodie';$old.left=342;$old.top=120;$old.pomo.remaining=947;$old.play.characters.kaling.fish[2]=4;Write-PetState $old $migration
    $upgraded=Read-PetState $migration
    Assert ($upgraded.character -eq 'kaling' -and $upgraded.outfit -eq 'hoodie' -and $upgraded.left -eq 342 -and $upgraded.pomo.remaining -eq 947 -and $upgraded.play.characters.kaling.fish[2] -eq 4 -and $upgraded.world.companion -eq '') 'legacy schema-3 file gains world without losing costume timer position or collections'
    $upgraded.care.characters.slime.messes=@(@{id='saved-world-mess';place='world';x=250.0;y=443.0});Write-PetState $upgraded $migration;$round=Read-PetState $migration
    Assert ($round.care.characters.slime.messes[0].place -eq 'world' -and (Test-Path (Join-Path $migration 'settings.json.bak'))) 'world mess and atomic backup survive real save IO'
    @{ok=$true;count=$checks.Count;checks=@($checks)}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $OutputDirectory 'world-model.json') -Encoding UTF8
}
Write-Output ("PASS: "+$checks.Count+' world model checks')
