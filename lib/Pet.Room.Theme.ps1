# Image sources are cached by theme and object; generated atlas pixels are kept intact.
$script:roomThemes=$null;$script:roomBitmapCache=@{}
function Get-RoomTheme {
    if(-not $roomThemes){$script:roomThemes=Get-Content (Join-Path $root 'assets/room/themes.json') -Raw -Encoding UTF8 | ConvertFrom-Json}
    $id=if($character.roomTheme){[string]$character.roomTheme}else{'kaling'}
    $theme=$roomThemes.$id;if(-not $theme){throw "Unknown room theme: $id"};return $theme
}
function Get-RoomText([string]$Key,[string]$Fallback) {
    $theme=Get-RoomTheme
    if($theme.dialogue.$Key){return [string]$theme.dialogue.$Key};return $Fallback
}
function Get-RoomBitmap([string]$Name) {
    $theme=Get-RoomTheme;$key=$theme.id+'/'+$Name
    if($roomBitmapCache.ContainsKey($key)){return $roomBitmapCache[$key]}
    $source=$theme.assets.$Name;if(-not $source){throw "Missing room asset: $key"}
    $bitmap=[System.Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad'
    $bitmap.UriSource=[Uri](Join-Path $root $source.file);$bitmap.EndInit();$bitmap.Freeze()
    if($source.rect){$r=$source.rect;$bitmap=[System.Windows.Media.Imaging.CroppedBitmap]::new($bitmap,[System.Windows.Int32Rect]::new($r[0],$r[1],$r[2],$r[3]));$bitmap.Freeze()}
    $roomBitmapCache[$key]=$bitmap;return $bitmap
}
function Update-RoomTheme {
    if(-not $room.open){return}
    $theme=Get-RoomTheme;$room.theme=$theme.id;$room.window.Title=$theme.title;$room.window.Background=$theme.background
    $room.backgroundVisual.Source=Get-RoomBitmap 'room'
    foreach($name in $room.visuals.Keys){$room.visuals[$name].Source=Get-RoomBitmap $name;$room.visuals[$name].ToolTip=$theme.tooltips.$name}
    $room.bedFront.Source=Get-RoomBitmap 'bed';$room.boxFront.Source=Get-RoomBitmap 'box'
    $room.message.Foreground=$theme.foreground;$room.timerText.Foreground=$theme.foreground
    foreach($button in $room.buttons){$button.Background=$theme.button;$button.Foreground=$theme.foreground;$button.BorderBrush=$theme.border}
    Set-RoomMessage $theme.welcome;Render-Room
}
