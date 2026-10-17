# Production WPF controls, shared actor lifecycle, save IO and renderer acceptance.
Close-Play;Close-Room;Stop-Activity;Close-CareWindows;Reset-Pomodoro $state
$state.quiet=$false;$state.stories=$false;$state.autoHide=$false;$state.look=$false;$state.mode='stay';$script:manualHidden=$false;$script:fullscreenHidden=$false;$script:pendingClick=$null
$state.play=New-PlayState;Update-Visibility
function Play-Click($Button){
    $event=if($Button -is [Windows.Controls.MenuItem]){[Windows.Controls.MenuItem]::ClickEvent}else{[Windows.Controls.Button]::ClickEvent}
    try{$Button.RaiseEvent([Windows.RoutedEventArgs]::new($event))}catch{$Error|Select-Object -First 3|Format-List * -Force|Out-String|Set-Content (Join-Path $dataDirectory 'play-event-error.txt');throw};Pump
}
function Get-PlayFileHash([string]$Path){
    $stream=[IO.File]::OpenRead($Path);$sha=[Security.Cryptography.SHA256]::Create()
    try{return [Convert]::ToBase64String($sha.ComputeHash($stream))}finally{$sha.Dispose();$stream.Dispose()}
}
function Capture-Play([string]$Name,[switch]$Window){
    $visual=if($Window){$playWindow}else{$play.stage};$visual.InvalidateVisual();$visual.UpdateLayout();Pump
    $width=if($Window){[int][math]::Ceiling($visual.ActualWidth)}else{800};$height=if($Window){[int][math]::Ceiling($visual.ActualHeight)}else{460}
    $render=[Windows.Media.Imaging.RenderTargetBitmap]::new($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($visual)
    $enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render));$stream=[IO.File]::Create((Join-Path $dataDirectory $Name));try{$enc.Save($stream)}finally{$stream.Dispose()}
    $pixels=New-Object byte[] ($width*$height*4);$render.CopyPixels($pixels,$width*4,0)
    Check (@($pixels|Where-Object {$_ -ne 0}|Select-Object -First 1).Count -eq 1) "play capture $Name contains rendered pixels"
}
Check ($playMenuItem.Header -like '*一起玩*' -and $playTrayItem.Text -like '*一起玩*') 'play hub available in context and tray menus'
foreach($id in @('ren','kaling','mushroom','ribbon-pig','slime')){
    Select-Character $id;$left=$w.Left;$top=$w.Top;Play-Click $playMenuItem
    Check ($playWindow.IsVisible -and -not $w.IsVisible -and -not $room.open -and $play.character -eq $id) "$id opens hub with a single active character"
    Check ($play.featureButtons.Count -eq 10 -and $play.stage.Frames.Count -eq $frames.Count -and $play.stage.CharacterName -eq $character.displayName) "$id has all ten features and its own frames"
    foreach($feature in $playAssets.manifest.features){
        Play-Click $play.featureButtons[$feature.id];Check ($play.mode -eq $feature.id -and $play.stage.Mode -eq $feature.id -and $play.description.Text -eq $feature.description) "$id $($feature.id) real navigation selects matching page"
        if($id -eq 'slime'){Capture-Play ('play-slime-'+$feature.id+'.png')}
    }
    Play-Click $play.featureButtons.bubble;Play-Click $play.primary;$target=$play.stage.Session.Items[0];$play.stage.Session.Click($target.X,$target.Y);Refresh-PlayData
    Check ($play.stage.Session.Score -gt 0 -and $play.stage.Session.Chasing) "$id bubble hit begins a continuous chase"
    while($play.stage.Session.Chasing){Update-Play .05};Check ($play.stage.Session.ActionRow -eq 4) "$id arrives and jumps with its own frames";Capture-Play ('play-'+$id+'-bubble.png')
    Play-Click $play.pause;$elapsed=$play.stage.Session.Time;$score=$play.stage.Session.Score;$target=$play.stage.Session.Items[1];$play.stage.Session.Click($target.X,$target.Y);Update-Play .1
    Check ($play.stage.Session.Time -eq $elapsed -and $play.stage.Session.Score -eq $score) "$id pause blocks hidden scoring and timer"
    Play-Click $play.pause;Check ($play.stage.IsKeyboardFocused) "$id resume restores game keyboard focus";for($n=0;$n -lt 301;$n++){Update-Play .1};Refresh-PlayData
    $c=Get-PlayCare;Check ($c.games -eq 1 -and $c.best.bubble -gt 0 -and $c.stamps -contains 'first') "$id finished game saves one real record"
    Update-Play .1;Refresh-PlayData;Check ($c.games -eq 1) "$id dispatcher cannot duplicate completed rewards"
    $timer.Start();Pump-For 350;$timer.Stop();Check (-not $closing -and -not (Test-Path $log)) "$id live game dispatcher remains healthy"
    Close-Play;Check ($null -eq $playWindow -and $w.IsVisible -and $w.Left -eq $left -and $w.Top -eq $top) "$id closes hub to original desktop position"
}
foreach($outfit in @('uniform','pajamas','hoodie')){
    Select-Character 'kaling';Select-Outfit $outfit;Show-Play;Pump
    Check ([object]::ReferenceEquals($play.stage.Frames['0,0'],$frames['0,0']) -and $state.outfit -eq $outfit) "$outfit uses selected costume in new playground"
    Close-Play
}
Select-Character 'slime';Show-Play;Pump
Play-Click $play.featureButtons.snack;Play-Click $play.primary
for($n=0;$n -lt 30;$n++){Update-Play .1};Capture-Play 'play-snack-active.png'
for($n=0;$n -lt 600;$n++){$food=@($play.stage.Session.Items|Where-Object Kind -eq 0|Sort-Object Y -Descending);if($food.Count){$play.stage.Session.Move($food[0].X)};Update-Play .05}
Refresh-PlayData;Check ($play.stage.Session.Completed -and (Get-PlayCare).best.snack -gt 0) 'catcher game finishes and records actual collisions through update loop'
Play-Click $play.featureButtons.boxes;Play-Click $play.primary;Capture-Play 'play-boxes-peek.png'
for($round=0;$round -lt 3;$round++){
    for($n=0;$n -lt 120 -and $play.stage.Session.Phase -ne 'guess';$n++){Update-Play .05}
    $play.stage.Session.Click($play.stage.Session.Boxes[$play.stage.Session.WinningBox],310);Refresh-PlayData
    if($round -eq 0){Capture-Play 'play-boxes-found.png'}
    for($n=0;$n -lt 31;$n++){Update-Play .05}
}
Refresh-PlayData;Check ((Get-PlayCare).best.boxes -eq 300) 'three actual shuffled rounds persist a perfect result'
Play-Click $play.featureButtons.rhythm;Play-Click $play.primary
Check ($play.stage.IsKeyboardFocused) 'start button gives keyboard focus to rhythm stage'
for($beat=0;$beat -lt 10;$beat++){
    $target=1+$beat*1.25;while($play.stage.Session.Time -lt $target-.001){Update-Play ([math]::Min(.05,$target-$play.stage.Session.Time))}
    if($beat -eq 0){Capture-Play 'play-rhythm-active.png'}
    $key=[Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice,[Windows.PresentationSource]::FromVisual($play.stage),0,[Windows.Input.Key]::Space);$key.RoutedEvent=[Windows.Input.Keyboard]::KeyDownEvent;$play.stage.RaiseEvent($key)
}
for($n=0;$n -lt 13;$n++){Update-Play .05};Refresh-PlayData
Check ((Get-PlayCare).best.rhythm -eq 1000) 'ten routed space events complete rhythm without restarting the game'
Play-Click $play.featureButtons.garden;$play.stage.SelectedPot=2;$play.seed.SelectedIndex=1;Play-Click $play.primary
Check ((Get-PlayCare).garden[2].seed -eq 1 -and $play.stage.GardenPlanted[2]) 'garden plants selected seed and shows planted state before sprouting'
$water=@($play.extra.Children|Where-Object Content -eq '澆水')[0];Play-Click $water;Check ((Get-PlayCare).garden[2].water -eq 90) 'garden watering button supplies water'
for($n=0;$n -lt 245;$n++){Update-Play 1;if((Get-PlayCare).garden[2].cooldown -le 0){Play-Click $water}}
Capture-Play 'play-garden-flower.png';$harvest=@($play.extra.Children|Where-Object Content -eq '收成花朵')[0];Play-Click $harvest
Check ((Get-PlayCare).flowers[1] -eq 1 -and (Get-PlayCare).garden[2].seed -eq -1) 'garden harvest updates collection and frees pot'
Play-Click $play.featureButtons.weather
foreach($weather in @('sun','rain','snow','night')){$button=@($play.options.Children|Where-Object Tag -eq $weather)[0];Play-Click $button;Check ($state.play.weather -eq $weather -and $play.stage.Weather -eq $weather) "weather $weather changes through actual control";Capture-Play ('play-weather-'+$weather+'.png')}
Play-Click $play.featureButtons.fishing;Play-Click $play.primary
for($n=0;$n -lt 100 -and $play.stage.Session.Phase -ne 'bite';$n++){Update-Play .1};Play-Click $play.primary
Check ($play.stage.Session.Result -eq 'fish' -and @((Get-PlayCare).fish|Where-Object {$_ -gt 0}).Count -eq 1) 'fishing controls commit a caught species';Capture-Play 'play-fishing-caught.png'
Play-Click $play.featureButtons.picnic;$play.meal.SelectedIndex=1;Play-Click $play.primary
for($n=0;$n -lt 35;$n++){Update-Play .1};Check ($play.stage.Session.ActionRow -eq 13) 'picnic UI chooses pudding animation';Capture-Play 'play-picnic-pudding.png'
for($n=0;$n -lt 170;$n++){Update-Play .1};Refresh-PlayData;Check ((Get-PlayCare).picnics -eq 1) 'complete picnic enters diary once'
Play-Click $play.featureButtons.photo;$play.pose.SelectedIndex=1;$play.photoFrame.SelectedIndex=2;$play.caption.Text='啵！今天也一起玩了。';Pump;Play-Click $play.primary
$c=Get-PlayCare;Check ($c.photos.Count -eq 1 -and $play.stage.PhotoSource) 'photo button saves a real image and loads it in album'
$file=$c.photos[0].file;$path=Get-PlayPhotoPath $file;$bitmap=[Windows.Media.Imaging.BitmapImage]::new([Uri]$path)
Check ($bitmap.PixelWidth -eq 800 -and $bitmap.PixelHeight -eq 460 -and (Get-Item $path).Length -gt 10000) 'postcard contains full-size WPF art';$bitmap=$null
Check (Export-PlayPhoto $file (Join-Path $dataDirectory 'play-postcard-export.png')) 'postcard exports through production IO helper'
Check ((Get-PlayFileHash $path) -eq (Get-PlayFileHash (Join-Path $dataDirectory 'play-postcard-export.png'))) 'export preserves PNG bytes'
Capture-Play 'play-album.png';Capture-Play 'play-window.png' -Window
Play-Click $play.featureButtons.journal;Check ($play.stage.JournalLines.Count -gt 0 -and $play.stage.StampLabels.Count -ge 4) 'journal shows actual events and earned stamps';Capture-Play 'play-journal.png'
Save-Settings;$saved=Read-PetState $dataDirectory;Check ($saved.play.weather -eq 'night' -and $saved.play.frame -eq 'mint' -and $saved.play.characters.slime.photos[0].file -eq $file -and $saved.play.characters.slime.flowers[1] -eq 1) 'weather frame photo and flower persist together'
Play-Click $play.featureButtons.photo;$null=Load-PlayPhoto $file;Check ($play.photoFile -eq $file) 'album reopens saved photo after page change'
Check (Remove-PlayPhoto $file) 'explicit delete removes chosen photo';Check (-not (Test-Path $path) -and (Get-PlayCare).photos.Count -eq 0 -and (Get-PlayCare).stamps -contains 'photo') 'photo deletion preserves earned memory stamp'
$play.caption.Text='第一張';$null=Save-PlayPhoto;$firstFile=$play.photoFile;$firstHash=Get-PlayFileHash (Get-PlayPhotoPath $firstFile)
$play.caption.Text='換了短句的第二張';$play.photoFrame.SelectedIndex=1;$null=Save-PlayPhoto;$secondFile=$play.photoFile
Check ($secondFile -ne $firstFile -and (Get-PlayFileHash (Get-PlayPhotoPath $secondFile)) -ne $firstHash) 'new photo immediately uses changed scene instead of cached album bitmap'
$null=Remove-PlayPhoto $firstFile;$null=Remove-PlayPhoto $secondFile
Close-Play;Show-Room;Pump;$roomLeft=$room.window.Left;$roomTop=$room.window.Top;Show-Play;Pump
Check (-not $w.IsVisible -and -not $room.window.IsVisible -and $playWindow.IsVisible) 'opening from home hides both previous actor surfaces'
Close-Play;Check ($room.window.IsVisible -and -not $w.IsVisible -and $room.window.Left -eq $roomLeft -and $room.window.Top -eq $roomTop) 'closing play restores original home';Close-Room
foreach($interrupt in @('switch','pet','timer','quiet','hide','fullscreen','wardrobe','room')){
    Select-Character 'ren';Reset-Pomodoro $state;$state.quiet=$false;$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility;Show-Play;Pump;Invoke-PlayPrimary;$old=$play.stage.Session;$window=$playWindow
    switch($interrupt){'switch'{Select-Character 'mushroom'};'pet'{$script:cooldownUntil=0;$null=Invoke-Interaction 'pet'};'timer'{Start-Timer};'quiet'{Toggle-Preference 'quiet' $quietItem};'hide'{Toggle-Visibility};'fullscreen'{$script:fullscreenHidden=$true;Update-Visibility};'wardrobe'{Show-Wardrobe};'room'{Show-Room}}
    Check ($null -eq $playWindow -and -not $window.IsVisible -and $old.Phase -eq 'cancelled' -and -not $old.Completed) "$interrupt cancels play without orphan window or reward"
    if($wardrobeWindow){$wardrobeWindow.Close()};Close-Room;Reset-Pomodoro $state;$state.quiet=$false;$script:manualHidden=$false;$script:fullscreenHidden=$false;Update-Visibility
}
Select-Character 'ren';Show-Play;Pump;$old=$playWindow;$null=Request-Attack 'petal';Check ($null -eq $playWindow -and -not $old.IsVisible -and $activity.kind -eq 'attack') 'Ren attack takes ownership from play cleanly';Stop-Activity
$state.play.weather='sun';$state.care.enabled=$true;Save-Settings
