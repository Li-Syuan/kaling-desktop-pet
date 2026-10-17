$script:playWindow=$null;$script:play=$null;$script:playAssets=$null
function Get-PlayCare {return $state.play.characters[$state.character]}
function Get-PlayVoice {
    switch($state.character){'ren'{return '蓮：'};'slime'{return '啵！'};'mushroom'{return '菇！'};'ribbon-pig'{return '哼哼！'};default{return '嘿嘿，'}}
}
function Load-PlayAssets {
    if($playAssets){return}
    $manifest=Get-Content (Join-Path $root 'assets/play/catalog.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.UriSource=[Uri](Join-Path $root $manifest.props.file);$bitmap.EndInit();$bitmap.Freeze()
    $props=[Windows.Media.ImageSource[]]::new($manifest.props.rects.Count)
    for($i=0;$i -lt $props.Length;$i++){$r=$manifest.props.rects[$i];$props[$i]=[Windows.Media.Imaging.CroppedBitmap]::new($bitmap,[Windows.Int32Rect]::new($r[0],$r[1],$r[2],$r[3]));$props[$i].Freeze()}
    $script:playAssets=@{manifest=$manifest;props=$props}
}
function New-PlayButton([string]$Label,[scriptblock]$Action) {
    $b=[Windows.Controls.Button]::new();$b.Content=$Label;$b.Margin='4';$b.Padding='13,9';$b.Background='#E6EFE1';$b.Foreground='#294B39';$b.BorderBrush='#B3C9AB';$b.Cursor='Hand';$b.FontSize=13
    if($Action){$b.Add_Click($Action)};return $b
}
function Add-PlayChoice($Parent,[string]$Label,[string[]]$Options) {
    $captionBlock=[Windows.Controls.TextBlock]::new();$captionBlock.Text=$Label;$captionBlock.Margin='8,8,4,4';$captionBlock.VerticalAlignment='Center';$captionBlock.Foreground='#536457';[void]$Parent.Children.Add($captionBlock)
    $combo=[Windows.Controls.ComboBox]::new();$combo.Margin='4';$combo.Padding='6';$combo.MinWidth=100;foreach($option in $Options){[void]$combo.Items.Add($option)};$combo.SelectedIndex=0;[void]$Parent.Children.Add($combo);return $combo
}
function Show-Play {
    if($playWindow){$playWindow.Activate()|Out-Null;return}
    if($manualHidden -or $fullscreenHidden -or $closing){return}
    if($state.pomo.status -eq 'running' -or $state.quiet){Show-Bubble '先結束專注或關閉安靜陪伴，再來一起玩。' -Important;return}
    if($wardrobeWindow){$wardrobeWindow.Close()};if($settingsWindow){$settingsWindow.Close()};if($room.open){Cancel-RoomActivity};Mark-Activity;Hide-Bubble;Load-PlayAssets
    $script:pendingClick=$null;$script:drag=$false;$img.ReleaseMouseCapture()
    $script:play=@{mode='bubble';elapsed=0.0;lastRender=0.0;lastUi=-1.0;character=$state.character;notice='';photoFile=$null;paused=$false}
    $window=[Windows.Window]::new();$window.Title=$character.displayName+' · 一起玩';$window.Width=[math]::Min(1120,[Windows.SystemParameters]::WorkArea.Width*.94);$window.Height=[math]::Min(800,[Windows.SystemParameters]::WorkArea.Height*.94)
    $window.MinWidth=800;$window.MinHeight=570;$window.WindowStartupLocation='CenterScreen';$window.Background='#F8F5EB';$window.Topmost=$true;$window.FontFamily='Microsoft JhengHei UI';$script:playWindow=$window
    $grid=[Windows.Controls.Grid]::new();$grid.Margin=18;$grid.Background='#F8F5EB'
    foreach($v in @('Auto','*','Auto')){$r=[Windows.Controls.RowDefinition]::new();$r.Height=[Windows.GridLengthConverter]::new().ConvertFromString($v);[void]$grid.RowDefinitions.Add($r)}
    $header=[Windows.Controls.StackPanel]::new();$title=[Windows.Controls.TextBlock]::new();$title.Text=$character.displayName+' 的小日子';$title.FontSize=27;$title.FontWeight='SemiBold';$title.Foreground='#284E3B';[void]$header.Children.Add($title)
    $sub=[Windows.Controls.TextBlock]::new();$sub.Text='玩一小局、種一朵花，留下一張今天的回憶。';$sub.Foreground='#708173';$sub.Margin='0,6,0,16';[void]$header.Children.Add($sub);[void]$grid.Children.Add($header)
    $body=[Windows.Controls.Grid]::new();[Windows.Controls.Grid]::SetRow($body,1)
    foreach($v in @('170','*')){$c=[Windows.Controls.ColumnDefinition]::new();$c.Width=[Windows.GridLengthConverter]::new().ConvertFromString($v);[void]$body.ColumnDefinitions.Add($c)}
    $sidebar=[Windows.Controls.StackPanel]::new();$scroll=[Windows.Controls.ScrollViewer]::new();$scroll.VerticalScrollBarVisibility='Auto';$scroll.Content=$sidebar;[void]$body.Children.Add($scroll)
    $play.featureButtons=@{}
    foreach($entry in $playAssets.manifest.features){$b=New-PlayButton $entry.title {param($s,$e);Select-PlayFeature ([string]$s.Tag)};$b.Tag=$entry.id;$b.HorizontalContentAlignment='Left';$b.Padding='12,11';$play.featureButtons[$entry.id]=$b;[void]$sidebar.Children.Add($b)}
    $content=[Windows.Controls.Grid]::new();$content.Margin='16,0,0,0';[Windows.Controls.Grid]::SetColumn($content,1)
    foreach($v in @('Auto','*','Auto','Auto','Auto')){$r=[Windows.Controls.RowDefinition]::new();$r.Height=[Windows.GridLengthConverter]::new().ConvertFromString($v);[void]$content.RowDefinitions.Add($r)}
    $play.description=[Windows.Controls.TextBlock]::new();$play.description.TextWrapping='Wrap';$play.description.Foreground='#56695C';$play.description.FontSize=14;$play.description.Margin='3,0,4,10';[void]$content.Children.Add($play.description)
    $stage=[KalingPlay.Stage]::new();$stage.Width=800;$stage.Height=460;$stage.Focusable=$true;$stage.Props=$playAssets.props;$stage.Counts=[int[]]$counts;$stage.CharacterName=$character.displayName;$stage.Weather=$state.play.weather;$stage.FrameColor=$state.play.frame;$stage.Box=Get-RoomBitmap 'box'
    foreach($key in $frames.Keys){$stage.Frames.Add([string]$key,$frames[$key])};$play.stage=$stage
    $stage.Add_Interacted({Refresh-PlayData});$view=[Windows.Controls.Viewbox]::new();$view.Stretch='Uniform';$view.Child=$stage;$view.VerticalAlignment='Center';[Windows.Controls.Grid]::SetRow($view,1);[void]$content.Children.Add($view)
    $play.options=[Windows.Controls.WrapPanel]::new();$play.options.Margin='0,8,0,4';[Windows.Controls.Grid]::SetRow($play.options,2);[void]$content.Children.Add($play.options)
    $bar=[Windows.Controls.WrapPanel]::new();[Windows.Controls.Grid]::SetRow($bar,3)
    $play.primary=New-PlayButton '開始' {Invoke-PlayPrimary};$play.primary.Background='#396B50';$play.primary.Foreground='White';[void]$bar.Children.Add($play.primary)
    $play.cancel=New-PlayButton '結束這一局' {if($play.stage.Session){$play.stage.Session.Cancel()};$play.notice='這局先停在這裡，不會記入成績。';Refresh-PlayData};[void]$bar.Children.Add($play.cancel)
    $play.pause=New-PlayButton '暫停' {$play.paused=-not $play.paused;$play.stage.Session.Paused=$play.paused;$play.pause.Content=if($play.paused){'繼續'}else{'暫停'};$play.notice=if($play.paused){'先停在這一刻，準備好再繼續。'}else{''};Refresh-PlayData;$play.stage.Focus()|Out-Null};[void]$bar.Children.Add($play.pause)
    $play.extra=[Windows.Controls.WrapPanel]::new();[void]$bar.Children.Add($play.extra);[void]$content.Children.Add($bar)
    $play.status=[Windows.Controls.TextBlock]::new();$play.status.TextWrapping='Wrap';$play.status.MinHeight=44;$play.status.Foreground='#355B44';$play.status.Margin='5,7,5,0';[Windows.Controls.Grid]::SetRow($play.status,4);[void]$content.Children.Add($play.status)
    [void]$body.Children.Add($content);[void]$grid.Children.Add($body)
    $footer=[Windows.Controls.DockPanel]::new();$footer.Margin='0,14,0,0';[Windows.Controls.Grid]::SetRow($footer,2)
    $back=New-PlayButton '收好，回去陪你' {Close-Play};[Windows.Controls.DockPanel]::SetDock($back,'Right');[void]$footer.Children.Add($back)
    $note=[Windows.Controls.TextBlock]::new();$note.Text='各角色分開記錄 · 關閉不會扣進度 · 預設無聲';$note.Foreground='#7C877C';$note.VerticalAlignment='Center';$note.FontSize=12;[void]$footer.Children.Add($note);[void]$grid.Children.Add($footer)
    $window.Content=$grid;$window.ContextMenu=$menu
    $window.Add_Closed({if($play -and $play.stage.Session){$play.stage.Session.Cancel()};$script:playWindow=$null;$script:play=$null;Save-Settings;if(-not $closing){Update-Visibility}})
    Select-PlayFeature 'bubble';Update-Visibility;$window.Show();$stage.Focus()|Out-Null
}
function Close-Play {if($playWindow){$playWindow.Close()}}
function Select-PlayFeature([string]$Id) {
    if(-not $play){return};$entry=@($playAssets.manifest.features|Where-Object id -eq $Id)[0];if(-not $entry){return}
    if($play.stage.Session){$play.stage.Session.Cancel()};$play.mode=$Id;$play.notice='';$play.photoFile=$null;$play.paused=$false;$play.pause.Content='暫停';$play.stage.PhotoSource=$null;$play.stage.Mode=$Id;$play.stage.Session=[KalingPlay.Session]::new($Id,(Get-Random));$play.description.Text=$entry.description
    $play.options.Children.Clear();$play.extra.Children.Clear();$play.primary.Content=$entry.primary;$play.primary.Visibility='Visible';$play.cancel.Visibility=if($Id -in @('bubble','snack','boxes','fishing','rhythm','picnic')){'Visible'}else{'Collapsed'}
    $play.pause.Visibility=$play.cancel.Visibility
    foreach($key in $play.featureButtons.Keys){$play.featureButtons[$key].Background=if($key -eq $Id){'#C8DEC1'}else{'#E6EFE1'}}
    switch($Id){
        'garden'{
            $play.seed=Add-PlayChoice $play.options '種子' @('粉紅波斯菊','向日葵','紫色風鈴花')
            $b=New-PlayButton '澆水' {$c=Get-PlayCare;if(Water-PlayPlant $c $play.stage.SelectedPot){$play.notice='澆好了！有水的時候就會慢慢長大。';Save-Settings}else{$play.notice='先種下種子；剛澆過水時等一下，開花後就能收成。'};Refresh-PlayData};[void]$play.extra.Children.Add($b)
            $b=New-PlayButton '收成花朵' {$c=Get-PlayCare;if(Harvest-PlayPlant $c $play.stage.SelectedPot){$play.notice='花朵收進收藏，空花盆又能種了。';Save-Settings}else{$play.notice='花還沒開，慢慢陪它長大吧。'};Refresh-PlayData};[void]$play.extra.Children.Add($b)
        }
        'picnic'{$play.meal=Add-PlayChoice $play.options '今天的點心' @('餅乾＋茶','布丁＋茶')}
        'weather'{
            $play.primary.Visibility='Collapsed';$names=@{sun='晴天';rain='下雨';snow='飄雪';night='星空'}
            foreach($kind in @('sun','rain','snow','night')){$b=New-PlayButton $names[$kind] {param($s,$e);$state.play.weather=[string]$s.Tag;$play.stage.Weather=$state.play.weather;$play.notice='天空換好了，其他玩法也會沿用。';Save-Settings;Refresh-PlayData};$b.Tag=$kind;[void]$play.options.Children.Add($b)}
        }
        'photo'{Initialize-PlayPhotoOptions}
        'journal'{$play.primary.Visibility='Collapsed';$b=New-PlayButton '看看紀念章條件' {$play.notice='初次遊玩；泡泡 200 分；接點心 150 分；找人全對；首次釣獲／四種魚；首次收花／三色花；節奏 800 分；野餐；拍照；累積五天互動。';Refresh-PlayData};[void]$play.extra.Children.Add($b)}
    }
    Refresh-PlayData;$play.stage.InvalidateVisual()
}
function Invoke-PlayPrimary {
    if(-not $play){return};$c=Get-PlayCare;$play.notice='';$play.paused=$false;$play.stage.Session.Paused=$false;$play.pause.Content='暫停'
    switch($play.mode){
        'garden'{if(Plant-PlaySeed $c $play.stage.SelectedPot $play.seed.SelectedIndex){$play.notice='種子種好了，替它澆點水吧。';Save-Settings}else{$play.notice='這盆已經有植物了，開花收成後再種。'}}
        'photo'{Save-PlayPhoto}
        'fishing'{if($play.stage.Session.Phase -in @('waiting','bite')){$play.stage.Session.Pull()}else{$play.stage.Session.Start()}}
        default {if($play.mode -eq 'picnic'){$play.stage.Session.Food=if($play.meal.SelectedIndex -eq 1){'pudding'}else{'cookie'}};$play.stage.Session.Start()}
    };Refresh-PlayData
    if($play.mode -in @('bubble','snack','boxes','fishing','rhythm','picnic')){$play.stage.Focus()|Out-Null}
}
function Refresh-PlayData {
    if(-not $play){return};$c=Get-PlayCare;$stage=$play.stage;$session=$stage.Session
    if($session.Completed -and -not $session.Committed){
        if(Complete-PlaySession $c $session){
            Add-CareHappiness 5
            if($state.care.enabled -and ($session.Result -eq 'picnic' -or ($session.Result -eq 'snack' -and $session.Caught -ge 3))){$food=if($session.Result -eq 'picnic'){$session.Food}else{'cookie'};if(Test-CareFeed (Get-ActiveCare) $food){$null=Complete-CareMeal (Get-ActiveCare) $food (Get-Random -Minimum 480 -Maximum 721)}}
            Save-Settings
        }
    }
    for($i=0;$i -lt 3;$i++){$p=$c.garden[$i];$stage.GardenPlanted[$i]=$p.seed -ge 0;$stage.GardenGrowth[$i]=$p.growth;$stage.GardenWater[$i]=$p.water;$stage.GardenStages[$i]=if($p.seed -lt 0){4}elseif($p.growth -ge 240){@(7,8,9)[$p.seed]}elseif($p.growth -ge 150){6}elseif($p.growth -ge 60){5}else{4};$stage.Flowers[$i]=$c.flowers[$i]}
    for($i=0;$i -lt 4;$i++){$stage.FishCounts[$i]=$c.fish[$i]}
    $stage.StampLabels=[string[]]@($c.stamps|ForEach-Object {$playStampNames[$_]});$stage.JournalLines=[string[]]@($c.journal|Select-Object -Last 8|Sort-Object day -Descending|ForEach-Object {$_.day+'  '+$_.text})
    if($play.mode -eq 'fishing'){$play.primary.Content=if($session.Phase -in @('waiting','bite')){'拉竿！'}else{'下一竿'}}
    $status=if($play.notice){$play.notice}elseif($session.Message){(Get-PlayVoice)+$session.Message}elseif($play.mode -eq 'garden'){'花朵收藏：波斯菊 '+$c.flowers[0]+' · 向日葵 '+$c.flowers[1]+' · 風鈴花 '+$c.flowers[2]}elseif($play.mode -eq 'journal'){'已記下 '+$c.journal.Count+' 篇回憶，收集 '+$c.stamps.Count+' / 12 枚紀念章。'}else{'選好玩法，準備好再開始。'}
    if($play.mode -in @('bubble','snack','boxes','rhythm')){$status+='　最高分 '+$c.best[$play.mode]}
    $play.status.Text=$status;$stage.InvalidateVisual()
}
function Update-Play([double]$Delta) {
    $paused=$closing -or $manualHidden -or $fullscreenHidden -or $state.quiet -or $state.pomo.status -eq 'running'
    Step-PlayGarden (Get-PlayCare) $Delta $paused
    if(-not $playWindow -or -not $play -or $paused -or $play.paused -or -not $playWindow.IsVisible -or $playWindow.WindowState -eq 'Minimized' -or $menu.IsOpen -or $trayMenu.Visible -or $Delta -gt 1){return}
    $play.elapsed+=[math]::Max(0,$Delta);$play.stage.Clock=$play.elapsed;$play.stage.Session.Step($Delta)
    if($play.elapsed-$play.lastUi -gt .10){$play.lastUi=$play.elapsed;Refresh-PlayData}
    if($play.elapsed-$play.lastRender -gt .032){$play.lastRender=$play.elapsed;$play.stage.InvalidateVisual()}
}
function Initialize-PlayMenus {
    $script:playMenuItem=Add-Menu '一起玩 · 十種小日子…' {Show-Play}
    $script:playTrayItem=Add-Tray '一起玩 · 十種小日子…' {Show-Play}
}
