. (Join-Path $PSScriptRoot 'Pet.Room.Model.ps1')
. (Join-Path $PSScriptRoot 'Pet.Care.Model.ps1')
. (Join-Path $PSScriptRoot 'Pet.Play.State.ps1')
function New-PetState {
    return @{
        version=3; character='ren'; characterOutfits=(New-CharacterOutfits); left=$null; top=$null; scale=1.5; mode='stay'; look=$true
        bubbles=$true; stories=$true; quiet=$false; autoHide=$true; clickThrough=$false
        focusMinutes=25; shortMinutes=5; longMinutes=15; mood='calm'; outfit='original';care=(New-CareState)
        pomo=@{phase='focus'; status='ready'; remaining=1500.0; rounds=0; total=0};home=(New-HomeState);play=(New-PlayState)
    }
}
function Read-PetState([string]$Directory) {
    $state=New-PetState
    $path=Join-Path $Directory 'settings.json'
    if(-not (Test-Path -LiteralPath $path)){return $state}
    try {
        $data=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if($data.version -notin @(1,2,3)){throw 'Unsupported settings version'}
        foreach($name in @('left','top','scale','focusMinutes','shortMinutes','longMinutes')) {
            $value=$data.$name
            if($null -eq $value -and $name -in @('left','top')){continue}
            if($value -isnot [ValueType] -or $value -is [bool] -or [double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value)){throw "Invalid $name"}
            $state[$name]=[double]$value
        }
        if($state.scale -notin @(1.0,1.5,2.0)){throw 'Invalid size'}
        foreach($name in @('focusMinutes','shortMinutes','longMinutes')){if($state[$name] -lt 1 -or $state[$name] -gt 180 -or $state[$name] -ne [math]::Floor($state[$name])){throw 'Invalid duration'}}
        foreach($name in @('look','bubbles','stories','quiet','autoHide','clickThrough')) {
            if($data.$name -isnot [bool]){throw "Invalid $name"};$state[$name]=$data.$name
        }
        if($data.mode -notin @('stay','wander','follow')){throw 'Invalid mode'};$state.mode=$data.mode
        if($data.mood -in @('calm','happy','focused','sleepy')){$state.mood=$data.mood}
        # Keep legacy Kaling outfits; add new identities without resetting existing care.
        if($data.outfit -in @('uniform','pajamas','hoodie')){$state.characterOutfits.kaling=[string]$data.outfit}
        $definitions=@(Get-PetDefinitions)
        if($data.version -ge 2){
            foreach($definition in $definitions){
                $saved=$data.characterOutfits.($definition.id)
                if($saved -in @($definition.outfits.id)){$state.characterOutfits[$definition.id]=[string]$saved}
            }
            if($data.character -in @($definitions.id)){$state.character=[string]$data.character}
        }
        if($data.version -lt 3){$state.character='ren'}
        $state.outfit=$state.characterOutfits[$state.character]
        $state.care=Read-CareState $data.care
        $state.home=Read-HomeState $data.home
        $state.play=Read-PlayState $data.play
        $p=$data.pomo
        if($p.phase -notin @('focus','short','long') -or $p.status -notin @('ready','running','paused')){throw 'Invalid timer state'}
        foreach($name in @('remaining','rounds','total')){
            if($p.$name -isnot [ValueType] -or $p.$name -is [bool] -or [double]::IsNaN([double]$p.$name) -or [double]::IsInfinity([double]$p.$name) -or $p.$name -lt 0){throw 'Invalid timer number'}
        }
        if($p.remaining -gt 10800 -or $p.rounds -gt 3 -or $p.rounds -ne [math]::Floor($p.rounds) -or $p.total -ne [math]::Floor($p.total) -or $p.total -gt [int]::MaxValue){throw 'Invalid timer range'}
        $state.pomo=@{phase=$p.phase;status=$(if($p.status -eq 'running'){'paused'}else{$p.status});remaining=[double]$p.remaining;rounds=[int]$p.rounds;total=[int]$p.total}
    } catch {
        $backup=$path+'.corrupt-'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
        [IO.File]::Copy($path,$backup,$false)
        $state=New-PetState
    }
    return $state
}
function Write-PetState($State,[string]$Directory) {
    $State.characterOutfits[$State.character]=$State.outfit
    [void][IO.Directory]::CreateDirectory($Directory)
    $path=Join-Path $Directory 'settings.json';$temp=Join-Path $Directory ('settings.'+[guid]::NewGuid().ToString('N')+'.tmp')
    try {
        [IO.File]::WriteAllText($temp,($State | ConvertTo-Json -Depth 9),[Text.UTF8Encoding]::new($false))
        # Indexers and antivirus may briefly hold the destination or backup on Windows.
        # Keep atomic replacement and its backup; only retry transient IO failures.
        for($attempt=0;$attempt -lt 5;$attempt++){
            try{if([IO.File]::Exists($path)){[IO.File]::Replace($temp,$path,$path+'.bak',$true)}else{[IO.File]::Move($temp,$path)};break}
            catch [IO.IOException]{if($attempt -eq 4 -or -not [IO.File]::Exists($temp)){throw};Start-Sleep -Milliseconds (20*($attempt+1))}
        }
    } finally {if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
}
function Get-PhaseSeconds($State,[string]$Phase) {
    switch($Phase){'focus'{return $State.focusMinutes*60.0};'short'{return $State.shortMinutes*60.0};'long'{return $State.longMinutes*60.0}}
}
function Start-Pomodoro($State) {$State.pomo.status='running';$State.mood='focused'}
function Pause-Pomodoro($State) {if($State.pomo.status -eq 'running'){$State.pomo.status='paused'}}
function Reset-Pomodoro($State) {
    $State.pomo.phase='focus';$State.pomo.status='ready';$State.pomo.remaining=Get-PhaseSeconds $State 'focus';$State.pomo.rounds=0
}
function Step-Pomodoro($State,[double]$Elapsed) {
    if($State.pomo.status -ne 'running'){return 'none'}
    # Dispatcher gaps include system sleep and long stalls. Never credit unattended time.
    if($Elapsed -gt 5){Pause-Pomodoro $State;return 'suspended'}
    $State.pomo.remaining=[math]::Max(0.0,$State.pomo.remaining-[math]::Max(0.0,$Elapsed))
    if($State.pomo.remaining -gt 0){return 'none'}
    $finished=$State.pomo.phase
    if($finished -eq 'focus'){
        $State.pomo.rounds++;$State.pomo.total++;$State.mood='happy'
        if($State.pomo.rounds -ge 4){$State.pomo.phase='long';$State.pomo.rounds=0}else{$State.pomo.phase='short'}
    }else{$State.pomo.phase='focus';$State.mood='calm'}
    $State.pomo.status='ready';$State.pomo.remaining=Get-PhaseSeconds $State $State.pomo.phase
    return $finished
}
function Get-ClickAction([bool]$Moved,[bool]$DoubleClick,[double]$NormalizedY) {
    if($Moved){return 'drag'};if($DoubleClick){return 'jump'};if($NormalizedY -lt 0.60){return 'pet'};return 'wave'
}
function Limit-PetPosition([double]$Left,[double]$Top,[double]$Width,[double]$Height,$Area) {
    return @{left=[math]::Max($Area.Left,[math]::Min($Left,$Area.Right-$Width));top=[math]::Max($Area.Top,[math]::Min($Top,$Area.Bottom-$Height))}
}
function Get-Story([int]$Hour,[string]$Mood) {
    if($Hour -ge 22 -or $Hour -lt 6){return @{text='夜深了，今天也辛苦你了。';row=0;mood='sleepy'}}
    if($Hour -lt 11){return @{text='早安！今天也一起慢慢完成吧。';row=3;mood='calm'}}
    if($Hour -lt 17){return @{text='伸個懶腰，喝口水再繼續吧。';row=4;mood='happy'}}
    if($Mood -eq 'happy'){return @{text='有你陪著，今天過得好快呀。';row=3;mood='happy'}}
    return @{text='我在這裡，陪你把今天收個尾。';row=8;mood='calm'}
}
