$script:room=@{open=$false;window=$null;hwnd=[IntPtr]::Zero;phase='idle';task='';u=.45;v=.45;path=@();step=0;until=0.0;time=0.0;idle=0.0;nextAuto=40.0;nextFrame=0.0;drag=$null;roll=$null;pose=$null;foodCount=0;petCount=0}
function Get-RoomBitmap([string]$Name) {
    $b=[System.Windows.Media.Imaging.BitmapImage]::new();$b.BeginInit();$b.CacheOption='OnLoad';$b.UriSource=[Uri](Join-Path $root ('assets\room\'+$Name+'.png'));$b.EndInit();$b.Freeze();return $b
}
function Add-RoomImage([string]$Name,[double]$Width,[double]$Height) {
    $i=[System.Windows.Controls.Image]::new();$i.Source=Get-RoomBitmap $Name;$i.Width=$Width;$i.Height=$Height;$i.Stretch='Fill';[void]$room.canvas.Children.Add($i);return $i
}
function Place-RoomVisual($Visual,[double]$X,[double]$Y,[int]$Z) {
    [System.Windows.Controls.Canvas]::SetLeft($Visual,$X);[System.Windows.Controls.Canvas]::SetTop($Visual,$Y);[System.Windows.Controls.Panel]::SetZIndex($Visual,$Z)
}
function Set-RoomMessage([string]$Text) {if($room.open){$room.message.Text=$Text}}
function Keep-RoomVisible {
    if(-not $room.window -or $room.hwnd -eq [IntPtr]::Zero){return}
    $a=[System.Windows.Forms.Screen]::FromHandle($room.hwnd).WorkingArea;$m=([System.Windows.PresentationSource]::FromVisual($room.window)).CompositionTarget.TransformFromDevice
    $p=$m.Transform([System.Windows.Point]::new($a.Left,$a.Top));$q=$m.Transform([System.Windows.Point]::new($a.Right,$a.Bottom))
    $pos=Limit-PetPosition $room.window.Left $room.window.Top $room.window.ActualWidth $room.window.ActualHeight @{Left=$p.X;Top=$p.Y;Right=$q.X;Bottom=$q.Y}
    $room.window.Left=$pos.left;$room.window.Top=$pos.top
}
function Render-Room {
    if(-not $room.open){return}
    foreach($kind in @('ball','box')){$p=Get-RoomPoint $state.home[$kind].u $state.home[$kind].v;$visual=$room.visuals[$kind];Place-RoomVisual $visual ($p.x-$visual.Width/2) ($p.y-$visual.Height) ([int]$p.y)}
    $p=Get-RoomPoint $room.u $room.v;$z=[int]$p.y
    if($room.pose){$p=$room.pose;$z=$p.z}
    $room.actor.Source=$frames["$row,$frame"];$room.actor.Visibility='Visible';Place-RoomVisual $room.actor ($p.x-72) ($p.y-153) $z
    $room.actor.Clip=if($room.phase -in @('bed-tuck','bed-sleep','waking')){[System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0,0,144,110))}else{$null}
    if($room.phase -eq 'box-hide'){$room.actor.Visibility='Hidden'}
    $room.bedFront.Visibility=if($room.phase -in @('bed-tuck','bed-sleep','waking')){'Visible'}else{'Hidden'}
    $room.boxFront.Visibility=if($room.phase -in @('box-enter','box-hide','box-peek')){'Visible'}else{'Hidden'}
    if($room.boxFront.Visibility -eq 'Visible'){$bp=Get-RoomPoint $state.home.box.u $state.home.box.v;Place-RoomVisual $room.boxFront ($bp.x-51) ($bp.y-75) ([int]$bp.y+2)}
}
function Cancel-RoomActivity {
    if(-not $room.open){return}
    $room.path=@();$room.step=0;$room.phase='idle';$room.task='';$room.pose=$null;$room.roll=$null;$room.transition=$null
    if($room.drag){$v=$room.visuals[$room.drag.kind];$room.drag=$null;$v.ReleaseMouseCapture()}
    $room.idle=0;$room.nextAuto=$room.time+(Get-Random -Minimum 30 -Maximum 61);$script:resting='none';Set-Animation 0 0;Render-Room
}
function Start-RoomPhase([string]$Phase,[int]$Row,[double]$Seconds) {
    $room.phase=$Phase;$room.until=$room.time+$Seconds;Set-Animation $Row ([int]($Seconds*1000));Render-Room
}
function Request-RoomAction([string]$Action,[switch]$Automatic) {
    if(-not $room.open){return}
    if($Action -eq 'ball' -and $state.pomo.status -eq 'running'){Set-RoomMessage '先陪你專注，休息時再玩球。';return}
    $oldPose=$room.pose;$wasBed=$room.phase -like 'bed-*'
    Cancel-RoomActivity;if(-not $Automatic){Mark-Activity}
    if($Action -eq 'wake'){if($wasBed){$room.pose=$oldPose;Start-RoomPhase 'waking' 23 1.0}else{Start-RoomPhase 'stretch' 17 2.4};Set-RoomMessage '嗯？你叫我嗎？';return}
    if($Action -eq 'pet'){$room.petCount++;$r=if($room.petCount%3 -eq 0){21}else{11};Start-RoomPhase 'reaction' $r 2.2;Set-RoomMessage '嘿嘿，再陪我一下。';return}
    $reactions=@{smug=21;wave=3;jump=4;stretch=17;spin=18;peek=20;waiting=6;thinking=7;review=8;sad=5}
    if($reactions.ContainsKey($Action)){Start-RoomPhase 'reaction' $reactions[$Action] 2.2;return}
    $goal=switch($Action){'bed'{@{u=.38;v=.63}};'sofa'{@{u=.70;v=.40}};'wardrobe'{@{u=.40;v=.18}};{$_ -in @('cookie','pudding','tea')}{@{u=.54;v=.67}};'ball'{@{u=$state.home.ball.u;v=$state.home.ball.v}};'box'{@{u=$state.home.box.u;v=$state.home.box.v}};default{$null}}
    if($Action -eq 'ball'){
        foreach($offset in @(@(-.055,.055),@(-.10,0),@(0,.10),@(.10,0),@(0,-.10))){$u=$state.home.ball.u+$offset[0];$v=$state.home.ball.v+$offset[1];if(Test-RoomFloor $u $v){$goal=@{u=$u;v=$v};break}}
    }
    if(-not $goal){return};$room.task=$Action;$room.path=@(Get-RoomPath @{u=$room.u;v=$room.v} $goal);$room.step=0
    if(-not $room.path.Count){Set-RoomMessage '這邊走不到，換個位置吧。';return}
    $room.phase='walking';Set-Animation 1 0;Set-RoomMessage $(switch($Action){'bed'{'回小床休息一下。'};'sofa'{'抱著枕頭陪你。'};'ball'{'球球跑去哪裡了？'};'box'{'箱子裡是不是有祕密？'};'wardrobe'{'今天想穿哪一套？'};default{'去茶几吃點心！'}})
}
function Arrive-RoomTarget {
    switch($room.task){
        'bed' {$p=Get-RoomPoint .18 .65;Move-RoomPose @{x=$p.x;y=$p.y-40;z=455};Start-RoomPhase 'bed-enter' 15 .65}
        'sofa' {$p=Get-RoomPoint .75 .22;Move-RoomPose @{x=$p.x;y=$p.y-48;z=440};Start-RoomPhase 'sofa-enter' 22 .65}
        'wardrobe' {$room.phase='idle';Set-Animation 0 0;Show-Wardrobe}
        'ball' {Start-RoomPhase 'ball-tap' 24 1.2}
        'box' {$p=Get-RoomPoint $state.home.box.u $state.home.box.v;$room.pose=@{x=$p.x;y=$p.y;z=[int]$p.y+1};Start-RoomPhase 'box-enter' 25 1.2}
        {$_ -in @('cookie','pudding','tea')} {$r=@{cookie=12;pudding=13;tea=14}[$room.task];Start-RoomPhase 'food' $r 2.8}
    }
}
function Move-RoomPose($Target) {
    $start=if($room.pose){$room.pose}else{Get-RoomPoint $room.u $room.v}
    $room.transition=@{from=$start;to=$Target;started=$room.time;duration=.65};$room.pose=@{x=$start.x;y=$start.y;z=$Target.z}
}
function Begin-RoomToy([string]$Kind,$Point) {
    Cancel-RoomActivity;Mark-Activity;$room.drag=@{kind=$Kind;start=$Point;last=$Point;original=@{u=$state.home[$Kind].u;v=$state.home[$Kind].v};candidate=$null;moved=$false;du=0.0;dv=0.0}
}
function Move-RoomToy($Point) {
    if(-not $room.drag){return};$d=$room.drag
    if([math]::Abs($Point.X-$d.start.X)+[math]::Abs($Point.Y-$d.start.Y) -gt 5){$d.moved=$true}
    if($d.moved){$origin=Get-RoomPoint $d.original.u $d.original.v;$p=Get-RoomUV ($origin.x+$Point.X-$d.start.X) ($origin.y+$Point.Y-$d.start.Y);$d.candidate=$p
        $a=Get-RoomUV $d.last.X $d.last.Y;$b=Get-RoomUV $Point.X $Point.Y;$d.du=[math]::Max(-.30,[math]::Min(.30,($b.u-$a.u)*8));$d.dv=[math]::Max(-.30,[math]::Min(.30,($b.v-$a.v)*8))
        $v=$room.visuals[$d.kind];Place-RoomVisual $v ($origin.x+$Point.X-$d.start.X-$v.Width/2) ($origin.y+$Point.Y-$d.start.Y-$v.Height) 900
    };$d.last=$Point
}
function End-RoomToy {
    if(-not $room.drag){return};$d=$room.drag;$room.drag=$null;$room.visuals[$d.kind].ReleaseMouseCapture()
    if(-not $d.moved){Request-RoomAction $d.kind;return}
    if(-not (Test-RoomDrop $d.kind $d.candidate.u $d.candidate.v $state.home)){Render-Room;Set-RoomMessage '玩具放在空地上就好，這裡會擋到家具。';return}
    $state.home[$d.kind]=@{u=$d.candidate.u;v=$d.candidate.v};Save-Settings;Render-Room
    if($d.kind -eq 'ball' -and $state.pomo.status -ne 'running'){$room.roll=@{du=$d.du;dv=$d.dv;remaining=.8;chase=$true}}elseif($d.kind -eq 'box'){Request-RoomAction 'box'}
}
function Update-Room([double]$Delta) {
    if(-not $room.open -or -not $room.window.IsVisible -or $room.drag -or $wardrobeWindow -or $settingsWindow -or $menu.IsOpen -or $room.foodMenu.IsOpen){return}
    $dt=[math]::Min(.15,[math]::Max(0.0,$Delta));$room.time+=$dt;$room.idle+=$dt
    if($room.transition){$t=$room.transition;$progress=[math]::Min(1.0,($room.time-$t.started)/$t.duration);$room.pose=@{x=$t.from.x+($t.to.x-$t.from.x)*$progress;y=$t.from.y+($t.to.y-$t.from.y)*$progress;z=$t.to.z};if($progress -ge 1){$room.transition=$null}}
    if($room.roll){$r=$room.roll;$u=$state.home.ball.u+$r.du*$dt;$v=$state.home.ball.v+$r.dv*$dt
        if(Test-RoomDrop 'ball' $u $v $state.home){$state.home.ball.u=$u;$state.home.ball.v=$v}else{$r.remaining=0}
        $r.remaining-=$dt;$r.du*=.94;$r.dv*=.94
        if($r.remaining -le 0){$chase=$r.chase;$room.roll=$null;Save-Settings;if($chase){Request-RoomAction 'ball'}}
    }
    if($room.phase -eq 'walking'){
        $goal=$room.path[$room.step];$dx=$goal.u-$room.u;$dy=$goal.v-$room.v;$distance=[math]::Sqrt($dx*$dx+$dy*$dy);$amount=.28*$dt
        $r=if($dx-$dy -lt 0){2}else{1};if($row -ne $r){Set-Animation $r 0}
        if($distance -le $amount){$room.u=$goal.u;$room.v=$goal.v;$room.step++;if($room.step -ge $room.path.Count){Arrive-RoomTarget}}else{$room.u+=$dx/$distance*$amount;$room.v+=$dy/$distance*$amount}
    }elseif($room.phase -ne 'idle' -and $room.phase -ne 'bed-sleep' -and $room.time -ge $room.until){
        switch($room.phase){
            'bed-enter' {Start-RoomPhase 'bed-sit' 15 1.0}
            'sofa-enter' {Start-RoomPhase 'sofa' 22 10}
            'bed-sit' {Start-RoomPhase 'bed-tuck' 23 2.4}
            'bed-tuck' {$script:frame=3;$room.phase='bed-sleep';Set-RoomMessage '睡著了…點小床或咖凌叫醒她。'}
            'waking' {$p=Get-RoomPoint $room.u $room.v;Move-RoomPose @{x=$p.x;y=$p.y;z=[int]$p.y};Start-RoomPhase 'getting-up' 17 .65}
            'getting-up' {$room.pose=$null;Start-RoomPhase 'stretch' 17 2.4}
            'sofa' {if($state.pomo.status -ne 'running' -and -not $state.quiet){Start-RoomPhase 'sofa-nap' 16 4}else{Cancel-RoomActivity}}
            'ball-tap' {$room.roll=@{du=.18;dv=-.10;remaining=.65;chase=$false};Start-RoomPhase 'reaction' 21 2.2}
            'box-enter' {Start-RoomPhase 'box-hide' 25 1.0}
            'box-hide' {Start-RoomPhase 'box-peek' 25 1.2;$script:frame=3}
            'box-peek' {$room.pose=$null;Start-RoomPhase 'reaction' 21 2.2;Set-RoomMessage '被你找到啦！'}
            'food' {$room.foodCount++;if($room.foodCount%2 -eq 0){Start-RoomPhase 'reaction' 21 2.2;Set-RoomMessage '嘿嘿，這份點心我很喜歡。'}else{Cancel-RoomActivity}}
            default {Cancel-RoomActivity}
        }
    }
    if($room.phase -eq 'idle' -and -not $room.roll -and $state.stories -and -not $state.quiet -and $state.pomo.status -ne 'running'){
        if(($clock.ElapsedMilliseconds-$lastInteraction) -gt 300000){Request-RoomAction 'bed' -Automatic}
        elseif($room.time -ge $room.nextAuto){Request-RoomAction (@('sofa','tea','box') | Get-Random) -Automatic}
    }
    if($room.time -ge $room.nextFrame){$script:frame=if($room.phase -in @('bed-sleep','box-peek')){3}elseif($room.phase -eq 'box-enter'){[math]::Min($frame+1,2)}elseif($room.phase -eq 'waking'){0}elseif($row -in @(16,23)){[math]::Min($frame+1,$counts[$row]-1)}else{($frame+1)%$counts[$row]};$room.nextFrame=$room.time+$durations[$row][$frame]/1000.0};Render-Room
}
function Close-Room([switch]$FromWindow) {
    if(-not $room.open){return};Cancel-RoomActivity
    $state.home.left=$room.window.Left;$state.home.top=$room.window.Top;$room.open=$false;if(-not $FromWindow){$room.window.Close()};$room.window=$null;$room.hwnd=[IntPtr]::Zero
    $script:resting='none';$script:lastInteraction=$clock.ElapsedMilliseconds;Set-Animation 0 0;Save-Settings
    if(-not $closing){Update-Visibility;Keep-Visible}
}
function Show-Room {
    if($room.open){if(-not $manualHidden -and -not $fullscreenHidden){$room.window.Show();[void]$room.window.Activate()};return}
    Mark-Activity;$script:pendingClick=$null;$script:drag=$false;$img.ReleaseMouseCapture();Hide-Bubble
    $room.open=$true;$room.u=.45;$room.v=.45;$room.phase='idle';$room.pose=$null;$room.time=0.0;$room.nextFrame=0.0;$room.nextAuto=40.0;$room.roll=$null
    $dialog=[System.Windows.Window]::new();$room.window=$dialog;$dialog.Title='咖凌的小屋';$dialog.Width=880;$dialog.Height=745;$dialog.MinWidth=580;$dialog.MinHeight=500;$dialog.Background='#FFF7F8';$dialog.Topmost=$true;$dialog.FontFamily='Microsoft JhengHei UI';$dialog.ContextMenu=$menu
    $area=[System.Windows.SystemParameters]::WorkArea;$dialog.Width=[math]::Min(880,$area.Width-24);$dialog.Height=[math]::Min(745,$area.Height-24)
    $layout=[System.Windows.Controls.DockPanel]::new();$dialog.Content=$layout
    $bar=[System.Windows.Controls.StackPanel]::new();$bar.Orientation='Horizontal';$bar.Margin='16,12';[System.Windows.Controls.DockPanel]::SetDock($bar,'Top');[void]$layout.Children.Add($bar)
    foreach($entry in @(@('回桌面','close'),@('衣櫃','wardrobe'),@('吃點心','food'),@('專注／繼續','focus'),@('暫停計時','pause'))){$b=[System.Windows.Controls.Button]::new();$b.Content=$entry[0];$b.Tag=$entry[1];$b.Padding='12,6';$b.Margin='0,0,8,0';$b.Add_Click({param($s,$e);switch($s.Tag){'close'{Close-Room};'wardrobe'{Request-RoomAction 'wardrobe'};'food'{$room.foodMenu.PlacementTarget=$s;$room.foodMenu.IsOpen=$true};'focus'{Start-Timer};'pause'{Pause-Timer}}});[void]$bar.Children.Add($b)}
    $room.message=[System.Windows.Controls.TextBlock]::new();$room.message.Text='點家具互動 · 拖動球和紙箱 · 點咖凌摸摸頭';$room.message.Margin='20,8';$room.message.Foreground='#79556A';$room.message.TextWrapping='Wrap';[System.Windows.Controls.DockPanel]::SetDock($room.message,'Bottom');[void]$layout.Children.Add($room.message)
    $room.timerText=[System.Windows.Controls.TextBlock]::new();$room.timerText.Margin='20,0,20,4';$room.timerText.Foreground='#79556A';$room.timerText.Text='右鍵可切換安靜陪伴、日常小劇場與番茄鐘設定';[System.Windows.Controls.DockPanel]::SetDock($room.timerText,'Top');[void]$layout.Children.Add($room.timerText)
    $view=[System.Windows.Controls.Viewbox]::new();$view.Stretch='Uniform';[void]$layout.Children.Add($view)
    $room.canvas=[System.Windows.Controls.Canvas]::new();$room.canvas.Width=900;$room.canvas.Height=650;$room.canvas.ClipToBounds=$true;$view.Child=$room.canvas
    $bg=Add-RoomImage 'room' 900 650;$bg.IsHitTestVisible=$false;$room.visuals=@{}
    foreach($spec in @(@('bed',.18,.66,210,175,450),@('sofa',.75,.20,190,135,425),@('wardrobe',.21,.10,118,170,325),@('table',.75,.65,135,85,510),@('box',.20,.33,102,75,400),@('ball',.77,.90,36,36,550))){
        $name=[string]$spec[0];$visual=Add-RoomImage $name $spec[3] $spec[4];$visual.Tag=$name;$visual.Cursor='Hand';$p=Get-RoomPoint $spec[1] $spec[2];Place-RoomVisual $visual ($p.x-$spec[3]/2) ($p.y-$spec[4]) $spec[5];$room.visuals[$name]=$visual
        $visual.ToolTip=@{bed='小床：休息／叫醒';sofa='沙發：抱枕放空';wardrobe='衣櫃：換衣服';table='茶几：選點心';box='紙箱：點一下躲貓貓，拖曳搬動';ball='球：點擊或拖動來玩'}[$name]
        $visual.Add_MouseLeftButtonDown({param($s,$e);$e.Handled=$true;if($s.Tag -in @('ball','box')){Begin-RoomToy $s.Tag ($e.GetPosition($room.canvas));[void]$s.CaptureMouse()}elseif($s.Tag -eq 'table'){$room.foodMenu.PlacementTarget=$s;$room.foodMenu.IsOpen=$true}elseif($s.Tag -eq 'bed' -and $room.phase -in @('bed-sleep','bed-tuck','bed-sit')){Request-RoomAction 'wake'}else{Request-RoomAction $s.Tag}})
        if($name -in @('ball','box')){$visual.Add_MouseMove({param($s,$e);if($room.drag){Move-RoomToy ($e.GetPosition($room.canvas))}});$visual.Add_MouseLeftButtonUp({param($s,$e);End-RoomToy;$e.Handled=$true});$visual.Add_LostMouseCapture({if($room.drag){$room.drag=$null;Render-Room}})}
    }
    $room.actor=[System.Windows.Controls.Image]::new();$room.actor.Width=144;$room.actor.Height=156;$room.actor.Cursor='Hand';[void]$room.canvas.Children.Add($room.actor)
    $room.actor.Add_MouseLeftButtonDown({param($s,$e);$e.Handled=$true;Request-RoomAction $(if($room.phase -in @('bed-sleep','bed-tuck','sofa-nap')){'wake'}else{'pet'})})
    $room.bedFront=Add-RoomImage 'bed' 210 175;$room.bedFront.Clip=[System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0,105,210,70));$room.bedFront.IsHitTestVisible=$false
    $p=Get-RoomPoint .18 .66;Place-RoomVisual $room.bedFront ($p.x-105) ($p.y-175) 460
    $room.boxFront=Add-RoomImage 'box' 102 75;$room.boxFront.Clip=[System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0,42,102,33));$room.boxFront.IsHitTestVisible=$false
    $room.foodMenu=[System.Windows.Controls.ContextMenu]::new();foreach($entry in @(@('餅乾','cookie'),@('布丁','pudding'),@('茶','tea'))){$item=[System.Windows.Controls.MenuItem]::new();$item.Header=$entry[0];$item.Tag=$entry[1];$item.Add_Click({param($s,$e);Request-RoomAction $s.Tag});[void]$room.foodMenu.Items.Add($item)}
    $dialog.Add_SourceInitialized({$room.hwnd=([System.Windows.Interop.WindowInteropHelper]::new($room.window)).Handle})
    $dialog.Add_Closing({param($s,$e);if($room.open){Close-Room -FromWindow}})
    $dialog.Add_LocationChanged({if($room.open -and $room.window.IsLoaded){$state.home.left=$room.window.Left;$state.home.top=$room.window.Top}})
    $dialog.WindowStartupLocation='Manual';$dialog.Left=if($null -ne $state.home.left){$state.home.left}else{$area.Left+($area.Width-$dialog.Width)/2};$dialog.Top=if($null -ne $state.home.top){$state.home.top}else{$area.Top+($area.Height-$dialog.Height)/2}
    Set-Animation 0 0;$w.Hide();$dialog.Show();Keep-RoomVisible;Render-Room;Update-Visibility;Update-Badge
}
