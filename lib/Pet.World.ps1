$script:worldWindow=$null;$script:world=$null;$script:worldAssets=$null
function Load-WorldAssets {
    if($worldAssets){return}
    $manifest=Get-Content (Join-Path $root 'assets/world/catalog.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $components=[RenPoseArt]::Read((Join-Path $root 'assets/world/props.png'));if($components.Count -ne 16){throw 'Invalid world prop sheet'}
    $props=[Windows.Media.ImageSource[]]::new(16);for($i=0;$i -lt 16;$i++){$props[$i]=$components[$manifest.propsComponentOrder[$i]].Image}
    $ren=[RenPoseArt]::Read((Join-Path $root 'assets/world/ren-daily.png'));if($ren.Count -ne 8){throw 'Invalid world Ren sheet'}
    $renImages=[Windows.Media.ImageSource[]]::new(8)
    for($i=0;$i -lt 8;$i++){
        $pose=$ren[$i];$scale=$manifest.renScale;$visual=[Windows.Media.DrawingVisual]::new();$dc=$visual.RenderOpen()
        $dc.DrawImage($pose.Image,[Windows.Rect]::new((84-($manifest.renHeadAnchors[$i]-$pose.X)*$scale),(190-$pose.Height*$scale),($pose.Width*$scale),($pose.Height*$scale)));$dc.Close()
        $bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new(384,416,192,192,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($visual);$bmp.Freeze();$renImages[$i]=$bmp
    }
    $bg=[Windows.Media.Imaging.BitmapImage]::new();$bg.BeginInit();$bg.CacheOption='OnLoad';$bg.UriSource=[Uri](Join-Path $root 'assets/world/garden.png');$bg.EndInit();$bg.Freeze()
    $scenes=@{};foreach($scene in @('forest','pond')){$bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.UriSource=[Uri](Join-Path $root ('assets/world/'+$scene+'.png'));$bitmap.EndInit();$bitmap.Freeze();$scenes[$scene]=$bitmap}
    $kaling=@{}
    foreach($outfit in @('uniform','pajamas','hoodie')){
        $poses=[RenPoseArt]::Read((Join-Path $root ('assets/world/kaling-'+$outfit+'.png')));if($poses.Count -ne 6){throw ('Invalid Kaling world sheet: '+$outfit)}
        $images=[Windows.Media.ImageSource[]]::new(6)
        for($i=0;$i -lt 6;$i++){$pose=$poses[$i];$scale=.365;$visual=[Windows.Media.DrawingVisual]::new();$dc=$visual.RenderOpen();$dc.DrawImage($pose.Image,[Windows.Rect]::new((96-$pose.Width*$scale/2),(190-$pose.Height*$scale),($pose.Width*$scale),($pose.Height*$scale)));$dc.Close();$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new(384,416,192,192,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($visual);$bmp.Freeze();$images[$i]=$bmp};$kaling[$outfit]=$images
    }
    $script:worldAssets=@{manifest=$manifest;props=$props;ren=$renImages;kaling=$kaling;background=$bg;scenes=$scenes}
}
function New-WorldActorArt([string]$Id) {
    $definition=@($characterCatalog.characters|Where-Object id -eq $Id)[0]
    $assets=Get-OutfitAssets $state.characterOutfits[$Id] $Id
    $art=[KalingWorld.ActorArt]::new();$art.Id=$Id;$art.Name=$definition.displayName;$art.Counts=[int[]]$assets.counts
    foreach($key in $assets.frames.Keys){$art.Frames.Add([string]$key,$assets.frames[$key])}
    if($Id -eq 'ren'){$art.RenDaily=$worldAssets.ren};if($Id -eq 'kaling'){$art.Signature=$worldAssets.kaling[$state.characterOutfits[$Id]]};return $art
}
function Save-WorldLayout {
    if(-not $world){return};$state.world.layout=@($world.session.Layout);$state.world.boxX=$world.session.BoxX;$state.world.boxY=$world.session.BoxY
}
function Reset-WorldSession {
    if(-not $world){return};$companion=$state.world.companion;if($companion -eq $state.character){$companion='';$state.world.companion=''}
    if($world.session){Refresh-World;Save-WorldLayout;$world.session.Cancel()}
    $world.session=[KalingWorld.Session]::new($state.character,$companion,(Get-Random));$world.session.Layout=[string[]]$state.world.layout;$world.session.BoxX=$state.world.boxX;$world.session.BoxY=$state.world.boxY
    $world.stage.Session=$world.session;$world.stage.Art.Clear()
    foreach($a in $world.session.Actors){$world.stage.Art.Add((New-WorldActorArt $a.Id))}
    $world.actor.Items.Clear();foreach($a in $world.stage.Art){[void]$world.actor.Items.Add($a.Name)};$world.actor.SelectedIndex=0
    Refresh-World
}
function New-WorldActionButton($Panel,[string]$Label,[string]$Id,[scriptblock]$Action) {
    $button=New-PlayButton $Label $Action;$button.Tag=$Id;[void]$Panel.Children.Add($button);$world.buttons[$Id]=$button;return $button
}
function Show-World {
    if($worldWindow){$worldWindow.Activate()|Out-Null;return}
    if($closing -or $manualHidden -or $fullscreenHidden){return}
    if($state.quiet -or $state.pomo.status -eq 'running'){Show-Bubble '專注結束後，再一起到庭院玩。' -Important;return}
    if($wardrobeWindow){$wardrobeWindow.Close()};if($settingsWindow){$settingsWindow.Close()};if($room.open){Cancel-RoomActivity}
    Mark-Activity;Hide-Bubble;Load-WorldAssets;Load-PlayAssets;$script:pendingClick=$null;$script:drag=$false;$img.ReleaseMouseCapture()
    $script:world=@{buttons=@{};session=$null;lastUi=-1.0;lastRender=0.0;resetting=$true;choiceKey='';closing=$false;hwnd=[IntPtr]::Zero}
    $window=[Windows.Window]::new();$script:worldWindow=$window;$window.Title='楓之谷桌面小世界 · 2.0.0';$window.FontFamily='Microsoft JhengHei UI';$window.Background='#F7F5EC';$window.Topmost=$true
    $area=[Windows.SystemParameters]::WorkArea;$window.Width=[math]::Min(1170,$area.Width-24);$window.Height=[math]::Min(900,$area.Height-24);$window.MinWidth=[math]::Min(760,$area.Width-24);$window.MinHeight=[math]::Min(580,$area.Height-24)
    $window.Left=if($null -ne $state.world.left){[math]::Max($area.Left,[math]::Min($state.world.left,$area.Right-$window.Width))}else{$area.Left+($area.Width-$window.Width)/2}
    $window.Top=if($null -ne $state.world.top){[math]::Max($area.Top,[math]::Min($state.world.top,$area.Bottom-$window.Height))}else{$area.Top+($area.Height-$window.Height)/2}
    $layout=[Windows.Controls.DockPanel]::new();$layout.Margin=16;$window.Content=$layout
    $head=[Windows.Controls.StackPanel]::new();[Windows.Controls.DockPanel]::SetDock($head,'Top');[void]$layout.Children.Add($head)
    $title=[Windows.Controls.TextBlock]::new();$title.Text='我們的小世界';$title.FontSize=26;$title.FontWeight='SemiBold';$title.Foreground='#294E3D';[void]$head.Children.Add($title)
    $note=[Windows.Controls.TextBlock]::new();$note.Text='一起住、隨手逗逗，讓日常慢慢發生。點角色摸摸；拖紙箱；點空地推球。';$note.Foreground='#6A7D6D';$note.Margin='0,5,0,8';$note.TextWrapping='Wrap';[void]$head.Children.Add($note)
    $toolbar=[Windows.Controls.WrapPanel]::new();[void]$head.Children.Add($toolbar)
    $world.companion=Add-PlayChoice $toolbar '搭檔' @('自己待一會');$world.companionIds=@('')
    foreach($d in $characterCatalog.characters){if($d.id -ne $state.character){[void]$world.companion.Items.Add($d.displayName);$world.companionIds+=,[string]$d.id}}
    $world.companion.SelectedIndex=[math]::Max(0,$world.companionIds.IndexOf($state.world.companion))
    $world.actor=Add-PlayChoice $toolbar '互動對象' @()
    $null=New-WorldActionButton $toolbar '招牌動作' 'signature' {Invoke-WorldInteraction 'signature'}
    $null=New-WorldActionButton $toolbar '喝茶' 'tea' {Invoke-WorldInteraction 'tea'}
    $null=New-WorldActionButton $toolbar '玩球' 'ball' {Invoke-WorldInteraction 'ball'}
    $null=New-WorldActionButton $toolbar '拿出點心' 'bait' {Invoke-WorldInteraction 'bait'}
    $null=New-WorldActionButton $toolbar '清理庭院' 'clean' {Invoke-WorldInteraction 'clean'}
    $body=[Windows.Controls.Grid]::new();$col=[Windows.Controls.ColumnDefinition]::new();$col.Width=[Windows.GridLength]::new(1,'Star');[void]$body.ColumnDefinitions.Add($col);$col=[Windows.Controls.ColumnDefinition]::new();$col.Width=205;[void]$body.ColumnDefinitions.Add($col)
    $stage=[KalingWorld.Stage]::new();$stage.Width=900;$stage.Height=560;$stage.Focusable=$true;$stage.Props=$worldAssets.props;$stage.PlayProps=$playAssets.props;$stage.BackgroundArt=$worldAssets.background
    $stage.ForestArt=$worldAssets.scenes.forest;$stage.PondArt=$worldAssets.scenes.pond
    $stage.Box=Get-RoomBitmap 'box';$stage.Ball=Get-RoomBitmap 'ball';$stage.Poop=Get-CareArt 'poop';$world.stage=$stage
    $view=[Windows.Controls.Viewbox]::new();$view.Stretch='Uniform';$view.Child=$stage;[void]$body.Children.Add($view)
    $sideScroll=[Windows.Controls.ScrollViewer]::new();$sideScroll.VerticalScrollBarVisibility='Auto';$sideScroll.Margin='12,0,0,0';[Windows.Controls.Grid]::SetColumn($sideScroll,1);[void]$body.Children.Add($sideScroll)
    $side=[Windows.Controls.StackPanel]::new();$sideScroll.Content=$side
    $label=[Windows.Controls.TextBlock]::new();$label.Text='今天的小劇場';$label.FontSize=16;$label.Foreground='#42614C';$label.Margin=8;[void]$side.Children.Add($label)
    foreach($story in $worldAssets.manifest.stories){$null=New-WorldActionButton $side $story.name ('story-'+$story.id) {param($s,$e);$world.decorate.IsChecked=$false;$world.stage.PendingFurniture='';$null=$world.session.StartStory(([string]$s.Tag).Substring(6));Refresh-World}}
    $null=New-WorldActionButton $side '森林小旅行' 'forest' {Start-WorldTrip 'forest'}
    $null=New-WorldActionButton $side '溪畔小旅行' 'pond' {Start-WorldTrip 'pond'}
    $world.decorate=[Windows.Controls.CheckBox]::new();$world.decorate.Content='佈置庭院';$world.decorate.Margin='8,12,8,4';[void]$side.Children.Add($world.decorate)
    $world.furniture=Add-PlayChoice $side '擺設' @($worldAssets.manifest.furniture.name)
    $null=New-WorldActionButton $side '放進庭院…' 'place' {Set-WorldFurniture}
    $world.weather=Add-PlayChoice $side '天空' @('晴天','下雨','飄雪','星空');$world.weather.SelectedIndex=@('sun','rain','snow','night').IndexOf($state.play.weather)
    $null=New-WorldActionButton $side '拍下這一刻' 'photo' {$null=Save-WorldPhoto}
    $null=New-WorldActionButton $side '查看相簿／一起玩' 'play' {Close-World;Show-Play;Select-PlayFeature 'photo'}
    $null=New-WorldActionButton $side '重設這位的習慣' 'reset' {Reset-WorldHabits}
    $null=New-WorldActionButton $side '回小屋照顧' 'care' {$id=$world.session.Actors[$world.session.SelectedActor].Id;Close-World;if($id -ne $state.character){Select-Character $id};Show-Room}
    $foot=[Windows.Controls.StackPanel]::new();[Windows.Controls.DockPanel]::SetDock($foot,'Bottom');[void]$layout.Children.Add($foot)
    $world.choices=[Windows.Controls.WrapPanel]::new();[void]$foot.Children.Add($world.choices)
    $world.message=[Windows.Controls.TextBlock]::new();$world.message.FontSize=15;$world.message.Foreground='#355741';$world.message.TextWrapping='Wrap';$world.message.Margin='4,8';[void]$foot.Children.Add($world.message)
    $world.habit=[Windows.Controls.TextBlock]::new();$world.habit.FontSize=12;$world.habit.Foreground='#6F7F72';$world.habit.TextWrapping='Wrap';$world.habit.Margin=4;[void]$foot.Children.Add($world.habit)
    $footer=[Windows.Controls.WrapPanel]::new();[void]$foot.Children.Add($footer)
    $null=New-WorldActionButton $footer '暫停／繼續' 'pause' {$world.session.Paused=-not $world.session.Paused;Refresh-World}
    $null=New-WorldActionButton $footer '結束活動，回庭院' 'cancel' {$world.session.Cancel();$world.session.Message='回到庭院，慢慢待著。';Refresh-World}
    $null=New-WorldActionButton $footer '收合，回去陪你' 'close' {Close-World}
    [void]$layout.Children.Add($body)
    Reset-WorldSession;$world.resetting=$false
    $world.companion.Add_SelectionChanged({if($world -and -not $world.resetting){$state.world.companion=$world.companionIds[$world.companion.SelectedIndex];Reset-WorldSession;Save-Settings}})
    $world.actor.Add_SelectionChanged({if($world -and $world.session -and $world.actor.SelectedIndex -ge 0){$world.session.SelectedActor=$world.actor.SelectedIndex;Refresh-World}})
    $world.decorate.Add_Checked({if($world){$world.session.Cancel();$world.stage.Decorating=$true;$world.session.Message='拖動擺設交換位置，或選一件擺設再點放置區。';Refresh-World}})
    $world.decorate.Add_Unchecked({if($world){$world.stage.Decorating=$false;$world.stage.PendingFurniture='';Refresh-World}})
    $world.weather.Add_SelectionChanged({if($world){$state.play.weather=@('sun','rain','snow','night')[$world.weather.SelectedIndex];Refresh-World;Save-Settings}})
    $stage.Add_Interacted({if($world){Save-WorldLayout;Refresh-World;Save-Settings}})
    $window.Add_SourceInitialized({$world.hwnd=([Windows.Interop.WindowInteropHelper]::new($worldWindow)).Handle})
    $window.Add_Closed({if($worldWindow){Close-World -FromWindow}})
    $window.Show();Update-Visibility;Refresh-World
}
function Close-World([switch]$FromWindow) {
    if(-not $worldWindow){return};$old=$worldWindow;Refresh-World;Save-WorldLayout;$state.world.left=$old.Left;$state.world.top=$old.Top
    if($world){$world.session.Cancel();$world.stage.ReleaseMouseCapture()};$script:worldWindow=$null;$script:world=$null
    if(-not $FromWindow){$old.Close()};$script:lastInteraction=$clock.ElapsedMilliseconds;Set-Animation 0 0;Save-Settings;if(-not $closing){Update-Visibility}
}
function Invoke-WorldInteraction([string]$Action) {
    if(-not $world){return};$world.stage.Decorating=$false;$world.decorate.IsChecked=$false;$world.stage.PendingFurniture=''
    $selected=$world.session.Actors[$world.session.SelectedActor].Id
    if($Action -eq 'bait' -and $state.care.enabled -and -not (Test-CareFeed $state.care.characters[$selected] 'cookie')){$world.session.Message='肚子還飽著，點心留待會再吃。';Refresh-World;return}
    if($Action -eq 'clean'){
        foreach($actor in $world.session.Actors){$c=$state.care.characters[$actor.Id];$m=@($c.messes|Where-Object place -eq 'world');if($m.Count){$c.messes=@($c.messes|Where-Object place -ne 'world');$c.hygiene=[math]::Min(100,$c.hygiene+8*$m.Count)}}
    }
    $world.session.Interact($Action,$world.session.SelectedActor);Refresh-World;Save-Settings
}
function Set-WorldFurniture {
    if(-not $world){return};$id=$worldAssets.manifest.furniture[$world.furniture.SelectedIndex].id
    if($id -in @('stone','shell','mushroom') -and $state.world.collections[$id] -lt 1){$world.session.Message='先去探險帶回這件紀念物，再放進庭院。';Refresh-World;return}
    $world.decorate.IsChecked=$true;$world.stage.PendingFurniture=$id;$world.session.Message='點一個擺設區放下；原本的家具會收起或交換。';Refresh-World
}
function Start-WorldTrip([string]$Route) {
    if(-not $world){return};$world.decorate.IsChecked=$false;$world.stage.PendingFurniture='';$world.session.StartExpedition($Route);Refresh-World
}
function Reset-WorldHabits {
    $id=$world.session.Actors[$world.session.SelectedActor].Id;foreach($key in @('pet','tea','ball','tidy')){$state.world.habits[$id][$key]=0};Save-Settings;$world.session.Message='這位夥伴的相處習慣已重新開始，收藏與日記仍然保留。';Refresh-World
}
function Save-WorldPhoto {
    if(-not $world){return $false};$c=Get-PlayCare;if($c.photos.Count -ge 48){$world.session.Message='相簿已滿，先到相簿另存或刪除照片。';Refresh-World;return $false}
    $file=[guid]::NewGuid().ToString('N')+'.png';$path=Get-PlayPhotoPath $file
    try{[void][IO.Directory]::CreateDirectory((Split-Path $path -Parent));$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($world.stage.Snapshot()));$stream=[IO.File]::Create($path);try{$encoder.Save($stream)}finally{$stream.Dispose()}
        $c.photos+=,@{file=$file;caption='我們的小世界';day=[datetime]::Now.ToString('yyyy-MM-dd')};Add-PlayEvent $c 'world-photo' '拍下了庭院裡一起生活的片刻。';Save-Settings;$world.session.Message='照片已存進這位角色原本的相簿。';Refresh-World;return $true
    }catch{$world.session.Message='照片暫時無法儲存，請檢查相簿資料夾。';Refresh-World;return $false}
}
function Refresh-World {
    if(-not $world -or -not $world.session){return};$s=$world.session;$stage=$world.stage;$changed=$false
    while($s.Events.Count){$event=$s.Events.Dequeue();$id=$event.Character
        switch($event.Kind){
            'habit'{$null=Add-WorldHabit $state.world $id $event.Value;$changed=$true;if($event.Value -eq 'tea' -and $state.care.enabled){$null=Complete-CareMeal $state.care.characters[$id] 'tea'};Add-PlayEvent $state.play.characters[$id] ('world-'+$event.Value) '在小世界裡又多了一次相處。'}
            'meal'{if($state.care.enabled){$null=Complete-CareMeal $state.care.characters[$id] $event.Value};$changed=$true}
            'story'{$key=($event.Value -split '-')[0];$name=@($worldAssets.manifest.stories|Where-Object id -eq $key)[0].name;Add-PlayEvent $state.play.characters[$id] ('world-story-'+$event.Value) ('一起經歷了庭院小劇場：'+$name+'。');$changed=$true}
            'expedition'{$state.world.collections[$event.Value]=[math]::Min(9999,$state.world.collections[$event.Value]+1);$state.world.trips++;foreach($a in $s.Actors){Add-PlayEvent $state.play.characters[$a.Id] ('world-trip-'+$event.Value) '一起去小旅行，帶回一件庭院紀念物。'};$changed=$true}
        }
    }
    if($changed){Save-Settings}
    $s.Weather=$state.play.weather;$s.Auto=$state.stories -and -not $stage.Decorating
    for($i=0;$i -lt 4;$i++){$stage.Fish[$i]=0};for($i=0;$i -lt 3;$i++){$stage.Flowers[$i]=0};$stage.Messes.Clear()
    foreach($a in $s.Actors){$c=$state.play.characters[$a.Id];for($i=0;$i -lt 4;$i++){$stage.Fish[$i]+=$c.fish[$i]};for($i=0;$i -lt 3;$i++){$stage.Flowers[$i]+=$c.flowers[$i]};$h=$state.world.habits[$a.Id];$s.Habits[$a.Id]=[int[]]@($h.pet,$h.tea,$h.ball,$h.tidy)
        if($state.care.enabled){foreach($m in $state.care.characters[$a.Id].messes){if($m.place -eq 'world'){$stage.Messes.Add([Windows.Point]::new($m.x,$m.y))}}}
    }
    $world.message.Text=$(if($s.Paused){'〔暫停中〕 '}else{''})+$s.Message
    if($world.actor.SelectedIndex -ne $s.SelectedActor){$world.actor.SelectedIndex=$s.SelectedActor}
    $id=$s.Actors[$s.SelectedActor].Id;$world.habit.Text=(Get-WorldHabitText $state.world $id)+'　旅行 '+$state.world.trips+' 次'
    $choiceKey=$s.Route+'|'+$s.ExpeditionStep+'|'+$s.ExpeditionPhase
    if($world.choiceKey -ne $choiceKey){$world.choiceKey=$choiceKey;$world.choices.Children.Clear();for($i=0;$i -lt $s.Choices.Length;$i++){$b=New-PlayButton $s.Choices[$i] {param($sender,$e);$null=$world.session.Choose([int]$sender.Tag);Refresh-World};$b.Tag=$i;[void]$world.choices.Children.Add($b)}}
    $stage.InvalidateVisual()
}
function Update-World([double]$Delta) {
    if(-not $worldWindow -or -not $world){return}
    if($closing -or $manualHidden -or $fullscreenHidden -or $state.quiet -or $state.pomo.status -eq 'running'){Close-World;return}
    if($worldWindow.WindowState -eq 'Minimized' -or -not $worldWindow.IsVisible -or $menu.IsOpen -or $trayMenu.Visible -or $Delta -le 0 -or $Delta -gt 1){return}
    $s=$world.session;$s.Step($Delta)
    if(-not $s.Paused -and -not $s.Dragging -and $s.Route -eq '' -and $state.care.enabled){
        foreach($a in $s.Actors){$c=$state.care.characters[$a.Id];$event=Step-CareModel $c $Delta $false ($a.Action -eq 'doze')
            if($event -eq 'warning'){$s.Message='有夥伴想上廁所了，可以選牠再按「回小屋照顧」。'}
            if($event -eq 'due'){$mess=@{id=[guid]::NewGuid().ToString('N');place='world';x=$a.X;y=443.0};if(Complete-CareToilet $c $false $mess){$s.Message='庭院留下了小便便，按「清理庭院」收拾一下。';Save-Settings}}
        }
    }
    if($s.Time-$world.lastUi -ge .1){$world.lastUi=$s.Time;Refresh-World}
    if($s.Time-$world.lastRender -ge .032){$world.lastRender=$s.Time;$world.stage.InvalidateVisual()}
}
function Initialize-WorldMenus {
    $script:worldMenuItem=Add-Menu '小世界 · 一起生活…' {Show-World}
    $script:worldTrayItem=Add-Tray '小世界 · 一起生活…' {Show-World}
    $null=Add-Menu '版本 2.0.0 · 查看更新' {Start-Process 'https://github.com/Li-Syuan/kaling-desktop-pet/releases/latest'}
    $null=Add-Tray '版本 2.0.0 · 查看更新' {Start-Process 'https://github.com/Li-Syuan/kaling-desktop-pet/releases/latest'}
}
