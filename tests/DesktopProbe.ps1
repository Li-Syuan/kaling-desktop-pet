param([Parameter(Mandatory=$true)][string]$Directory,[int]$X,[int]$Y)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$form=[System.Windows.Forms.Form]::new();$form.Text='Kaling isolated click test';$form.FormBorderStyle='None';$form.StartPosition='Manual';$form.AutoScaleMode='None'
$form.Location=[System.Drawing.Point]::new($X,$Y);$form.Size=[System.Drawing.Size]::new(200,200);$form.BackColor=[System.Drawing.Color]::Lavender;$form.ShowInTaskbar=$false
$form.Add_Shown({[IO.File]::WriteAllText((Join-Path $Directory 'probe-handle.txt'),[string]$form.Handle.ToInt64())})
$form.Add_MouseDown({[IO.File]::WriteAllText((Join-Path $Directory 'probe-click.txt'),'received')})
$timeout=[System.Windows.Forms.Timer]::new();$timeout.Interval=20000;$timeout.Add_Tick({$form.Close()});$timeout.Start()
[System.Windows.Forms.Application]::Run($form)
$timeout.Dispose();$form.Dispose()
