# Optional real WPF animation capture, enabled by -WorldPreview with -SelfTest.
Close-World;Close-Room;Close-Play;Reset-Pomodoro $state
$state.care.enabled=$false;$state.stories=$false;$state.quiet=$false;$state.play.weather='sun';$state.world=New-WorldState
Select-Character 'ren';$state.world.companion='slime';Show-World;Pump
$path=Join-Path $dataDirectory 'world-film';[void][IO.Directory]::CreateDirectory($path)
$null=$world.session.StartStory('sword')
for($i=0;$i -lt 400;$i++){
    $world.session.Step(.1);Refresh-World
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($world.stage.Snapshot()))
    $stream=[IO.File]::Create((Join-Path $path ($i.ToString('0000')+'.png')));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
Close-World
