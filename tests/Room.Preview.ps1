# Optional real-WPF animation recording; uses the same controller and renderer as the app.
$recordings=Join-Path $dataDirectory 'recordings';[void][IO.Directory]::CreateDirectory($recordings)
$manifest=@();$state.stories=$false;$state.quiet=$false;Reset-Pomodoro $state
foreach($scene in @(@('bed','uniform',12),@('sofa','pajamas',8),@('box','hoodie',9),@('ball','uniform',7),@('tea','pajamas',8))){
    Close-Room;Select-Outfit $scene[1];$state.home=New-HomeState;Show-Room;Pump;Request-RoomAction $scene[0]
    $folder=Join-Path $recordings $scene[0];[void][IO.Directory]::CreateDirectory($folder);$n=0
    for($k=0;$k -lt [int]$scene[2]*5;$k++){
        if($scene[0] -eq 'bed' -and $k -eq 43){Request-RoomAction 'wake'}
        Update-Room .1;Update-Room .1;Capture-Room ('recordings\'+$scene[0]+'\'+('{0:000}' -f $n)+'.png');$n++
    }
    $manifest+=@{action=$scene[0];outfit=$scene[1];frames=$n;frameMilliseconds=200}
}
$manifest | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $recordings 'manifest.json') -Encoding UTF8
$room.window.UpdateLayout();Pump
$render=[System.Windows.Media.Imaging.RenderTargetBitmap]::new([int]$room.window.ActualWidth,[int]$room.window.ActualHeight,96,96,[System.Windows.Media.PixelFormats]::Pbgra32);$render.Render($room.window)
$encoder=[System.Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($render))
$stream=[IO.File]::Create((Join-Path $dataDirectory 'room-window.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
Close-Room
