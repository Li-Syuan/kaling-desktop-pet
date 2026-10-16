# Pure care rules: time and random choices are supplied by the caller.
$script:careRules=@{digestMin=480;digestMax=720;warning=30;interval=600;maxMesses=3;maxMeals=3;foodLimit=88}
function New-CharacterCare {
    return @{satiety=60.0;energy=85.0;hygiene=90.0;happiness=80.0;meals=0;digest=-1.0;urge=-1.0;cooldown=0.0;training=20;autoTried=$false;messes=@()}
}
function New-CareState {return @{enabled=$true;characters=@{ren=(New-CharacterCare);kaling=(New-CharacterCare)}}}
function Test-CareNumber($Value,[double]$Min,[double]$Max) {
    return $Value -is [ValueType] -and $Value -isnot [bool] -and -not [double]::IsNaN([double]$Value) -and -not [double]::IsInfinity([double]$Value) -and $Value -ge $Min -and $Value -le $Max
}
function Read-CareState($Data) {
    $result=New-CareState;if($null -eq $Data){return $result}
    if($Data.enabled -is [bool]){$result.enabled=$Data.enabled}
    foreach($id in @('ren','kaling')){
        $src=$Data.characters.$id;$c=$result.characters[$id];if(-not $src){continue}
        foreach($key in @('satiety','energy','hygiene','happiness')){if(Test-CareNumber $src.$key 0 100){$c[$key]=[double]$src.$key}}
        foreach($entry in @(@('meals',0,3),@('digest',-1,720),@('urge',-1,30),@('cooldown',0,600),@('training',20,90))){$key=$entry[0];if(Test-CareNumber $src.$key $entry[1] $entry[2]){$c[$key]=[double]$src.$key}}
        $c.meals=[int][math]::Floor($c.meals);$c.training=[int][math]::Floor($c.training)
        if($c.meals -eq 0){$c.digest=-1.0;$c.urge=-1.0}elseif($c.digest -lt 0 -and $c.urge -lt 0){$c.digest=600.0}
        if($src.autoTried -is [bool]){$c.autoTried=$src.autoTried}
        $seen=@{};foreach($m in @($src.messes)){
            if($c.messes.Count -ge 3){break}
            if($m.id -notmatch '^[a-zA-Z0-9-]{1,40}$' -or $seen.ContainsKey([string]$m.id)){continue}
            if($m.place -eq 'desktop' -and (Test-CareNumber $m.x -100000 100000) -and (Test-CareNumber $m.y -100000 100000)){$c.messes+=@{id=[string]$m.id;place='desktop';x=[double]$m.x;y=[double]$m.y};$seen[[string]$m.id]=$true}
            elseif($m.place -eq 'room' -and (Test-CareNumber $m.u .06 .94) -and (Test-CareNumber $m.v .06 .94) -and (Test-RoomFloor $m.u $m.v)){$c.messes+=@{id=[string]$m.id;place='room';u=[double]$m.u;v=[double]$m.v};$seen[[string]$m.id]=$true}
        }
    };return $result
}
function Test-CareFeed($Care,[string]$Food) {return $Food -eq 'tea' -or ($Care.satiety -lt $careRules.foodLimit -and $Care.meals -lt $careRules.maxMeals)}
function Complete-CareMeal($Care,[string]$Food,[double]$DigestSeconds=600) {
    if(-not (Test-CareFeed $Care $Food)){return $false}
    if($Food -eq 'tea'){$Care.happiness=[math]::Min(100.0,$Care.happiness+8);return $true}
    $amount=if($Food -eq 'pudding'){28}else{20}
    $Care.satiety=[math]::Min(100.0,$Care.satiety+$amount);$Care.happiness=[math]::Min(100.0,$Care.happiness+10);$Care.meals++
    if($Care.digest -lt 0 -and $Care.urge -lt 0){$Care.digest=[math]::Max($careRules.digestMin,[math]::Min($careRules.digestMax,$DigestSeconds))}
    return $true
}
function Step-CareModel($Care,[double]$Delta,[bool]$Paused=$false,[bool]$Sleeping=$false) {
    if($Paused -or $Delta -le 0 -or $Delta -gt 5){return 'none'}
    $Care.satiety=[math]::Max(0.0,$Care.satiety-$Delta/120.0)
    $Care.energy=[math]::Max(0.0,[math]::Min(100.0,$Care.energy+$Delta*$(if($Sleeping){.5}else{-.004})))
    $Care.hygiene=[math]::Max(0.0,$Care.hygiene-$Delta*(.002+$Care.messes.Count*.005))
    $Care.happiness=[math]::Max(0.0,$Care.happiness-$Delta*$(if($Care.satiety -lt 20 -or $Care.hygiene -lt 25){.02}else{.001}))
    $Care.cooldown=[math]::Max(0.0,$Care.cooldown-$Delta)
    if($Care.messes.Count -ge $careRules.maxMesses){return 'full'}
    if($Care.urge -ge 0){$Care.urge=[math]::Max(0.0,$Care.urge-$Delta);if($Care.urge -eq 0){return 'due'};return 'urgent'}
    if($Care.digest -ge 0){$Care.digest=[math]::Max(0.0,$Care.digest-$Delta);if($Care.digest -eq 0 -and $Care.cooldown -eq 0){$Care.digest=-1.0;$Care.urge=[double]$careRules.warning;$Care.autoTried=$false;return 'warning'}}
    return 'none'
}
function Complete-CareToilet($Care,[bool]$Guided,$Mess=$null) {
    if($Care.urge -lt 0 -or ($Mess -and $Care.messes.Count -ge $careRules.maxMesses)){return $false}
    if($Mess){$Care.messes+=,$Mess;$Care.hygiene=[math]::Max(0.0,$Care.hygiene-12);$Care.happiness=[math]::Max(0.0,$Care.happiness-5)}
    elseif($Guided){$Care.training=[math]::Min(90,$Care.training+10);$Care.happiness=[math]::Min(100.0,$Care.happiness+8)}
    $Care.meals=[math]::Max(0.0,$Care.meals-1);$Care.digest=if($Care.meals -gt 0){600.0}else{-1.0};$Care.urge=-1.0;$Care.cooldown=600.0;$Care.autoTried=$false
    return $true
}
function Test-CarePlay($Care) {return $Care.satiety -ge 20 -and $Care.energy -ge 15 -and $Care.hygiene -ge 25}
