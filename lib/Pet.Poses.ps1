# Pose atlases stay intact on disk. Render keyed transforms once into the same
# 192 x 208 frame contract used by legacy pixel atlases, then cache the bitmaps.
function Get-PoseFrame($Atlas, $Entry, $Key) {
    if ($Key.pose -lt 0 -or $Key.pose -ge $Entry.poseRects.Count) { throw 'Invalid pose index' }
    $r = $Entry.poseRects[$Key.pose]
    if ($r.Count -ne 4 -or $r[0] -lt 0 -or $r[1] -lt 0 -or $r[2] -le 0 -or $r[3] -le 0 -or $r[0]+$r[2] -gt $Atlas.PixelWidth -or $r[1]+$r[3] -gt $Atlas.PixelHeight) { throw 'Invalid pose bounds' }
    $crop = [System.Windows.Media.Imaging.CroppedBitmap]::new($Atlas, [System.Windows.Int32Rect]::new($r[0], $r[1], $r[2], $r[3]))
    $visual = [System.Windows.Media.DrawingVisual]::new(); $dc = $visual.RenderOpen()
    $dc.PushClip([System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0,0,192,208)))
    $sx = if ($null -eq $Key.sx) { 1.0 } else { [double]$Key.sx }
    $sy = if ($null -eq $Key.sy) { 1.0 } else { [double]$Key.sy }
    if ($Key.flip) { $sx = -$sx }
    $dc.PushTransform([System.Windows.Media.TranslateTransform]::new([double]$Key.x,[double]$Key.y))
    $dc.PushTransform([System.Windows.Media.RotateTransform]::new([double]$Key.angle,96,190))
    $dc.PushTransform([System.Windows.Media.ScaleTransform]::new($sx,$sy,96,190))
    $width = $r[2]*$Entry.poseScale; $height = $r[3]*$Entry.poseScale
    $dc.DrawImage($crop,[System.Windows.Rect]::new(96-$width/2,190-$height,$width,$height))
    $dc.Pop(); $dc.Pop(); $dc.Pop(); $dc.Pop(); $dc.Close()
    $frame = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(192,208,96,96,[System.Windows.Media.PixelFormats]::Pbgra32)
    $frame.Render($visual); $frame.Freeze(); return $frame
}
