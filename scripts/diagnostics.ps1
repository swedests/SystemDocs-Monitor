#Requires -Version 5.1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $root "docs\diagnostics"
$reportPath = Join-Path $reportDir "report.txt"

New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("SYSTEMDOCS MONITOR - ОТЧЁТ ДИАГНОСТИКИ")
$lines.Add("Дата проверки: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')")
$lines.Add("")

function Add-Line {
    param([bool]$Ok, [string]$Name, [string]$Details = "")
    $mark = if ($Ok) { "[OK]" } else { "[НЕТ]" }
    $text = "$mark $Name"
    if (-not [string]::IsNullOrWhiteSpace($Details)) {
        $text += ": $Details"
    }
    $script:lines.Add($text)
}

$ahkCandidates = @(
    (Join-Path ${env:ProgramFiles} "AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe"),
    (Join-Path ${env:ProgramFiles} "AutoHotkey\AutoHotkeyU64.exe")
)
$ahkPath = $ahkCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$ahkDetails = if ($ahkPath) { "установлен в стандартном расположении" } else { "" }
Add-Line (-not [string]::IsNullOrWhiteSpace($ahkPath)) "AutoHotkey v1" $ahkDetails

$configPath = Join-Path $root "user_config.ahk"
$configExists = Test-Path $configPath
Add-Line $configExists "Конфигурация user_config.ahk"

$configFieldsPresent = $false
if ($configExists) {
    $configText = Get-Content -LiteralPath $configPath -Encoding UTF8 -Raw
    $requiredFields = @("UserFullName", "UserFullNameGen", "UserFullNameDat", "OwnerAbsenceMessage", "ContactPhone", "ViewerPath")
    $missingFields = @($requiredFields | Where-Object { $configText -notmatch [regex]::Escape($_) })
    $configFieldsPresent = $missingFields.Count -eq 0
    $fieldDetails = if (-not $configFieldsPresent) { "Найдены пропущенные поля" } else { "" }
    Add-Line $configFieldsPresent "Обязательные поля конфигурации" $fieldDetails
}

$markViewCandidates = @(
    (Join-Path $env:LOCALAPPDATA "MarkView\markview.exe"),
    (Join-Path ${env:ProgramFiles} "MarkView\markview.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "MarkView\markview.exe")
)
$markViewPath = $markViewCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$markViewDetails = if ($markViewPath) { "установлен в стандартном расположении" } else { "" }
Add-Line (-not [string]::IsNullOrWhiteSpace($markViewPath)) "MarkView" $markViewDetails

$hwiNfoCandidates = @(
    (Join-Path ${env:ProgramFiles} "HWiNFO64\HWiNFO64.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "HWiNFO64\HWiNFO64.exe")
)
$hwiNfoPath = $hwiNfoCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$hwiNfoRunning = $null -ne (Get-Process -Name "HWiNFO64" -ErrorAction SilentlyContinue)
$hwiNfoDetails = if ($hwiNfoPath) { "установлен в стандартном расположении" } else { "" }
Add-Line (-not [string]::IsNullOrWhiteSpace($hwiNfoPath)) "Установка HWiNFO64" $hwiNfoDetails
Add-Line $hwiNfoRunning "HWiNFO64 запущен"

$lines.Add("")
$lines.Add("ЗАДАНИЯ ПЛАНИРОВЩИКА")
foreach ($taskName in @("Clean_Dust_Reminder", "Clean_Mark_Task")) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $actionText = "Ready"
        Add-Line ($task.State -eq "Ready") $taskName "$($task.State); $actionText"
    } catch {
        Add-Line $false $taskName "Задание не найдено"
    }
}

$lines.Add("")
$lines.Add("ФАЙЛЫ АВТОМАТИЗАЦИИ")
$ahkFiles = Get-ChildItem -LiteralPath (Join-Path $root "scripts") -Filter "*.ahk" -File
$badEncoding = @()
foreach ($ahkFile in $ahkFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($ahkFile.FullName)
    $bomOk = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
    if (-not $bomOk) {
        $badEncoding += $ahkFile.Name
    }
}
$encodingDetails = if ($badEncoding.Count) { "Проверить: $($badEncoding -join ', ')" } else { "$($ahkFiles.Count) файлов" }
Add-Line ($badEncoding.Count -eq 0) "UTF-8 с BOM для AHK" $encodingDetails

$alertScript = Join-Path $root "scripts\alert.ahk"
$alertText = if (Test-Path $alertScript) { Get-Content -LiteralPath $alertScript -Encoding UTF8 -Raw } else { "" }
$missingAlertFiles = @()
$pairs = @()
if ($alertText) {
    $pairs = [regex]::Matches($alertText, '"([^"]+)"\s*:\s*"(ALERT_[^"]+)"')
    foreach ($pair in $pairs) {
        $alertFile = Join-Path $root "config\alerts\$($pair.Groups[2].Value).md"
        if (-not (Test-Path $alertFile)) {
            $missingAlertFiles += "$($pair.Groups[1].Value) -> $($pair.Groups[2].Value).md"
        }
    }
}
$routeDetails = if ($missingAlertFiles.Count) { "Не найдены: $($missingAlertFiles -join ', ')" } else { "$($pairs.Count) записей проверено" }
Add-Line ($missingAlertFiles.Count -eq 0 -and $pairs.Count -gt 0) "Маршруты памяток тревог" $routeDetails

$lines.Add("")
$lines.Add("ИТОГО")
$failCount = ([regex]::Matches(($lines -join "`r`n"), "\[НЕТ\]")).Count
if ($failCount -eq 0) {
    $lines.Add("Критических ошибок не найдено.")
} else {
    $lines.Add("Найдено ошибок: $failCount.")
}

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($reportPath, (($lines -join "`r`n") + "`r`n"), $utf8Bom)

Write-Host ""
foreach ($line in $lines) {
    Write-Host $line
}
Write-Host ""
Write-Host "Отчёт сохранён: $reportPath"

Start-Process -FilePath "notepad.exe" -ArgumentList ('"{0}"' -f $reportPath)
