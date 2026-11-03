param([string]$ModelSimBin='E:\modelsim\win64')
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
if(-not (Test-Path 'work')) { & "$ModelSimBin\vlib.exe" work; if($LASTEXITCODE -ne 0){throw 'vlib failed'} }
$sources=@(Get-ChildItem rtl -Filter *.v | ForEach-Object FullName)+@(Get-ChildItem testbenches -Filter *.sv | ForEach-Object FullName)
& "$ModelSimBin\vlog.exe" -sv -work work @sources *> compile.log
if($LASTEXITCODE -ne 0){throw 'Compile failed; see compile.log'}
foreach($name in @('tb_v42_dynamic_controller','tb_v43_barcode_pixels','tb_uart_telemetry','tb_v43_barcode')) {
    & "$ModelSimBin\vsim.exe" -c '-voptargs=+acc' -wlf "$name.wlf" -do "do ${name}_capture.do" "work.$name" *> "$name.log"
    if($LASTEXITCODE -ne 0 -or (Get-Content -Raw "$name.log") -notmatch 'PASS'){throw "Simulation failed: $name"}
    Write-Output "PASS $name"
}
