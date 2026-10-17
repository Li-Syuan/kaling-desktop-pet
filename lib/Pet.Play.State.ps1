# Save-model helpers stay independent of WPF and elapsed wall-clock time.
$script:playStampNames=@{first='初次一起玩';bubbles='泡泡獵人';snacks='點心接接王';boxes='找人高手';fish='第一尾小魚';aquarium='四色魚冊';flower='第一朵花';florist='三色小花園';rhythm='節奏默契';picnic='草地午後';photo='第一張合照';days='五日陪伴'}
function New-PlayPot {return @{seed=-1;growth=0.0;water=0.0;cooldown=0.0}}
function New-PlayCharacter {
    return @{best=@{bubble=0;snack=0;boxes=0;rhythm=0};fish=@(0,0,0,0);flowers=@(0,0,0);garden=@((New-PlayPot),(New-PlayPot),(New-PlayPot));journal=@();stamps=@();days=@();photos=@();games=0;picnics=0}
}
function New-PlayState {
    $characters=@{};foreach($d in (Get-PetDefinitions)){$characters[$d.id]=New-PlayCharacter}
    return @{version=1;weather='sun';frame='cream';characters=$characters}
}
function Read-PlayNumber($Value,[double]$Default,[double]$Maximum) {
    if($Value -isnot [ValueType] -or $Value -is [bool]){return $Default}
    $n=[double]$Value;if([double]::IsNaN($n) -or [double]::IsInfinity($n) -or $n -lt 0 -or $n -gt $Maximum){return $Default};return $n
}
function Read-PlayState($Data) {
    $result=New-PlayState;if(-not $Data){return $result}
    if($Data.weather -in @('sun','rain','snow','night')){$result.weather=[string]$Data.weather}
    if($Data.frame -in @('cream','rose','mint')){$result.frame=[string]$Data.frame}
    foreach($id in @($result.characters.Keys)){
        $old=$Data.characters.$id;if(-not $old){continue};$c=$result.characters[$id]
        foreach($key in @('bubble','snack','boxes','rhythm')){$c.best[$key]=[int](Read-PlayNumber $old.best.$key 0 1000000)}
        for($i=0;$i -lt 4;$i++){if($old.fish -and $i -lt $old.fish.Count){$c.fish[$i]=[int](Read-PlayNumber $old.fish[$i] 0 100000)}}
        for($i=0;$i -lt 3;$i++){
            if($old.flowers -and $i -lt $old.flowers.Count){$c.flowers[$i]=[int](Read-PlayNumber $old.flowers[$i] 0 100000)}
            if($old.garden -and $i -lt $old.garden.Count){$p=$old.garden[$i];if($p.seed -in @(0,1,2)){$c.garden[$i]=@{seed=[int]$p.seed;growth=(Read-PlayNumber $p.growth 0 240);water=(Read-PlayNumber $p.water 0 180);cooldown=(Read-PlayNumber $p.cooldown 0 20)}}}
        }
        $c.games=[int](Read-PlayNumber $old.games 0 1000000);$c.picnics=[int](Read-PlayNumber $old.picnics 0 1000000)
        foreach($stamp in @($old.stamps)){if($stamp -is [string] -and $playStampNames.ContainsKey($stamp) -and $stamp -notin $c.stamps){$c.stamps+=,$stamp}}
        foreach($day in @($old.days)){if($day -is [string] -and $day -match '^\d{4}-\d{2}-\d{2}$' -and $day -notin $c.days){$c.days+=,$day}};$c.days=@($c.days|Select-Object -Last 90)
        foreach($e in @($old.journal)){
            if($e -and $e.text -is [string] -and $e.text.Length -le 180 -and $e.day -match '^\d{4}-\d{2}-\d{2}$' -and $e.key -is [string] -and $e.key.Length -le 120){$c.journal+=,@{day=[string]$e.day;key=[string]$e.key;text=[string]$e.text}}
        };$c.journal=@($c.journal|Select-Object -Last 100)
        foreach($photo in @($old.photos)){
            if($photo -and $photo.file -is [string] -and $photo.file -match '^[a-f0-9]{32}\.png$' -and $photo.caption -is [string] -and $photo.caption.Length -le 60 -and $photo.day -match '^\d{4}-\d{2}-\d{2}$'){$c.photos+=,@{file=[string]$photo.file;caption=[string]$photo.caption;day=[string]$photo.day}}
        };$c.photos=@($c.photos|Select-Object -Last 48)
    }
    return $result
}
function Add-PlayEvent($Care,[string]$Key,[string]$Text,[datetime]$Now=[datetime]::Now) {
    $day=$Now.ToString('yyyy-MM-dd');if($day -notin $Care.days){$Care.days+=,$day;$Care.days=@($Care.days|Select-Object -Last 90)}
    if(-not @($Care.journal|Where-Object {$_.day -eq $day -and $_.key -eq $Key}).Count){$Care.journal+=,@{day=$day;key=$Key;text=$Text};$Care.journal=@($Care.journal|Select-Object -Last 100)}
    Update-PlayStamps $Care
}
function Update-PlayStamps($Care) {
    $conditions=@{first=$Care.games -gt 0;bubbles=$Care.best.bubble -ge 200;snacks=$Care.best.snack -ge 150;boxes=$Care.best.boxes -eq 300;fish=(@($Care.fish|Where-Object {$_ -gt 0}).Count -gt 0);aquarium=(@($Care.fish|Where-Object {$_ -gt 0}).Count -eq 4);flower=(@($Care.flowers|Where-Object {$_ -gt 0}).Count -gt 0);florist=(@($Care.flowers|Where-Object {$_ -gt 0}).Count -eq 3);rhythm=$Care.best.rhythm -ge 800;picnic=$Care.picnics -gt 0;photo=$Care.photos.Count -gt 0;days=$Care.days.Count -ge 5}
    foreach($id in $conditions.Keys){if($conditions[$id] -and $id -notin $Care.stamps){$Care.stamps+=,$id}}
}
function Complete-PlaySession($Care,$Session) {
    if(-not $Session.Completed -or $Session.Committed){return $false};$Session.Committed=$true
    if($Session.Result -in @('bubble','snack','boxes','rhythm')){
        $Care.games++;$Care.best[$Session.Result]=[math]::Max($Care.best[$Session.Result],$Session.Score)
        $names=@{bubble='泡泡追逐';snack='接點心';boxes='紙箱猜猜樂';rhythm='節奏跳跳'}
        Add-PlayEvent $Care ($Session.Result+'-'+$Session.Score) ($names[$Session.Result]+'完成，得分 '+$Session.Score+'。')
    }elseif($Session.Result -eq 'fish' -and $Session.Fish -ge 0 -and $Session.Fish -lt 4){
        $Care.games++;$Care.fish[$Session.Fish]++;$names=@('粉紅小魚','藍紋小魚','金色小魚','小海星')
        Add-PlayEvent $Care ('fish-'+$Session.Fish) ('釣到'+$names[$Session.Fish]+'，魚冊多了一個回憶。')
    }elseif($Session.Result -eq 'picnic'){$Care.picnics++;Add-PlayEvent $Care ('picnic-'+$Session.Food) '一起吃點心、喝茶、看雲，度過一段野餐時光。'}
    else{return $false}
    return $true
}
function Plant-PlaySeed($Care,[int]$Pot,[int]$Seed) {
    if($Pot -lt 0 -or $Pot -ge 3 -or $Seed -lt 0 -or $Seed -gt 2 -or $Care.garden[$Pot].seed -ne -1){return $false}
    $Care.garden[$Pot]=@{seed=$Seed;growth=0.0;water=0.0;cooldown=0.0};return $true
}
function Water-PlayPlant($Care,[int]$Pot) {
    if($Pot -lt 0 -or $Pot -ge 3){return $false};$p=$Care.garden[$Pot]
    if($p.seed -lt 0 -or $p.growth -ge 240 -or $p.cooldown -gt 0){return $false}
    $p.water=[math]::Min(180.0,$p.water+90);$p.cooldown=20.0;return $true
}
function Step-PlayGarden($Care,[double]$Delta,[bool]$Paused) {
    if($Paused -or $Delta -le 0 -or $Delta -gt 5){return}
    foreach($p in $Care.garden){if($p.seed -lt 0){continue};$p.cooldown=[math]::Max(0,$p.cooldown-$Delta)
        $growth=[math]::Min($Delta,$p.water);$p.water=[math]::Max(0,$p.water-$Delta);$p.growth=[math]::Min(240.0,$p.growth+$growth)
    }
}
function Harvest-PlayPlant($Care,[int]$Pot) {
    if($Pot -lt 0 -or $Pot -ge 3 -or $Care.garden[$Pot].growth -lt 240){return $false}
    $seed=$Care.garden[$Pot].seed;$Care.flowers[$seed]++;$Care.garden[$Pot]=New-PlayPot
    $name=@('粉紅波斯菊','向日葵','紫色風鈴花')[$seed];Add-PlayEvent $Care ('flower-'+$seed) ('收成了'+$name+'，小花園開花了。');return $true
}
