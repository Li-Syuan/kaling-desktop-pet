param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\lib\Pet.State.ps1')
if(-not $OutputDirectory){$OutputDirectory=Join-Path ([IO.Path]::GetTempPath()) ('Kaling-Monsters-'+[guid]::NewGuid().ToString('N'))}
[void][IO.Directory]::CreateDirectory($OutputDirectory);$checks=[Collections.Generic.List[string]]::new()
function Assert($Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$checks.Add($Name)}
$s=New-PetState;Assert ($s.character -eq 'ren' -and $s.care.characters.Count -eq 5) 'Ren remains default with five independent care slots'
$s.care.characters.ren.training=70;$s.care.characters.kaling.happiness=35;$s.character='kaling';$s.outfit='hoodie'
$s.characterOutfits.Remove('mushroom');$s.characterOutfits.Remove('ribbon-pig');$s.care.characters.Remove('mushroom');$s.care.characters.Remove('ribbon-pig');$s.characterOutfits.Remove('slime');$s.care.characters.Remove('slime')
Write-PetState $s $OutputDirectory;$s=Read-PetState $OutputDirectory
Assert ($s.character -eq 'kaling' -and $s.outfit -eq 'hoodie' -and $s.care.characters.ren.training -eq 70 -and $s.care.characters.kaling.happiness -eq 35) 'v1.4 settings retain character outfit and care'
Assert ($s.care.characters.mushroom.satiety -eq 60 -and $s.care.characters['ribbon-pig'].messes.Count -eq 0) 'old save adds healthy monster defaults without offline debt'
Assert ($s.care.characters.slime.satiety -eq 60 -and $s.care.characters.slime.messes.Count -eq 0) 'old save initializes Slime independently'
foreach($id in @('mushroom','ribbon-pig','slime')){
 $s.character=$id;$s.outfit='original';$s.left=-600;$s.mode='follow';$s.scale=2;$s.pomo.remaining=100;$s.home.box=@{u=.45;v=.45}
 $c=$s.care.characters[$id];$c.training=60;$c.meals=2;$c.digest=300;$c.messes=@(@{id=$id+'-mess';place='desktop';x=-500.0;y=250.0})
 Write-PetState $s $OutputDirectory;$s=Read-PetState $OutputDirectory
 Assert ($s.character -eq $id -and $s.outfit -eq 'original') "$id selection survives restart"
 Assert ($s.left -eq -600 -and $s.mode -eq 'follow' -and $s.scale -eq 2 -and $s.pomo.remaining -eq 100 -and $s.home.box.u -eq .45) "$id retains geometry preferences timer and house"
 Assert ($s.care.characters[$id].training -eq 60 -and $s.care.characters[$id].digest -eq 300 -and $s.care.characters[$id].messes[0].id -eq ($id+'-mess')) "$id care persists without advancing offline"
 $s.outfit='missing';Write-PetState $s $OutputDirectory;$s=Read-PetState $OutputDirectory
 Assert ($s.character -eq $id -and $s.outfit -eq 'original') "$id unknown appearance recovers to own default"
}
$s.care.characters.mushroom.happiness=12
Assert ($s.care.characters.slime.happiness -eq 80 -and $s.care.characters['ribbon-pig'].happiness -eq 80 -and $s.care.characters.ren.training -eq 70) 'mutating one care slot never changes the others'
$s.character='ribbon-pig';$s.care.characters['ribbon-pig'].happiness=43;$s.care.characters.mushroom.training=77;$s.characterOutfits.Remove('slime');$s.care.characters.Remove('slime')
Write-PetState $s $OutputDirectory;$s=Read-PetState $OutputDirectory
Assert ($s.character -eq 'ribbon-pig' -and $s.care.characters['ribbon-pig'].happiness -eq 43 -and $s.care.characters.mushroom.training -eq 77 -and $s.care.characters.slime.satiety -eq 60) 'v1.6 four-character save retains progress while adding Slime'
Assert (Test-Path (Join-Path $OutputDirectory 'settings.json.bak')) 'atomic backup preserved'
@{ok=$true;count=$checks.Count;checks=@($checks)}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $OutputDirectory 'monsters-state.json') -Encoding UTF8
Write-Output "PASS: $($checks.Count) monster state checks"
