function Get-PlayPhotoPath([string]$File) {
    if($File -notmatch '^[a-f0-9]{32}\.png$'){throw 'Invalid photo filename'}
    return Join-Path (Join-Path $dataDirectory 'photos') $File
}
function Load-PlayPhoto([string]$File) {
    $c=Get-PlayCare;if(-not @($c.photos|Where-Object file -eq $File).Count){return $false}
    $path=Get-PlayPhotoPath $File;if(-not (Test-Path -LiteralPath $path)){$play.notice='這張照片檔案不在相簿資料夾，其他回憶仍然保留。';Refresh-PlayData;return $false}
    try{$image=[Windows.Media.Imaging.BitmapImage]::new();$image.BeginInit();$image.CacheOption='OnLoad';$image.UriSource=[Uri]$path;$image.EndInit();$image.Freeze();$play.stage.PhotoSource=$image;$play.photoFile=$File;$play.notice='這是已拍下的明信片，可以另存或回到拍攝。';Refresh-PlayData;return $true}
    catch{$play.notice='這張照片暫時讀不到，可以選其他張。';Refresh-PlayData;return $false}
}
function Refresh-PlayAlbum {
    if(-not $play -or -not $play.album){return};$play.album.Items.Clear()
    foreach($photo in (Get-PlayCare).photos){$item=[Windows.Controls.ComboBoxItem]::new();$item.Content=$photo.day+' · '+$photo.caption;$item.Tag=$photo.file;[void]$play.album.Items.Add($item)}
}
function Initialize-PlayPhotoOptions {
    $play.stage.PhotoRow=0
    $play.pose=Add-PlayChoice $play.options '姿勢' @('待機','揮手','跳躍','摸摸','坐下','睡覺','伸展')
    $play.pose.Add_SelectionChanged({if($play -and $play.mode -eq 'photo'){$play.stage.PhotoRow=@(0,3,4,11,15,16,17)[$play.pose.SelectedIndex];$play.stage.InvalidateVisual()}})
    $play.photoFrame=Add-PlayChoice $play.options '相框' @('奶油','粉玫瑰','薄荷');$play.photoFrame.SelectedIndex=@('cream','rose','mint').IndexOf($state.play.frame)
    $play.photoFrame.Add_SelectionChanged({if($play -and $play.mode -eq 'photo'){$state.play.frame=@('cream','rose','mint')[$play.photoFrame.SelectedIndex];$play.stage.FrameColor=$state.play.frame;Save-Settings;$play.stage.InvalidateVisual()}})
    $play.caption=[Windows.Controls.TextBox]::new();$play.caption.Text=$play.stage.Caption;$play.caption.MaxLength=32;$play.caption.Width=240;$play.caption.Margin=4;$play.caption.Padding=6;$play.caption.ToolTip='明信片短句，最多 32 個字';$play.caption.Add_TextChanged({param($s,$e);if($play -and $play.mode -eq 'photo'){$play.stage.Caption=$s.Text;$play.stage.InvalidateVisual()}});[void]$play.options.Children.Add($play.caption)
    $play.album=Add-PlayChoice $play.options '相簿' @();$play.album.Width=220;$play.album.Add_SelectionChanged({if($play -and $play.mode -eq 'photo' -and $play.album.SelectedItem){$null=Load-PlayPhoto ([string]$play.album.SelectedItem.Tag)}});Refresh-PlayAlbum
    $back=New-PlayButton '回拍攝' {$play.stage.PhotoSource=$null;$play.photoFile=$null;$play.album.SelectedIndex=-1;$play.notice='準備好，拍一張新的吧。';Refresh-PlayData};[void]$play.extra.Children.Add($back)
    $export=New-PlayButton '另存 PNG…' {
        if(-not $play.photoFile){$play.notice='先拍一張，或從相簿選照片。';Refresh-PlayData;return}
        $dialog=[Microsoft.Win32.SaveFileDialog]::new();$dialog.Filter='PNG 圖片 (*.png)|*.png';$dialog.FileName=$character.displayName+'-明信片.png';$dialog.AddExtension=$true
        if($dialog.ShowDialog($playWindow)){$null=Export-PlayPhoto $play.photoFile $dialog.FileName}
    };[void]$play.extra.Children.Add($export)
    $remove=New-PlayButton '刪除此張' {if($play.photoFile){$null=Remove-PlayPhoto $play.photoFile}else{$play.notice='先從相簿選一張照片。';Refresh-PlayData}};[void]$play.extra.Children.Add($remove)
}
function Save-PlayPhoto {
    $c=Get-PlayCare;if($c.photos.Count -ge 48){$play.notice='相簿已有 48 張，可以先另存與刪除不要的照片。';Refresh-PlayData;return $false}
    $play.stage.PhotoSource=$null;$play.stage.UpdateLayout();$play.stage.InvalidateVisual();$play.stage.UpdateLayout()
    $file=[guid]::NewGuid().ToString('N')+'.png';$path=Get-PlayPhotoPath $file
    try{
        [void][IO.Directory]::CreateDirectory((Split-Path $path -Parent))
        $image=$play.stage.Snapshot()
        $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($image));$stream=[IO.File]::Create($path);try{$encoder.Save($stream)}finally{$stream.Dispose()}
        $caption=$play.stage.Caption;if(-not $caption){$caption='今天，也一起度過了。'}
        $c.photos+=,@{file=$file;caption=$caption;day=[DateTime]::Now.ToString('yyyy-MM-dd')};Add-PlayEvent $c 'photo' '拍下了一張今天的明信片。';Save-Settings
        Refresh-PlayAlbum;$play.photoFile=$file;$play.album.SelectedIndex=$play.album.Items.Count-1;$play.notice='拍好了！照片已存進這位夥伴的相簿。';Refresh-PlayData;return $true
    }catch{$play.notice='照片暫時無法儲存，請確認資料夾仍可寫入。';Refresh-PlayData;return $false}
}
function Export-PlayPhoto([string]$File,[string]$Destination) {
    if(-not @((Get-PlayCare).photos|Where-Object file -eq $File).Count){return $false}
    try{[IO.File]::Copy((Get-PlayPhotoPath $File),$Destination,$true);$play.notice='PNG 已另存。';Refresh-PlayData;return $true}
    catch{$play.notice='這個位置暫時無法另存，請換個資料夾。';Refresh-PlayData;return $false}
}
function Remove-PlayPhoto([string]$File) {
    $c=Get-PlayCare;if(-not @($c.photos|Where-Object file -eq $File).Count){return $false}
    try{[IO.File]::Delete((Get-PlayPhotoPath $File));$c.photos=@($c.photos|Where-Object file -ne $File);$play.stage.PhotoSource=$null;$play.photoFile=$null;Refresh-PlayAlbum;Save-Settings;$play.notice='這張照片已刪除，紀念章仍會保留。';Refresh-PlayData;return $true}
    catch{$play.notice='這張照片暫時無法刪除。';Refresh-PlayData;return $false}
}
