param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\lib\Pet.State.ps1')
if(-not $OutputDirectory){$OutputDirectory=Join-Path ([IO.Path]::GetTempPath()) ('Kaling-State-'+[guid]::NewGuid().ToString('N'))}
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$checks=[Collections.Generic.List[string]]::new()
function Assert($Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$checks.Add($Name)}
$s=New-PetState
Assert ($s.focusMinutes -eq 25 -and $s.pomo.remaining -eq 1500) 'default focus duration'
Start-Pomodoro $s;$null=Step-Pomodoro $s 2.5
Assert ($s.pomo.remaining -eq 1497.5) 'monotonic countdown'
Pause-Pomodoro $s;$null=Step-Pomodoro $s 3
Assert ($s.pomo.remaining -eq 1497.5) 'paused timer does not advance'
Start-Pomodoro $s;$event=Step-Pomodoro $s 3600
Assert ($event -eq 'suspended' -and $s.pomo.status -eq 'paused' -and $s.pomo.remaining -eq 1497.5 -and $s.pomo.total -eq 0) 'sleep gap pauses without credit'
Reset-Pomodoro $s
for($round=1;$round -le 4;$round++){
    Start-Pomodoro $s;$s.pomo.remaining=1;$event=Step-Pomodoro $s 1.1
    $expected=if($round -eq 4){'long'}else{'short'}
    Assert ($event -eq 'focus' -and $s.pomo.phase -eq $expected -and $s.pomo.status -eq 'ready' -and $s.pomo.total -eq $round) "round $round requires manual rest start"
    $event=Step-Pomodoro $s 1
    Assert ($event -eq 'none') "round $round does not auto-start"
    Start-Pomodoro $s;$s.pomo.remaining=1;$event=Step-Pomodoro $s 1.1
    Assert ($event -eq $expected -and $s.pomo.phase -eq 'focus' -and $s.pomo.status -eq 'ready') "round $round rest completes"
}
$s.mode='follow';$s.left=-1500;$s.top=80;$s.scale=2;$s.quiet=$true;$s.focusMinutes=42
Start-Pomodoro $s;$s.pomo.remaining=321
Write-PetState $s $OutputDirectory
$read=Read-PetState $OutputDirectory
Assert ($read.pomo.status -eq 'paused' -and $read.pomo.remaining -eq 321 -and $read.pomo.total -eq 4) 'restart restores paused timer'
Assert ($read.left -eq -1500 -and $read.scale -eq 2 -and $read.quiet -and $read.mode -eq 'follow' -and $read.focusMinutes -eq 42) 'preferences round-trip'
Write-PetState $read $OutputDirectory
Assert (Test-Path (Join-Path $OutputDirectory 'settings.json.bak')) 'atomic replacement creates backup'
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'settings.json'),'{ broken')
$read=Read-PetState $OutputDirectory
Assert ($read.scale -eq 1.5 -and @(Get-ChildItem $OutputDirectory -Filter '*.corrupt-*').Count -eq 1) 'corrupt state is preserved and defaults restored'
$bad=New-PetState;$bad.pomo.remaining='NaN';Write-PetState $bad $OutputDirectory
$read=Read-PetState $OutputDirectory
Assert ($read.pomo.remaining -eq 1500) 'invalid timer input rejected'
Assert ((Get-ClickAction $true $true 0.2) -eq 'drag') 'drag suppresses click and double-click'
Assert ((Get-ClickAction $false $true 0.2) -eq 'jump') 'double-click wins over head pet'
Assert ((Get-ClickAction $false $false 0.2) -eq 'pet') 'head click maps to petting'
Assert ((Get-ClickAction $false $false 0.8) -eq 'wave') 'body click maps to waving'
$p=Limit-PetPosition -10000 10000 288 432 @{Left=0;Top=0;Right=1920;Bottom=1080}
Assert ($p.left -eq 0 -and $p.top -eq 648) 'disconnected monitor position clamped'
$p=Limit-PetPosition -1600 -200 192 328 @{Left=-1920;Top=-300;Right=0;Bottom=780}
Assert ($p.left -eq -1600 -and $p.top -eq -200) 'negative-coordinate monitor preserved'
Assert ((Get-Story 23 'happy').mood -eq 'sleepy') 'late-night story'
Assert ((Get-Story 9 'happy').text -match '早安') 'morning story'
$wardrobe=New-PetState;$wardrobe.outfit='pajamas';Write-PetState $wardrobe $OutputDirectory
$read=Read-PetState $OutputDirectory;Assert ($read.outfit -eq 'pajamas') 'outfit survives restart'
$wardrobe.outfit='missing';Write-PetState $wardrobe $OutputDirectory
$read=Read-PetState $OutputDirectory;Assert ($read.outfit -eq 'uniform') 'unknown outfit falls back to uniform'
$wardrobe.Remove('outfit');$wardrobe.focusMinutes=32;Write-PetState $wardrobe $OutputDirectory
$read=Read-PetState $OutputDirectory;Assert ($read.outfit -eq 'uniform' -and $read.focusMinutes -eq 32) 'v1.1 settings migrate without losing preferences'
$old=New-PetState;$old.Remove('home');$old.outfit='hoodie';$old.mode='wander';Write-PetState $old $OutputDirectory
$read=Read-PetState $OutputDirectory
Assert ($read.outfit -eq 'hoodie' -and $read.mode -eq 'wander' -and $read.home.ball.u -eq .77) 'v1.2 settings gain house defaults without losing outfit or mode'
$read.home=@{left=-600;top=42;ball=@{u=.20;v=.33};box=@{u=.45;v=.35}};Write-PetState $read $OutputDirectory
$again=Read-PetState $OutputDirectory
Assert ($again.home.left -eq -600 -and $again.home.ball.u -eq .20 -and $again.home.box.u -eq .45) 'house and both moved toys round-trip together'
$badHome=Read-HomeState @{left=[double]::NaN;top=$true;ball=@{u=-1;v=3};box=@{u=.18;v=.7}}
Assert ($null -eq $badHome.left -and $null -eq $badHome.top -and $badHome.ball.u -eq .77 -and $badHome.box.v -eq .33) 'invalid house coordinates fall back field by field'
$overlap=Read-HomeState @{ball=@{u=.45;v=.45};box=@{u=.45;v=.45}}
Assert (Test-RoomDrop 'ball' $overlap.ball.u $overlap.ball.v $overlap) 'overlapping saved toys recover safely'
foreach($uv in @(@(.06,.06),@(.94,.94),@(.45,.38))){$point=Get-RoomPoint $uv[0] $uv[1];$back=Get-RoomUV $point.x $point.y;Assert ([math]::Abs($back.u-$uv[0]) -lt .000001 -and [math]::Abs($back.v-$uv[1]) -lt .000001) 'room projection round-trip'}
foreach($uv in @(@(-.1,.5),@(.5,1.1),@(.18,.65),@(.75,.20),@(.75,.65),@(.21,.10))){Assert (-not (Test-RoomFloor $uv[0] $uv[1])) 'walls and fixed furniture reject toy placement'}
Assert (-not (Test-RoomDrop 'ball' .20 .33 (New-HomeState))) 'toy overlap rejected'
Assert (-not (Test-RoomDrop 'box' .08 .40 (New-HomeState))) 'box footprint cannot hang over room edge'
Assert (-not (Test-RoomDrop 'box' .35 .65 (New-HomeState))) 'box footprint cannot overlap bed even when center is free'
Assert (-not (Test-RoomDrop 'ball' .92 .92 (New-HomeState))) 'ball radius stays within floor boundary'
$targets=@(@{u=.45;v=.45},@{u=.38;v=.63},@{u=.70;v=.40},@{u=.40;v=.18},@{u=.54;v=.67},@{u=.77;v=.90},@{u=.20;v=.33},@{u=.06;v=.40},@{u=.94;v=.94})
foreach($start in $targets){foreach($goal in $targets){$path=@(Get-RoomPath $start $goal);$valid=$path.Count -gt 0;$previous=$start;foreach($node in $path){$valid=$valid -and (Test-RoomSegment $previous $node);$previous=$node};Assert $valid 'furniture routes avoid every obstacle including endpoint connectors'}}
@{ok=$true;checks=@($checks);count=$checks.Count} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutputDirectory 'state-tests.json') -Encoding UTF8
Write-Output "PASS: $($checks.Count) state checks"
