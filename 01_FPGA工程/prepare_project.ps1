$ErrorActionPreference = 'Stop'
$projectFile = Join-Path $PSScriptRoot 'td_project\camera_to_dsi_display.al'
$projectText = [IO.File]::ReadAllText($projectFile)
$projectDir = (Join-Path $PSScriptRoot 'td_project').Replace('\','/')
$projectText = [regex]::Replace($projectText, '(<Project\s[^>]*\bPath=")[^"]*(")', {
    param($match)
    $match.Groups[1].Value + $projectDir + $match.Groups[2].Value
})
[IO.File]::WriteAllText($projectFile, $projectText, [Text.UTF8Encoding]::new($false))
Write-Output $projectFile
