param([string]$TDHome='E:\Anlogic\TD_6.2.1_Engineer_6.2.168.116')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'prepare_project.ps1')
$tool=Join-Path $TDHome 'bin\td_commands_prompt.exe'
$subst=Join-Path $env:SystemRoot 'System32\subst.exe'
$driveLetter='R'
foreach($candidate in @('R','S','T','U','V','W','X','Y','Z')){
    if(-not (Get-PSDrive -Name $candidate -ErrorAction SilentlyContinue)){$driveLetter=$candidate;break}
}
$drive="${driveLetter}:"
$log=Join-Path $PSScriptRoot 'reports\v42_build_console.log'
$oldSynthesisOnly=$env:V42_SYNTH_ONLY
$env:V42_SYNTH_ONLY='0'
$started=Get-Date
$mapped=$false
try {
    & $subst $drive $PSScriptRoot
    if($LASTEXITCODE -ne 0){throw "Could not map temporary project drive $drive"}
    $mapped=$true
    $scriptFile="$drive/td_project/build_v42.tcl"
    & $tool $scriptFile *> $log
    if($LASTEXITCODE -ne 0){throw "TD failed; see $log"}
    $text=[IO.File]::ReadAllText($log)
    if($text -notmatch 'V42 BUILD SUCCESS'){throw "Build success marker absent; see $log"}
    $bit=Get-Item -LiteralPath (Join-Path $PSScriptRoot 'td_project\v42_dynamic_label.bit')
    if($bit.Length -eq 0 -or $bit.LastWriteTime -lt $started.AddSeconds(-2)){throw 'Stale or empty bitstream'}
    Copy-Item -LiteralPath $bit.FullName -Destination (Join-Path $PSScriptRoot 'release\v42_dynamic_label_PH1P35MDG324.bit') -Force
    Get-FileHash -LiteralPath $bit.FullName -Algorithm SHA256
    Get-Content -LiteralPath (Join-Path $PSScriptRoot 'td_project\v42_phy.ts')
} finally {
    if($mapped){& $subst $drive /d}
    $env:V42_SYNTH_ONLY=$oldSynthesisOnly
}
