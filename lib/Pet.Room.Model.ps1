function New-HomeState {
    return @{left=$null;top=$null;ball=@{u=0.77;v=0.90};box=@{u=0.20;v=0.33}}
}
function Get-RoomPoint([double]$U,[double]$V) {return @{x=450+360*($U-$V);y=260+170*($U+$V)}}
function Get-RoomUV([double]$X,[double]$Y) {return @{u=(($Y-260)/170+($X-450)/360)/2;v=(($Y-260)/170-($X-450)/360)/2}}
function Test-RoomFloor([double]$U,[double]$V) {
    if([double]::IsNaN($U) -or [double]::IsNaN($V) -or $U -lt 0.06 -or $U -gt 0.94 -or $V -lt 0.06 -or $V -gt 0.94){return $false}
    foreach($r in @(@(0.05,0.31,0.47,0.88),@(0.57,0.93,0.07,0.30),@(0.64,0.87,0.55,0.76),@(0.13,0.30,0.04,0.22))){
        if($U -ge $r[0] -and $U -le $r[1] -and $V -ge $r[2] -and $V -le $r[3]){return $false}
    };return $true
}
function Test-RoomDrop([string]$Kind,[double]$U,[double]$V,$HomeState) {
    if(-not (Test-RoomToyFloor $Kind $U $V)){return $false}
    $other=if($Kind -eq 'ball'){$HomeState.box}else{$HomeState.ball}
    return [math]::Sqrt([math]::Pow($U-$other.u,2)+[math]::Pow($V-$other.v,2)) -ge 0.14
}
function Test-RoomToyFloor([string]$Kind,[double]$U,[double]$V) {
    $radius=if($Kind -eq 'box'){.07}else{.025}
    foreach($du in @(-$radius,0,$radius)){foreach($dv in @(-$radius,0,$radius)){if(-not (Test-RoomFloor ($U+$du) ($V+$dv))){return $false}}}
    return $true
}
function Get-RoomPath($Start,$Goal) {
    if(-not (Test-RoomFloor $Goal.u $Goal.v)){return @()}
    # Fixed room obstacles on a small navigation grid. Four-neighbour moves cannot cut corners.
    $nodes=@{};for($i=2;$i -le 18;$i++){for($j=2;$j -le 18;$j++){if(Test-RoomFloor ($i/20.0) ($j/20.0)){$nodes["$i,$j"]=@{u=$i/20.0;v=$j/20.0;i=$i;j=$j}}}}
    $a=$null;$b=$null;$da=[double]::MaxValue;$db=$da
    foreach($key in $nodes.Keys){$n=$nodes[$key];$d=[math]::Pow($n.u-$Start.u,2)+[math]::Pow($n.v-$Start.v,2);if($d -lt $da -and (Test-RoomSegment $Start $n)){$da=$d;$a=$key};$d=[math]::Pow($n.u-$Goal.u,2)+[math]::Pow($n.v-$Goal.v,2);if($d -lt $db -and (Test-RoomSegment $n $Goal)){$db=$d;$b=$key}}
    if($null -eq $a -or $null -eq $b){return @()}
    $queue=[Collections.Generic.Queue[string]]::new();$queue.Enqueue($a);$previous=@{};$previous[$a]=''
    while($queue.Count){$key=$queue.Dequeue();if($key -eq $b){break};$n=$nodes[$key]
        foreach($d in @(@(1,0),@(-1,0),@(0,1),@(0,-1))){$next=[string]($n.i+$d[0])+','+[string]($n.j+$d[1]);if($nodes.ContainsKey($next) -and -not $previous.ContainsKey($next)){$previous[$next]=$key;$queue.Enqueue($next)}}
    }
    if(-not $previous.ContainsKey($b)){return @()}
    $result=[Collections.Generic.List[object]]::new();$key=$b
    while($key -ne ''){$result.Insert(0,@{u=$nodes[$key].u;v=$nodes[$key].v});$key=$previous[$key]}
    $result.Add(@{u=[double]$Goal.u;v=[double]$Goal.v});return $result.ToArray()
}
function Test-RoomSegment($A,$B) {
    $steps=[math]::Max(1,[math]::Ceiling(([math]::Abs($A.u-$B.u)+[math]::Abs($A.v-$B.v))*1000))
    for($k=0;$k -le $steps;$k++){if(-not (Test-RoomFloor ($A.u+($B.u-$A.u)*$k/$steps) ($A.v+($B.v-$A.v)*$k/$steps))){return $false}}
    return $true
}
function Read-HomeState($Data) {
    $result=New-HomeState;if($null -eq $Data){return $result}
    foreach($key in @('left','top')){if($Data.$key -is [ValueType] -and $Data.$key -isnot [bool] -and -not [double]::IsNaN($Data.$key) -and -not [double]::IsInfinity($Data.$key)){$result[$key]=[double]$Data.$key}}
    foreach($kind in @('ball','box')){$p=$Data.$kind
        if($p.u -is [ValueType] -and $p.v -is [ValueType] -and $p.u -isnot [bool] -and $p.v -isnot [bool] -and (Test-RoomToyFloor $kind ([double]$p.u) ([double]$p.v))){$result[$kind]=@{u=[double]$p.u;v=[double]$p.v}}
    }
    if(-not (Test-RoomDrop 'ball' $result.ball.u $result.ball.v $result)){$defaults=New-HomeState;$result.ball=$defaults.ball;$result.box=$defaults.box}
    return $result
}
