param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\lib\Pet.State.ps1')
Add-Type -Path (Join-Path $PSScriptRoot '..\lib\Pet.Play.Model.cs')
if(-not $OutputDirectory){$OutputDirectory=Join-Path ([IO.Path]::GetTempPath()) ('Kaling-Play-'+[guid]::NewGuid().ToString('N'))}
[void][IO.Directory]::CreateDirectory($OutputDirectory);$checks=[Collections.Generic.List[string]]::new()
function Assert($Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$checks.Add($Name)}
function Advance($s,[double]$Seconds){for($n=0;$n -lt [math]::Ceiling($Seconds/.05);$n++){$s.Step(.05)}}
$state=New-PetState
Assert ($state.play.characters.Count -eq 5 -and $state.character -eq 'ren') 'five independent play records and Ren remains default'
$c=$state.play.characters.slime;$s=[KalingPlay.Session]::new('bubble',42);$s.Start();Assert ($s.Items.Count -eq 7 -and $s.Remaining -eq 30) 'bubble round starts with seven targets and thirty seconds'
$target=$s.Items[0];$s.Click($target.X,$target.Y);Assert ($s.Caught -eq 1 -and $s.Score -gt 0 -and $s.Chasing -and $s.ActorX -eq 400) 'bubble hit scores and requests a continuous chase without teleporting'
$score=$s.Score;$s.Click(-100,-100);Assert ($s.Score -eq $score -and $s.Combo -eq 0) 'miss resets combo without free points'
$s.Paused=$true;$target=$s.Items[1];$s.Click($target.X,$target.Y);$s.Step(.5);Assert ($s.Score -eq $score -and $s.Time -eq 0) 'pause blocks both input and elapsed game time';$s.Paused=$false
$s.Step(100);Assert ($s.Time -eq 0) 'suspend gap is not credited'
$s.Step(.05);Assert ([math]::Abs($s.ActorX-400) -le 21.5) 'bubble movement is bounded by real elapsed time'
while($s.Chasing){$s.Step(.05)};Assert ($s.ActionRow -eq 4 -and $s.ActorX -eq $s.TargetX) 'bubble chase arrives and jumps'
Advance $s 30.1;Assert ($s.Completed -and $s.Result -eq 'bubble') 'bubble session completes on deadline'
Assert (Complete-PlaySession $c $s) 'completed session records score and diary';Assert (-not (Complete-PlaySession $c $s) -and $c.games -eq 1) 'same result cannot award twice'
Assert ($state.play.characters.ren.games -eq 0 -and $c.stamps -contains 'first') 'awards belong only to the active character'
$s=[KalingPlay.Session]::new('snack',7);$s.Start();$s.Move(-100);Assert ($s.ActorX -eq 65) 'catcher clamps to left edge';$s.Move(900);Assert ($s.ActorX -eq 735) 'catcher clamps to right edge'
for($n=0;$n -lt 610;$n++){$food=@($s.Items|Where-Object {$_.Kind -eq 0 -and -not $_.Removed}|Sort-Object Y -Descending);if($food.Count){$s.Move($food[0].X)};$s.Step(.05)}
Assert ($s.Completed -and $s.Caught -gt 10 -and $s.Score -gt 0) 'moving catcher can complete a genuine falling-food round'
$s=[KalingPlay.Session]::new('snack',1);$s.Start();$s.Score=50;$stone=[KalingPlay.Item]::new();$stone.X=400;$stone.Y=340;$stone.Speed=150;$stone.Kind=1;$s.Items.Add($stone);$s.Step(.1)
Assert ($s.Score -eq 30 -and $s.ActionRow -eq 5) 'stone collision penalizes once with a reaction'
$s=[KalingPlay.Session]::new('boxes',5);$s.Start();$s.Click(220,310);Assert ($s.ChosenBox -eq -1) 'cannot guess while the hidden position is being shown'
for($round=0;$round -lt 3;$round++){for($n=0;$n -lt 100 -and $s.Phase -ne 'guess';$n++){$s.Step(.05)};Assert ($s.Phase -eq 'guess' -and @($s.Boxes|Select-Object -Unique).Count -eq 3) "box round $round shuffles into three separate slots";$s.Click($s.Boxes[$s.WinningBox],310);Assert $s.LastCorrect "box round $round resolves the actual hidden box";Advance $s 1.55}
Assert ($s.Completed -and $s.Wins -eq 3 -and $s.Score -eq 300) 'three-round box game finishes';$null=Complete-PlaySession $c $s;Assert ($c.stamps -contains 'boxes') 'perfect box game unlocks the correct stamp'
$s=[KalingPlay.Session]::new('fishing',3);$s.Start();$s.Pull();Assert ($s.Result -eq 'early' -and $s.Fish -eq -1) 'early fishing pull has no fish'
Assert (-not (Complete-PlaySession $c $s)) 'failed fishing does not invent a collection entry'
$s=[KalingPlay.Session]::new('fishing',3);$s.Start();for($n=0;$n -lt 150 -and $s.Phase -ne 'bite';$n++){$s.Step(.05)};$s.Pull();Assert ($s.Completed -and $s.Fish -in @(0,1,2,3)) 'pull within bite window catches a real species'
$fish=$s.Fish;$null=Complete-PlaySession $c $s;$s.Pull();Assert ($c.fish[$fish] -eq 1 -and $c.stamps -contains 'fish') 'fish is collected exactly once'
$s=[KalingPlay.Session]::new('fishing',3);$s.Start();Advance $s 8;Assert ($s.Result -eq 'missed') 'unattended bite eventually escapes'
$s=[KalingPlay.Session]::new('rhythm',1);$s.Start()
for($beat=0;$beat -lt 10;$beat++){$target=1+$beat*1.25;while($s.Time -lt $target-.001){$s.Step([math]::Min(.05,$target-$s.Time))};$s.Click(400,160);$score=$s.Score;$s.Click(400,160);Assert ($s.Score -eq $score) "rhythm beat $beat cannot be scored twice"};Advance $s .6
Assert ($s.Completed -and $s.Score -eq 1000 -and $s.Perfect -eq 10) 'ten perfectly timed beats yield full score';$null=Complete-PlaySession $c $s;Assert ($c.stamps -contains 'rhythm') 'rhythm mastery unlocks stamp'
$s=[KalingPlay.Session]::new('picnic',2);$s.Food='pudding';$s.Start();Advance $s 2.2;Assert ($s.Phase -eq 'eat' -and $s.ActionRow -eq 13) 'picnic plays the selected pudding animation';Advance $s 5.1;Assert ($s.Phase -eq 'tea' -and $s.ActionRow -eq 14) 'picnic continues into tea';Advance $s 4.1;Assert ($s.Phase -eq 'clouds') 'picnic includes cloud watching';Advance $s 5;Assert ($s.Phase -eq 'nap' -and $s.ActionRow -eq 16) 'picnic settles into sleep';Advance $s 4
Assert ($s.Completed -and (Complete-PlaySession $c $s) -and $c.picnics -eq 1) 'picnic records only after the complete sequence'
foreach($mode in @('bubble','snack','boxes','fishing','rhythm','picnic')){$s=[KalingPlay.Session]::new($mode,4);$s.Start();$s.Cancel();Advance $s 40;Assert (-not $s.Completed -and -not (Complete-PlaySession $c $s)) "$mode cancellation cannot award a result"}
Assert (-not (Plant-PlaySeed $c -1 0) -and -not (Plant-PlaySeed $c 0 9)) 'invalid seed and pot rejected'
for($seed=0;$seed -lt 3;$seed++){
 Assert (Plant-PlaySeed $c $seed $seed) "seed $seed planted into its own pot";Assert (-not (Plant-PlaySeed $c $seed $seed)) 'occupied pot cannot be overwritten';Assert (Water-PlayPlant $c $seed) 'first watering accepted';Assert (-not (Water-PlayPlant $c $seed)) 'rapid duplicate watering rejected'
 $before=$c.garden[$seed].growth;Step-PlayGarden $c 1 $true;Step-PlayGarden $c 100 $false;Assert ($c.garden[$seed].growth -eq $before) 'pause and suspend do not advance plants'
 for($n=0;$n -lt 245;$n++){Step-PlayGarden $c 1 $false;if($c.garden[$seed].cooldown -le 0){$null=Water-PlayPlant $c $seed}}
 Assert (Harvest-PlayPlant $c $seed) "mature flower $seed harvests";Assert (-not (Harvest-PlayPlant $c $seed)) 'empty pot cannot harvest twice'
}
Assert ($c.stamps -contains 'florist' -and ($c.flowers -join ',') -eq '1,1,1') 'three flowers create a genuine complete collection'
$d=New-PlayCharacter;Add-PlayEvent $d 'meal-cookie' '餅乾' ([datetime]'2026-10-17');Add-PlayEvent $d 'meal-cookie' '餅乾' ([datetime]'2026-10-17');Assert ($d.journal.Count -eq 1) 'same daily care event is not spammed'
foreach($day in 18..21){Add-PlayEvent $d 'meal-cookie' '餅乾' ([datetime]('2026-10-'+$day))};Assert ($d.stamps -contains 'days' -and $d.days.Count -eq 5) 'five actual interaction dates unlock companion stamp'
$state.play.weather='snow';$state.play.frame='rose';$state.care.characters.ren.training=55;Write-PetState $state $OutputDirectory;$read=Read-PetState $OutputDirectory
Assert ($read.play.weather -eq 'snow' -and $read.play.frame -eq 'rose' -and $read.play.characters.slime.best.rhythm -eq 1000 -and $read.care.characters.ren.training -eq 55) 'play progress and old care survive restart'
$state.Remove('play');Write-PetState $state $OutputDirectory;$read=Read-PetState $OutputDirectory;Assert ($read.play.characters.Count -eq 5 -and $read.care.characters.ren.training -eq 55) 'v1.7 save gains play defaults without resetting old care'
$bad=New-PlayState;$bad.weather='bad';$bad.characters.ren.photos=@(@{file='../outside.png';caption='x';day='2026-10-17'});$bad.characters.ren.best.bubble=[double]::NaN;$clean=Read-PlayState $bad
Assert ($clean.weather -eq 'sun' -and $clean.characters.ren.photos.Count -eq 0 -and $clean.characters.ren.best.bubble -eq 0) 'invalid photo paths numeric data and weather fall back safely'
@{ok=$true;count=$checks.Count;checks=@($checks)}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutputDirectory 'play-model.json') -Encoding UTF8
Write-Output "PASS: $($checks.Count) play model checks"
