function Read-OutfitCatalog([string]$Root) {
    $all=Get-Content -LiteralPath (Join-Path $Root 'assets/characters/catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if($all.schemaVersion -ne 1){throw 'Invalid character catalog'}
    foreach($character in $all.characters){
        foreach($entry in $character.outfits){
            if(@($entry.actions).Count -ne @($entry.counts).Count -or $entry.counts.Count -lt 21){throw 'Incomplete actions'}
            for($i=0;$i -lt $entry.counts.Count;$i++){
                if($entry.counts[$i] -lt 1 -or $entry.counts[$i] -gt 8 -or $entry.actions[$i].row -ne $i -or $entry.actions[$i].frameMs -le 0){throw 'Invalid animation metadata'}
            }
        }
    }
    $script:characterCatalog=$all
    $script:character=@($all.characters | Where-Object id -eq $state.character)[0]
    if(-not $script:character){throw 'Unknown character'}
    return $script:character
}
function Get-CharacterText([string]$Key,[string]$Fallback) {
    if($character.dialogue -and $character.dialogue.$Key){return [string]$character.dialogue.$Key};return $Fallback
}
function Select-Character([string]$Id) {
    $next=@($characterCatalog.characters | Where-Object id -eq $Id)[0]
    if(-not $next){throw 'Unknown character'}
    if($wardrobeWindow){$wardrobeWindow.Close()}
    if($room.open){Cancel-RoomActivity}
    Mark-Activity;Hide-Bubble;$script:pendingClick=$null;$script:cooldownUntil=0
    $script:state.characterOutfits[$state.character]=$state.outfit
    $script:state.character=$Id;$script:character=$next;$script:catalog=$next
    Select-Outfit $state.characterOutfits[$Id]
    $w.Title=$next.displayName+' · 陪伴日常';if($room.open){Update-RoomTheme};Update-Badge;Update-CharacterMenus
    Show-Bubble (Get-CharacterText 'hello' '你好！今天也一起度過吧。')
}
function Get-OutfitAssets([string]$Id) {
    $cacheKey=$state.character+'/'+$Id
    if($script:outfitCache.ContainsKey($cacheKey)){return $script:outfitCache[$cacheKey]}
    $entry=@($script:catalog.outfits | Where-Object id -eq $Id)[0]
    if(-not $entry){throw 'Unknown outfit'}
    $atlas=[System.Windows.Media.Imaging.BitmapImage]::new()
    $atlas.BeginInit();$atlas.CacheOption='OnLoad';$atlas.UriSource=[Uri](Join-Path $script:root $entry.atlas);$atlas.EndInit();$atlas.Freeze()
    if($atlas.PixelWidth -ne 1536 -or $atlas.PixelHeight -ne (208*$entry.counts.Count)){throw 'Invalid outfit atlas dimensions'}
    $frames=@{}
    for($r=0;$r -lt $entry.counts.Count;$r++){for($c=0;$c -lt $entry.counts[$r];$c++){
        $frame=[System.Windows.Media.Imaging.CroppedBitmap]::new($atlas,[System.Windows.Int32Rect]::new($c*192,$r*208,192,208));$frame.Freeze();$frames["$r,$c"]=$frame
    }}
    $thumb=[System.Windows.Media.Imaging.BitmapImage]::new()
    $thumb.BeginInit();$thumb.CacheOption='OnLoad';$thumb.UriSource=[Uri](Join-Path $script:root $entry.portrait);$thumb.EndInit();$thumb.Freeze()
    $result=@{entry=$entry;frames=$frames;thumbnail=$thumb;counts=@($entry.counts)}
    $script:outfitCache[$cacheKey]=$result;return $result
}
function Select-Outfit([string]$Id,[switch]$Celebrate) {
    $assets=Get-OutfitAssets $Id
    $script:frames=$assets.frames;$script:counts=$assets.counts;$script:state.outfit=$Id;$state.characterOutfits[$state.character]=$Id
    $script:durations=@()
    for($r=0;$r -lt $counts.Count;$r++){
        $speed=$assets.entry.actions[$r].frameMs
        $timings=@();for($c=0;$c -lt $counts[$r];$c++){$timings+=$speed};$script:durations+=,$timings
    }
    if($script:loaded){
        if($room.open){Cancel-RoomActivity}
        Mark-Activity
        if($Celebrate){Set-Animation 18 1440;Show-Bubble ('換上'+$assets.entry.displayName+'，陪你開始新的日常！')}else{Set-Animation 0 0}
        if($room.open){$room.phase='reaction';$room.until=$room.time+1.44;Render-Room}
        Save-Settings
        if($script:wardrobeButtons){foreach($key in $script:wardrobeButtons.Keys){$script:wardrobeButtons[$key].Content=if($key -eq $Id){'正在穿這套'}else{'穿上這套'};$script:wardrobeButtons[$key].IsEnabled=$key -ne $Id}}
    }
}
function Show-Wardrobe {
    if($script:wardrobeWindow){[void]$script:wardrobeWindow.Activate();return}
    if($room.open){Cancel-RoomActivity}
    Mark-Activity;Set-Animation 0 0
    $script:wardrobeWindow=[System.Windows.Window]::new();$dialog=$script:wardrobeWindow
    $dialog.Title=$character.displayName+'衣櫃';$dialog.Width=640;$dialog.Height=420;$dialog.ResizeMode='NoResize';$dialog.WindowStartupLocation='CenterScreen';$dialog.Background='#FFF5F8'
    $layout=[System.Windows.Controls.StackPanel]::new();$layout.Margin=18;$dialog.Content=$layout
    $title=[System.Windows.Controls.TextBlock]::new();$title.Text=$character.displayName+' · 今天的衣裝';$title.FontSize=20;$title.Foreground='#673D54';$title.Margin='0,0,0,6';[void]$layout.Children.Add($title)
    $note=[System.Windows.Controls.TextBlock]::new();$note.Text='每套都有完整動作。換裝立即生效，下次開啟會記得。';$note.FontSize=12;$note.Foreground='#876878';$note.Margin='0,0,0,16';[void]$layout.Children.Add($note)
    $cards=[System.Windows.Controls.Primitives.UniformGrid]::new();$cards.Columns=$catalog.outfits.Count;[void]$layout.Children.Add($cards);$script:wardrobeButtons=@{}
    foreach($entry in $script:catalog.outfits){
        $assets=Get-OutfitAssets $entry.id
        $card=[System.Windows.Controls.Border]::new();$card.Background='White';$card.BorderBrush='#EACAD8';$card.BorderThickness=1;$card.CornerRadius=14;$card.Margin=5;$card.Padding=10
        $stack=[System.Windows.Controls.StackPanel]::new();$card.Child=$stack
        $image=[System.Windows.Controls.Image]::new();$image.Source=$assets.thumbnail;$image.Height=178;$image.Stretch='Uniform';[void]$stack.Children.Add($image)
        $name=[System.Windows.Controls.TextBlock]::new();$name.Text=$entry.displayName;$name.FontSize=16;$name.TextAlignment='Center';$name.Margin='0,8,0,3';$name.Foreground='#673D54';[void]$stack.Children.Add($name)
        $caption=[System.Windows.Controls.TextBlock]::new();$caption.Text=$entry.description;$caption.FontSize=11;$caption.TextAlignment='Center';$caption.Foreground='#876878';$caption.Margin='0,0,0,10';[void]$stack.Children.Add($caption)
        $button=[System.Windows.Controls.Button]::new();$button.Tag=$entry.id;$button.Content=if($entry.id -eq $state.outfit){'正在穿這套'}else{'穿上這套'};$button.IsEnabled=$entry.id -ne $state.outfit;$button.Height=30
        $button.Add_Click({param($sender,$e);Select-Outfit ([string]$sender.Tag) -Celebrate})
        [void]$stack.Children.Add($button);$script:wardrobeButtons[$entry.id]=$button;[void]$cards.Children.Add($card)
    }
    $dialog.Add_Closed({$script:wardrobeWindow=$null;$script:wardrobeButtons=$null});$dialog.Show();[void]$dialog.Activate()
}
