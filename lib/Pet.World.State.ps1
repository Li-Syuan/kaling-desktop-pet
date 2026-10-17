# Optional schema-3 extension. Only observed interactions affect habits.
function New-WorldState {
    $habits=@{};foreach($d in (Get-PetDefinitions)){$habits[$d.id]=@{pet=0;tea=0;ball=0;tidy=0}}
    return @{version=1;companion='';left=$null;top=$null;layout=@('hammock','flowers','aquarium','leaves','basket','swing');habits=$habits;collections=@{stone=0;shell=0;mushroom=0};trips=0;boxX=650.0;boxY=430.0}
}
function Read-WorldState($Data) {
    $v=New-WorldState;if(-not $Data){return $v};$ids=@((Get-PetDefinitions).id)
    if($Data.companion -in $ids){$v.companion=[string]$Data.companion}
    foreach($key in @('left','top')){if(Test-CareNumber $Data.$key -100000 100000){$v[$key]=[double]$Data.$key}}
    if(Test-CareNumber $Data.boxX 120 780){$v.boxX=[double]$Data.boxX};if(Test-CareNumber $Data.boxY 395 445){$v.boxY=[double]$Data.boxY}
    $valid=@('hammock','flowers','aquarium','leaves','basket','swing','stone','shell','mushroom','')
    if(@($Data.layout).Count -eq 6){$seen=@();for($i=0;$i -lt 6;$i++){$item=[string]$Data.layout[$i];if($item -in $valid -and ($item -eq '' -or $item -notin $seen)){$v.layout[$i]=$item;$seen+=,$item}else{$v.layout[$i]=''}}}
    foreach($id in $ids){foreach($key in @('pet','tea','ball','tidy')){if(Test-CareNumber $Data.habits.$id.$key 0 999){$v.habits[$id][$key]=[int]$Data.habits.$id.$key}}}
    foreach($key in @('stone','shell','mushroom')){if(Test-CareNumber $Data.collections.$key 0 9999){$v.collections[$key]=[int]$Data.collections.$key}}
    if(Test-CareNumber $Data.trips 0 999999){$v.trips=[int]$Data.trips}
    for($i=0;$i -lt 6;$i++){if($v.layout[$i] -in @('stone','shell','mushroom') -and $v.collections[$v.layout[$i]] -lt 1){$v.layout[$i]=''}}
    return $v
}
function Add-WorldHabit($World,[string]$Id,[string]$Kind) {
    if(-not $World.habits.ContainsKey($Id) -or -not $World.habits[$Id].ContainsKey($Kind)){return $false}
    $World.habits[$Id][$Kind]=[math]::Min(999,$World.habits[$Id][$Kind]+1);return $true
}
function Get-WorldHabitText($World,[string]$Id) {
    $h=$World.habits[$Id];$labels=@{pet='摸摸陪伴';tea='一起喝茶';ball='玩球';tidy='一起整理'}
    $top=@('pet','tea','ball','tidy')|Sort-Object {$h[$_]} -Descending|Select-Object -First 1
    $prefix=if($h[$top] -ge 3){'最近喜歡'+$labels[$top]+'。'}else{'還在慢慢認識彼此。'}
    return $prefix+' 摸摸 '+$h.pet+' · 喝茶 '+$h.tea+' · 玩球 '+$h.ball+' · 整理 '+$h.tidy
}
