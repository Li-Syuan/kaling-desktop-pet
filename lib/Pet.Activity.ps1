# Desktop attacks and room actions are mutually exclusive; entering the room cancels the desktop activity.
$script:activity=@{kind='idle';generation=0}
$script:trayAttackItems=@();$script:fxWindow=$null;$script:fxFrames=@{};$script:attackItems=@();$script:characterItems=@()
function Stop-Activity {
    if($playWindow){Close-Play}
    Cancel-CareActivity
    if($activity.kind -eq 'attack'){
        $w.Left=$activity.originLeft;$img.RenderTransform=[System.Windows.Media.Transform]::Identity
        $script:actionUntil=0;$script:row=0;$script:frame=0
        if($frames){$img.Source=$frames['0,0']}
    }
    $activity.generation++;$activity.kind='idle'
    if($fxWindow){$fxWindow.Hide()}
}
function Get-AttackBlockReason([switch]$AllowRoom) {
    if($state.character -ne 'ren'){return '請先從「角色」選單切換成蓮。'}
    if($closing){return '程式正在關閉。'}
    if($manualHidden -or $fullscreenHidden){return '角色隱藏中，顯示後即可施放。'}
    if($state.pomo.status -eq 'running'){return '番茄鐘運行中，請先暫停計時。'}
    if($state.quiet){return '安靜陪伴已開啟，關閉後即可施放。'}
    if($drag -or $room.drag){return '請先放開正在拖曳的角色或玩具。'}
    if($wardrobeWindow -or $settingsWindow){return '請先關閉衣櫃或番茄鐘設定視窗。'}
    if($room.open -and -not $AllowRoom){return '請回到桌面施放劍術。'}
    return ''
}
function Test-AttackAllowed {return [string]::IsNullOrEmpty((Get-AttackBlockReason))}
function Request-Attack([string]$Id) {
    $reason=Get-AttackBlockReason -AllowRoom
    if($reason){Show-Bubble $reason -Important;return $false}
    if(-not @($character.attacks | Where-Object id -eq $Id).Count){return $false}
    # The label explicitly promises returning to the desktop before performing.
    if($room.open){Close-Room}
    return Start-Attack $Id
}
function Update-CharacterMenus {
    $reason=Get-AttackBlockReason -AllowRoom;$enabled=[string]::IsNullOrEmpty($reason)
    $status=if($reason){$reason}elseif($room.open){'選招後收合小屋，回桌面施放。'}else{'選擇招式即可施放；預設無聲。'}
    if($attackStatusItem){$attackStatusItem.Header=$status}
    if($trayAttackStatusItem){$trayAttackStatusItem.Text=$status}
    foreach($item in $attackItems){$item.IsEnabled=$enabled;$item.ToolTip=$status;$item.Header=$(if($room.open){'回桌面施放 · '}else{''})+$attackLabels[[string]$item.Tag]}
    foreach($item in $trayAttackItems){$item.Enabled=$enabled;$item.ToolTipText=$status;$item.Text=$(if($room.open){'回桌面施放 · '}else{''})+$attackLabels[[string]$item.Tag]}
    foreach($pair in $characterItems){
        if($pair.item -is [System.Windows.Controls.MenuItem]){$pair.item.IsChecked=$state.character -eq $pair.id}
        else{$pair.item.Checked=$state.character -eq $pair.id}
    }
}
function Initialize-CharacterMenu {
    $group=Add-Menu '角色' $null
    foreach($entry in $characterCatalog.characters){
        $item=Add-Menu $entry.displayName {param($s,$e);Select-Character ([string]$s.Tag)} $group
        $item.Tag=$entry.id;$item.IsCheckable=$true;$script:characterItems+=@{item=$item;id=$entry.id}
    }
    $group=Add-Menu '劍術 · 蓮' $null
    $script:attackLabels=@{}
    $script:attackStatusItem=Add-Menu '選擇招式即可施放。' $null $group;$attackStatusItem.IsEnabled=$false
    foreach($entry in @($characterCatalog.characters | Where-Object id -eq 'ren')[0].attacks){
        $attackLabels[[string]$entry.id]=$entry.name
        $item=Add-Menu $entry.name {param($s,$e);$null=Request-Attack ([string]$s.Tag)} $group
        $item.Tag=$entry.id;$script:attackItems+=$item
    }
    $menu.Add_Opened({Update-CharacterMenus})
}
function Initialize-CharacterTray {
    $group=[System.Windows.Forms.ToolStripMenuItem]::new('角色');[void]$trayMenu.Items.Add($group)
    foreach($entry in $characterCatalog.characters){
        $item=[System.Windows.Forms.ToolStripMenuItem]::new($entry.displayName);$item.Tag=$entry.id
        $item.Add_Click({param($s,$e);Select-Character ([string]$s.Tag)});[void]$group.DropDownItems.Add($item)
        $script:characterItems+=@{item=$item;id=$entry.id}
    }
    $group=[System.Windows.Forms.ToolStripMenuItem]::new('劍術 · 蓮');[void]$trayMenu.Items.Add($group)
    $script:trayAttackStatusItem=[System.Windows.Forms.ToolStripMenuItem]::new('選擇招式即可施放。');$trayAttackStatusItem.Enabled=$false;[void]$group.DropDownItems.Add($trayAttackStatusItem)
    foreach($entry in @($characterCatalog.characters | Where-Object id -eq 'ren')[0].attacks){
        $item=[System.Windows.Forms.ToolStripMenuItem]::new($entry.name);$item.Tag=$entry.id
        $item.Add_Click({param($s,$e);$null=Request-Attack ([string]$s.Tag)});[void]$group.DropDownItems.Add($item)
        # WinForms uses Enabled, WPF uses IsEnabled. Keep a separate collection.
        $script:trayAttackItems+=,$item
    }
    $trayMenu.Add_Opening({Update-CharacterMenus})
}
function Get-WorkArea {
    $area=[System.Windows.Forms.Screen]::FromHandle($hwnd).WorkingArea
    $m=([System.Windows.PresentationSource]::FromVisual($w)).CompositionTarget.TransformFromDevice
    $a=$m.Transform([System.Windows.Point]::new($area.Left,$area.Top));$b=$m.Transform([System.Windows.Point]::new($area.Right,$area.Bottom))
    return @{Left=$a.X;Top=$a.Y;Right=$b.X;Bottom=$b.Y}
}
function Initialize-Effects {
    if($fxWindow){return}
    $atlas=[System.Windows.Media.Imaging.BitmapImage]::new()
    $atlas.BeginInit();$atlas.CacheOption='OnLoad';$atlas.UriSource=[Uri](Join-Path $root 'assets/characters/ren/effects.png');$atlas.EndInit();$atlas.Freeze()
    if($atlas.PixelWidth -ne 2048 -or $atlas.PixelHeight -ne 1536){throw 'Invalid effect atlas'}
    for($r=0;$r -lt 3;$r++){for($c=0;$c -lt 4;$c++){
        $f=[System.Windows.Media.Imaging.CroppedBitmap]::new($atlas,[System.Windows.Int32Rect]::new($c*512,$r*512,512,512));$f.Freeze();$fxFrames["$r,$c"]=$f
    }}
    $script:fxWindow=[System.Windows.Window]::new();$fxWindow.Title='蓮 · 劍術特效'
    $fxWindow.WindowStyle='None';$fxWindow.ResizeMode='NoResize';$fxWindow.AllowsTransparency=$true;$fxWindow.Background='Transparent'
    $fxWindow.Topmost=$true;$fxWindow.ShowInTaskbar=$false;$fxWindow.ShowActivated=$false;$fxWindow.IsHitTestVisible=$false;$fxWindow.Owner=$w
    $script:fxCanvas=[System.Windows.Controls.Canvas]::new();$fxCanvas.ClipToBounds=$true;$fxWindow.Content=$fxCanvas
    $script:ghosts=@()
    foreach($i in 0..1){$g=[System.Windows.Controls.Image]::new();$g.IsHitTestVisible=$false;[void]$fxCanvas.Children.Add($g);$script:ghosts+=,$g}
    $script:fxImage=[System.Windows.Controls.Image]::new();$fxImage.IsHitTestVisible=$false;$fxImage.Stretch='Uniform';[void]$fxCanvas.Children.Add($fxImage)
    $fxWindow.Add_SourceInitialized({$script:fxHandle=([System.Windows.Interop.WindowInteropHelper]::new($fxWindow)).Handle;[KalingNative]::ClickThrough($fxHandle,$true)})
}
function Start-Attack([string]$Id) {
    if(-not (Test-AttackAllowed)){return $false}
    $spec=@($character.attacks | Where-Object id -eq $Id)[0];if(-not $spec){return $false}
    Mark-Activity;Hide-Bubble;$script:pendingClick=$null;Initialize-Effects
    $area=Get-WorkArea;$center=$w.Left+$w.Width/2
    $dir=if($area.Right-$center -ge $center-$area.Left){1}else{-1}
    $size=[math]::Min(440*$state.scale,[math]::Min($area.Right-$area.Left,$area.Bottom-$area.Top))
    $fxWindow.Width=$size;$fxWindow.Height=$size
    $bounds=Limit-PetPosition ($center-$size/2+$dir*$size*0.13) ($w.Top+88+104*$state.scale-$size/2) $size $size $area
    $fxWindow.Left=$bounds.left;$fxWindow.Top=$bounds.top;$fxImage.Width=$size;$fxImage.Height=$size
    $fxImage.RenderTransformOrigin=[System.Windows.Point]::new(.5,.5);$fxImage.RenderTransform=[System.Windows.Media.ScaleTransform]::new($dir,1)
    [System.Windows.Controls.Canvas]::SetLeft($fxImage,0);[System.Windows.Controls.Canvas]::SetTop($fxImage,0)
    Set-Animation $spec.row $spec.duration
    $script:activity=@{kind='attack';generation=($activity.generation+1);spec=$spec;start=$clock.ElapsedMilliseconds;originLeft=$w.Left;direction=$dir;area=$area}
    $img.RenderTransformOrigin=[System.Windows.Point]::new(.5,.5);$img.RenderTransform=[System.Windows.Media.ScaleTransform]::new($dir,1)
    $fxImage.Opacity=0;foreach($g in $ghosts){$g.Opacity=0};$fxWindow.Show();Step-Attack $clock.ElapsedMilliseconds
    return $true
}
function Step-Attack([long]$Now) {
    if($activity.kind -ne 'attack'){return}
    if(-not (Test-AttackAllowed) -or -not $w.IsVisible){Stop-Activity;return}
    $spec=$activity.spec;$p=[math]::Max(0.0,($Now-$activity.start)/[double]$spec.duration)
    if($p -ge 1){Stop-Activity;Set-Animation 0 0;return}
    $index=[math]::Min(3,[int][math]::Floor($p*4));$script:frame=$index;$img.Source=$frames["$($spec.row),$index"]
    $f=-1;for($i=0;$i -lt 4;$i++){if($p -ge $spec.cues[$i]){$f=$i}}
    if($f -ge 0){$fxImage.Source=$fxFrames["$($spec.fxRow),$f"];$fxImage.Opacity=[math]::Min(1.0,[math]::Max(0.0,(1-$p)*5))}else{$fxImage.Opacity=0}
    $dash=if($spec.id -eq 'combo'){[math]::Sin([math]::PI*$p)*24*$state.scale*$activity.direction}else{0}
    $pos=Limit-PetPosition ($activity.originLeft+$dash) $w.Top $w.Width $w.Height $activity.area;$w.Left=$pos.left
    for($i=0;$i -lt 2;$i++){
        $g=$ghosts[$i];$g.Opacity=if($spec.id -eq 'combo' -and $p -ge .22 -and $p -lt .75){.23-($i*.08)}else{0}
        $g.Source=$frames["$($spec.row),$index"];$g.Width=192*$state.scale;$g.Height=208*$state.scale
        $g.RenderTransformOrigin=[System.Windows.Point]::new(.5,.5);$g.RenderTransform=[System.Windows.Media.ScaleTransform]::new($activity.direction,1)
        [System.Windows.Controls.Canvas]::SetLeft($g,$w.Left-$fxWindow.Left-($i+1)*22*$state.scale*$activity.direction)
        [System.Windows.Controls.Canvas]::SetTop($g,$w.Top+88-$fxWindow.Top)
    }
}
