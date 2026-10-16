param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../lib/Pet.State.ps1')
if(-not $OutputDirectory){$OutputDirectory=Join-Path ([IO.Path]::GetTempPath()) ('Care-Model-'+[guid]::NewGuid().ToString('N'))}
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$checks=[Collections.Generic.List[string]]::new()
function Assert($Ok,[string]$Name){if(-not $Ok){throw "FAIL: $Name"};$checks.Add($Name)}
function Advance($C,[int]$Seconds,[bool]$Paused=$false,[bool]$Sleeping=$false){for($i=0;$i -lt $Seconds;$i++){$null=Step-CareModel $C 1 $Paused $Sleeping}}
$s=New-PetState
Assert ($s.version -eq 3 -and $s.character -eq 'ren' -and $s.outfit -eq 'original') 'Ren is the first-run default'
$c=$s.care.characters.ren
Assert (Complete-CareMeal $c 'cookie' 480) 'completed cookie accepted'
Assert ($c.satiety -eq 80 -and $c.meals -eq 1 -and $c.digest -eq 480) 'cookie has nutrition and digestion'
Advance $c 479;Assert ($c.urge -eq -1) 'no early urge'
$event=Step-CareModel $c 1;Assert ($event -eq 'warning' -and $c.urge -eq 30) 'warning begins after digestion'
Advance $c 29;Assert ($c.urge -eq 1) 'warning lasts thirty active seconds'
Assert ((Step-CareModel $c 1) -eq 'due') 'unattended warning reaches accident'
$mess=@{id='test1';place='desktop';x=-1500.0;y=300.0}
Assert (Complete-CareToilet $c $false $mess) 'accident commits one mess'
Assert ($c.messes.Count -eq 1 -and $c.cooldown -eq 600 -and $c.training -eq 20) 'accident cooldown without training punishment'
Assert (-not (Complete-CareToilet $c $true)) 'completion is idempotent'
$c.satiety=60;$null=Complete-CareMeal $c 'pudding' 480;Advance $c 480
Assert ($c.urge -lt 0 -and $c.cooldown -eq 120) 'second meal cannot bypass ten-minute interval'
Advance $c 120;Assert ($c.urge -eq 30) 'queued digestion resumes when interval ends'
Assert (Complete-CareToilet $c $true) 'guided toilet succeeds'
Assert ($c.training -eq 30 -and $c.messes.Count -eq 1) 'guided success trains without adding mess'
for($i=0;$i -lt 12;$i++){$c.urge=30;$c.meals=1;$null=Complete-CareToilet $c $true}
Assert ($c.training -eq 90) 'training capped with occasional accidents retained'
$c.urge=30;$c.meals=1;$null=Complete-CareToilet $c $false
Assert ($c.training -eq 90 -and $c.messes.Count -eq 1) 'autonomous toilet does not count as guided training'
$c=New-CharacterCare;$c.satiety=90;Assert (-not (Complete-CareMeal $c 'cookie')) 'full stomach refuses food'
Assert (Complete-CareMeal $c 'tea') 'tea available when full';Assert ($c.meals -eq 0) 'tea does not create poop'
$c.satiety=0;1..3|ForEach-Object {$null=Complete-CareMeal $c 'cookie'};Assert (-not (Complete-CareMeal $c 'cookie')) 'digestive queue bounded'
$c.messes=@($mess,@{id='test2';place='room';u=.45;v=.45},@{id='test3';place='desktop';x=20;y=30});$c.urge=0
Assert ((Step-CareModel $c 1) -eq 'full' -and -not (Complete-CareToilet $c $false @{id='test4'})) 'three-mess cap is enforced'
$before=$c|ConvertTo-Json -Depth 8;Advance $c 1000 $true
Assert (($c|ConvertTo-Json -Depth 8) -eq $before) 'focus hidden quiet disabled pauses every care clock'
$null=Step-CareModel $c 3600;Assert (($c|ConvertTo-Json -Depth 8) -eq $before) 'suspend gap is never credited'
$c=New-CharacterCare;$c.energy=10;Advance $c 60 $false $true
Assert ($c.energy -eq 40) 'sleep restores energy over time'
Advance $c 100000;Assert ($c.satiety -eq 0 -and $c.energy -eq 0 -and $c.hygiene -ge 0 -and $c.happiness -ge 0) 'neglect clamps at zero without death or sickness'
Assert (-not (Test-CarePlay $c)) 'low needs suppress autonomous play'
$s=New-PetState;$s.care.characters.ren.messes=@($mess);$s.care.characters.ren.training=70;$s.care.characters.ren.digest=345;$s.care.characters.ren.meals=2
Write-PetState $s $OutputDirectory;$read=Read-PetState $OutputDirectory
Assert ($read.care.characters.ren.training -eq 70 -and $read.care.characters.ren.digest -eq 345 -and $read.care.characters.ren.messes[0].x -eq -1500) 'care and desktop mess round-trip without elapsed offline time'
Assert ($read.care.characters.kaling.training -eq 20 -and $read.care.characters.kaling.messes.Count -eq 0) 'characters keep independent care'
$read.character='kaling';$read.outfit='hoodie';Write-PetState $read $OutputDirectory;$read=Read-PetState $OutputDirectory
Assert ($read.character -eq 'kaling' -and $read.outfit -eq 'hoodie') 'later launches remember chosen character'
foreach($version in @(1,2)){
 $legacy=New-PetState;$legacy.version=$version;$legacy.character='kaling';$legacy.outfit='pajamas';$legacy.characterOutfits.kaling='pajamas';$legacy.left=-1200;$legacy.scale=2;$legacy.pomo.remaining=300;$legacy.pomo.status='running';$legacy.Remove('care')
 [IO.File]::WriteAllText((Join-Path $OutputDirectory 'settings.json'),($legacy|ConvertTo-Json -Depth 9),[Text.UTF8Encoding]::new($false));$read=Read-PetState $OutputDirectory
 Assert ($read.version -eq 3 -and $read.character -eq 'ren' -and $read.characterOutfits.kaling -eq 'pajamas' -and $read.left -eq -1200 -and $read.scale -eq 2 -and $read.pomo.remaining -eq 300 -and $read.pomo.status -eq 'paused') "v$version migrates to Ren while retaining preferences outfit and timer"
}
$bad=Read-CareState @{enabled='false';characters=@{ren=@{satiety=[double]::NaN;energy=$true;meals=99;training=999;messes=@(@{id='bad';place='desktop';x='oops';y=5},@{id='ok';place='room';u=.45;v=.45},@{id='ok';place='room';u=.45;v=.45})}}}
Assert ($bad.enabled -and $bad.characters.ren.satiety -eq 60 -and $bad.characters.ren.energy -eq 85 -and $bad.characters.ren.training -eq 20 -and $bad.characters.ren.messes.Count -eq 1) 'invalid care data repaired field by field and duplicate IDs rejected'
foreach($goal in @(@{u=.45;v=.24},@{u=.34;v=.91})){
 foreach($start in @(@{u=.45;v=.45},@{u=.38;v=.63},@{u=.7;v=.4},@{u=.54;v=.67},@{u=.77;v=.9})){
  $path=@(Get-RoomPath $start $goal);$prev=$start;$valid=$path.Count -gt 0;foreach($p in $path){$valid=$valid -and (Test-RoomSegment $prev $p);$prev=$p};Assert $valid 'new care fixtures reachable without crossing furniture'
 }
}
Assert (-not (Test-RoomDrop 'box' .44 .10 (New-HomeState))) 'toys cannot overlap privacy screen'
Assert (-not (Test-RoomDrop 'ball' .14 .92 (New-HomeState))) 'toys cannot overlap bathtub'
@{ok=$true;count=$checks.Count;checks=@($checks)}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutputDirectory 'care-model.json') -Encoding UTF8
Write-Output "PASS: $($checks.Count) care model checks"
