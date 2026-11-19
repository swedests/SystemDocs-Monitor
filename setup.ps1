#Requires -Version 5.1

<#
.SYNOPSIS
Устанавливает конфигурацию мониторинга, ярлыки и задания Windows.
.DESCRIPTION
Запрашивает персональные данные владельца, создаёт user_config.ahk,
регистрирует задания очистки и создаёт ярлыки без встроенного исполняемого AHK.
#>

[CmdletBinding()]
param(
    [string]$UserFullName,
    [string]$UserFullNameGen,
    [string]$UserFullNameDat,
    [string]$OwnerAbsenceMessage,
    [string]$ContactPhone,
    [string]$AhkPath,
    [string]$MarkViewPath,
    [switch]$WhatIf,
    [switch]$CheckDependencies,
    [switch]$TestAlert,
    [switch]$TestAllAlerts,
    [switch]$StartHWiNFO,
    [switch]$CheckCleaningNotice,
    [switch]$Backup,
    [switch]$CheckUpdates,
    [switch]$UpdateProject,
    [switch]$UpdatePrivacyNotice,
    [string]$Repository,
    [switch]$Diagnostics
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsPath = Join-Path $root "scripts"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator) -and -not $WhatIf -and -not $CheckDependencies -and -not $TestAlert -and -not $TestAllAlerts -and -not $StartHWiNFO -and -not $CheckCleaningNotice -and -not $Backup -and -not $CheckUpdates -and -not $UpdateProject -and -not $Diagnostics) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path)
    )

    foreach ($entry in @(
        @{ Name = "UserFullName"; Value = $UserFullName },
        @{ Name = "UserFullNameGen"; Value = $UserFullNameGen },
        @{ Name = "UserFullNameDat"; Value = $UserFullNameDat },
        @{ Name = "OwnerAbsenceMessage"; Value = $OwnerAbsenceMessage },
        @{ Name = "ContactPhone"; Value = $ContactPhone },
        @{ Name = "AhkPath"; Value = $AhkPath },
        @{ Name = "MarkViewPath"; Value = $MarkViewPath }
    )) {
        if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
            $arguments += "-$($entry.Name)"
            $arguments += ('"{0}"' -f $entry.Value.Replace('"', '\"'))
        }
    }

    if ($CheckDependencies) { $arguments += "-CheckDependencies" }
    if ($TestAlert) { $arguments += "-TestAlert" }
    if ($TestAllAlerts) { $arguments += "-TestAllAlerts" }
    if ($StartHWiNFO) { $arguments += "-StartHWiNFO" }
    if ($CheckCleaningNotice) { $arguments += "-CheckCleaningNotice" }
    if ($Backup) { $arguments += "-Backup" }
    if ($CheckUpdates) { $arguments += "-CheckUpdates" }
    if ($UpdateProject) { $arguments += "-UpdateProject" }
    if ($UpdatePrivacyNotice) { $arguments += "-UpdatePrivacyNotice" }
    if (-not [string]::IsNullOrWhiteSpace($Repository)) { $arguments += "-Repository"; $arguments += ('"{0}"' -f $Repository) }
    if ($Diagnostics) { $arguments += "-Diagnostics" }
    if ($WhatIf) { $arguments += "-WhatIf" }

    Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs -Wait
    exit
}

function Read-Value {
    param(
        [string]$Prompt,
        [string]$Default = "",
        [switch]$Required
    )

    if ([string]::IsNullOrWhiteSpace($Default)) {
        $value = Read-Host $Prompt
    } else {
        $value = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = $Default
        }
    }

    if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
        throw "Не заполнено обязательное поле: $Prompt"
    }
    return $value
}

function Get-ExistingConfigValue {
    param([string]$Name)

    $configPath = Join-Path $root "user_config.ahk"
    if (-not (Test-Path $configPath)) {
        return ""
    }

    $line = Get-Content -LiteralPath $configPath -Encoding UTF8 |
        Where-Object { $_ -match "^$Name\s*:=" } |
        Select-Object -First 1

    if ($line -match '^\w+\s*:=\s*"((?:[^"\\]|\\.)*)"') {
        return $Matches[1].Replace('\"', '"')
    }
    return ""
}

function Escape-AhkString {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '""')
}

if ($UpdatePrivacyNotice) {
    $ownerName = Get-ExistingConfigValue "UserFullName"
    $absenceMessage = Get-ExistingConfigValue "OwnerAbsenceMessage"
    if ([string]::IsNullOrWhiteSpace($ownerName)) {
        throw "Имя владельца не найдено в user_config.ahk."
    }
    if ([string]::IsNullOrWhiteSpace($absenceMessage)) {
        throw "Сообщение об отсутствии не найдено в user_config.ahk."
    }

    $policy = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    New-Item -Path $policy -Force | Out-Null
    Set-ItemProperty -Path $policy -Name "legalnoticecaption" -Value "ВНИМАНИЕ: ВЛАДЕЛЕЦ ПК — $ownerName" -Type String
    $today = Get-Date -Format "dd.MM.yyyy"
    $notice = "$absenceMessage. КОМПЬЮТЕР ПРИНАДЛЕЖИТ ВЛАДЕЛЬЦУ. " +
        "ЗАПРЕЩЕНО: ЗАПУСКАТЬ ТЯЖЁЛЫЕ ИГРЫ, ТЕСТЫ, ПРОГРАММЫ ДЛЯ РАЗГОНА, МЕНЯТЬ НАСТРОЙКИ BIOS. " +
        "ЕСЛИ КОМПЬЮТЕР ЗАВИС - УДЕРЖИВАТЬ КНОПКУ ПИТАНИЯ 5-7 СЕКУНД. " +
        "ЕСЛИ НЕТ КАРТИНКИ НА ЭКРАНЕ - ПРОВЕРИТЬ КАБЕЛЬ МОНИТОРА. " +
        "ЕСЛИ ПОЯВИТСЯ ОКНО С ИНСТРУКЦИЕЙ - ПРОЧИТАЙ И ДЕЙСТВУЙ ПО НЕЙ. " +
        "ЕСЛИ БУДЕТ СООБЩЕНИЕ ПРО ДИСК (SSD) - НЕ ЗАПУСКАЙ НИЧЕГО ТЯЖЁЛОГО И СОХРАНИ ВАЖНЫЕ ФАЙЛЫ. " +
        "ЧИСТКА ОТ ПЫЛИ - РАЗ В 2 МЕСЯЦА. ПОСЛЕДНЯЯ ЧИСТКА: $today. " +
        "ПОЛНАЯ ШПАРГАЛКА: docs\CheatSheet.md."
    Set-ItemProperty -Path $policy -Name "legalnoticetext" -Value $notice -Type String
    Write-Host "Системное уведомление обновлено: имя владельца указано только в заголовке."
    exit
}

function Find-Ahk {
    $candidates = @(
        (Join-Path ${env:ProgramFiles} "AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe"),
        (Join-Path ${env:ProgramFiles} "AutoHotkey\v1.1.36.02\AutoHotkeyU64.exe"),
        (Join-Path ${env:ProgramFiles} "AutoHotkey\AutoHotkeyU64.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    $found = Get-ChildItem -Path ${env:ProgramFiles} -Filter "AutoHotkeyU64.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\v1\\.' } |
        Select-Object -First 1

    if ($found) {
        return $found.FullName
    }
    return ""
}

function Find-MarkView {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "MarkView\markview.exe"),
        (Join-Path ${env:ProgramFiles} "MarkView\markview.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "MarkView\markview.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }
    return ""
}

function Find-HWiNFO {
    $candidates = @(
        (Join-Path ${env:ProgramFiles} "HWiNFO64\HWiNFO64.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "HWiNFO64\HWiNFO64.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }
    return ""
}

function Invoke-DependencyCheck {
    param([switch]$Quiet)

    $results = New-Object System.Collections.Generic.List[object]
    $checkedAhk = if ([string]::IsNullOrWhiteSpace($AhkPath)) { Find-Ahk } else { $AhkPath }
    $checkedMarkView = if ([string]::IsNullOrWhiteSpace($MarkViewPath)) { Find-MarkView } else { $MarkViewPath }
    $checkedHWiNFO = Find-HWiNFO
    $configPresent = Test-Path (Join-Path $root "user_config.ahk")

    $results.Add([PSCustomObject]@{ Name="AutoHotkey v1"; Found=(-not [string]::IsNullOrWhiteSpace($checkedAhk)); Path=$checkedAhk })
    $results.Add([PSCustomObject]@{ Name="MarkView"; Found=(-not [string]::IsNullOrWhiteSpace($checkedMarkView) -and (Test-Path $checkedMarkView)); Path=$checkedMarkView })
    $results.Add([PSCustomObject]@{ Name="HWiNFO64"; Found=(-not [string]::IsNullOrWhiteSpace($checkedHWiNFO)); Path=$checkedHWiNFO })
    $results.Add([PSCustomObject]@{ Name="user_config.ahk"; Found=$configPresent; Path=(Join-Path $root "user_config.ahk") })

    foreach ($result in $results) {
        if ($result.Found) {
            if (-not $Quiet) { Write-Host "[OK] $($result.Name): $($result.Path)" -ForegroundColor Green }
        } else {
            if (-not $Quiet) { Write-Host "[НЕТ] $($result.Name)" -ForegroundColor Red }
        }
    }

    return $results
}

if ($CheckDependencies) {
    Write-Host "Проверка зависимостей SystemDocs Monitor"
    $dependencyResults = Invoke-DependencyCheck
    if (($dependencyResults | Where-Object { -not $_.Found }).Count -gt 0) {
        exit 1
    }
    exit 0
}

if ($Diagnostics) {
    $diagnosticsScript = Join-Path $root "scripts\diagnostics.ps1"
    if (-not (Test-Path $diagnosticsScript)) {
        throw "Не найден файл диагностики: $diagnosticsScript"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $diagnosticsScript
    exit $LASTEXITCODE
}

if ($TestAlert) {
    $testAhk = if ([string]::IsNullOrWhiteSpace($AhkPath)) { Find-Ahk } else { $AhkPath }
    $testMarkView = if ([string]::IsNullOrWhiteSpace($MarkViewPath)) { Find-MarkView } else { $MarkViewPath }

    if ([string]::IsNullOrWhiteSpace($testAhk) -or -not (Test-Path $testAhk)) {
        Write-Error "AutoHotkey v1 не найден."
        exit 1
    }
    if ([string]::IsNullOrWhiteSpace($testMarkView) -or -not (Test-Path $testMarkView)) {
        Write-Error "MarkView не найден."
        exit 1
    }

    $testScript = Join-Path $root "scripts\alert.ahk"
    if (-not (Test-Path $testScript)) {
        Write-Error "Не найден скрипт тревоги: $testScript"
        exit 1
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $testAhk
    $startInfo.Arguments = ('"{0}" cpu' -f $testScript)
    $startInfo.WorkingDirectory = (Split-Path -Parent $testScript)
    $startInfo.UseShellExecute = $false
    [void][System.Diagnostics.Process]::Start($startInfo)
    Write-Host "Тестовая тревога CPU отправлена маршруту alert.ahk."
    Write-Host "Проверьте, что открылось окно ALERT_CPU.md."
    exit 0
}

if ($TestAllAlerts) {
    $testAhk = if ([string]::IsNullOrWhiteSpace($AhkPath)) { Find-Ahk } else { $AhkPath }
    $testMarkView = if ([string]::IsNullOrWhiteSpace($MarkViewPath)) { Find-MarkView } else { $MarkViewPath }
    $testScript = Join-Path $root "scripts\alert.ahk"

    if ([string]::IsNullOrWhiteSpace($testAhk) -or -not (Test-Path $testAhk)) {
        Write-Error "AutoHotkey v1 не найден."
        exit 1
    }
    if ([string]::IsNullOrWhiteSpace($testMarkView) -or -not (Test-Path $testMarkView)) {
        Write-Error "MarkView не найден."
        exit 1
    }
    if (-not (Test-Path $testScript)) {
        Write-Error "Не найден скрипт тревоги: $testScript"
        exit 1
    }

    $alertText = Get-Content -LiteralPath $testScript -Encoding UTF8 -Raw
    $pairs = [regex]::Matches($alertText, '"([^"]+)"\s*:\s*"(ALERT_[^"]+)"')
    $alertTypes = New-Object System.Collections.Generic.List[string]
    foreach ($pair in $pairs) {
        $alertType = $pair.Groups[1].Value
        if ($alertTypes -notcontains $alertType) {
            $alertTypes.Add($alertType)
        }
    }

    Write-Host "Будут последовательно проверены уникальные типы тревог: $($alertTypes.Count)"
    foreach ($alertType in $alertTypes) {
        Write-Host "Проверка: $alertType"
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $testAhk
        $startInfo.Arguments = ('"{0}" {1}' -f $testScript, $alertType)
        $startInfo.WorkingDirectory = (Split-Path -Parent $testScript)
        $startInfo.UseShellExecute = $false
        [void][System.Diagnostics.Process]::Start($startInfo)
        Start-Sleep -Seconds 3
    }

    Write-Host ""
    Write-Host "Проверка завершена."
    Write-Host "Закройте открытые окна памяти, если их осталось несколько."
    exit 0
}

if ($StartHWiNFO) {
    $hwiNfoPath = Find-HWiNFO
    if ([string]::IsNullOrWhiteSpace($hwiNfoPath)) {
        Write-Error "HWiNFO64.exe не найден."
        exit 1
    }
    $running = Get-Process -Name "HWiNFO64" -ErrorAction SilentlyContinue
    if ($running) {
        Write-Host "HWiNFO64 уже запущен."
        exit 0
    }
    Start-Process -FilePath $hwiNfoPath
    Write-Host "HWiNFO64 запущен."
    exit 0
}

if ($CheckCleaningNotice) {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    try {
        $caption = (Get-ItemProperty -LiteralPath $registryPath -Name "legalnoticecaption" -ErrorAction Stop).legalnoticecaption
        $text = (Get-ItemProperty -LiteralPath $registryPath -Name "legalnoticetext" -ErrorAction Stop).legalnoticetext
    } catch {
        Write-Error "Системное уведомление не найдено в реестре."
        exit 1
    }

    $cleanDate = ""
    $cleanFile = Join-Path $root "data\last_cleaning.txt"
    if (Test-Path $cleanFile) {
        $stamp = (Get-Content -LiteralPath $cleanFile -Encoding UTF8 -Raw).Trim()
        if ($stamp.Length -ge 14 -and $stamp.Substring(0,14) -match '^\d{14}$') {
            $cleanDate = "$($stamp.Substring(6,2)).$($stamp.Substring(4,2)).$($stamp.Substring(0,4))"
        }
    }

    $captionOk = -not [string]::IsNullOrWhiteSpace($caption)
    $textOk = -not [string]::IsNullOrWhiteSpace($text)
    $dateOk = [string]::IsNullOrWhiteSpace($cleanDate) -or $text.Contains($cleanDate)

    if ($captionOk -and $textOk -and $dateOk) {
        Write-Host "[OK] Заголовок и текст системного уведомления настроены."
        if ($cleanDate) { Write-Host "[OK] Дата чистки в сообщении совпадает: $cleanDate" }
        exit 0
    }

    Write-Host "[НЕТ] Системное уведомление не совпадает с текущей чисткой."
    exit 1
}

if ($Backup) {
    $backupDir = Join-Path $env:USERPROFILE "SystemDocs-Backups"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $backupDir "SystemDocs-$stamp.zip"
    $items = New-Object System.Collections.Generic.List[string]

    $configPath = Join-Path $root "user_config.ahk"
    if (Test-Path $configPath) { $items.Add($configPath) }

    $dataPath = Join-Path $root "data"
    if (Test-Path $dataPath) { $items.Add($dataPath) }

    if ($items.Count -eq 0) {
        Write-Error "Нет данных для резервной копии."
        exit 1
    }

    $temporaryDir = Join-Path $env:TEMP "SystemDocs-Backup-$stamp"
    New-Item -ItemType Directory -Path $temporaryDir -Force | Out-Null
    if (Test-Path $configPath) {
        Copy-Item -LiteralPath $configPath -Destination (Join-Path $temporaryDir "user_config.ahk")
    }
    if (Test-Path $dataPath) {
        Copy-Item -LiteralPath $dataPath -Destination (Join-Path $temporaryDir "data") -Recurse
    }

    if (Test-Path $backupPath) { Remove-Item -LiteralPath $backupPath -Force }
    Compress-Archive -Path (Join-Path $temporaryDir "*") -DestinationPath $backupPath -Force
    Remove-Item -LiteralPath $temporaryDir -Recurse -Force

    Write-Host "Резервная копия создана:"
    Write-Host $backupPath
    exit 0
}

if ($CheckUpdates -or $UpdateProject) {
    if ([string]::IsNullOrWhiteSpace($Repository)) {
        Write-Error "Для проверки обновлений укажите -Repository с URL репозитория."
        exit 1
    }

    $git = Get-Command "git.exe" -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Error "Git не найден в PATH."
        exit 1
    }

    $isRepo = Test-Path (Join-Path $root ".git")
    if (-not $isRepo) {
        Write-Host "Проект сейчас не является Git-репозиторием."
        Write-Host "Скачивание обновления начнётся только после явного подтверждения пользователя."
        if (-not $UpdateProject) { exit 0 }
        $confirm = Read-Host "Скачать и установить обновление в новую папку рядом с проектом? (да/нет)"
        if ($confirm -notin @("да", "yes", "y")) { exit 0 }

        $parent = Split-Path -Parent $root
        $updateDir = Join-Path $parent ("SystemDocs-update-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        & $git.Source clone --depth 1 $Repository $updateDir
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-Host "Обновление скачано в: $updateDir"
        Write-Host "После проверки скопируйте системные файлы поверх проекта и сохраните user_config.ahk/data."
        exit 0
    }

    & $git.Source -C $root fetch origin
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $branch = (& $git.Source -C $root branch --show-current).Trim()
    $behind = [int](& $git.Source -C $root rev-list --count ("HEAD..origin/" + $branch))
    if ($behind -gt 0) {
        Write-Host "Доступно обновлений: $behind"
        if ($UpdateProject) {
            & $git.Source -C $root pull --ff-only origin $branch
            exit $LASTEXITCODE
        }
        exit 2
    }

    Write-Host "Обновлений нет."
    exit 0
}

if ($WhatIf) {
    $dryAhk = if ([string]::IsNullOrWhiteSpace($AhkPath)) { Find-Ahk } else { $AhkPath }
    $dryMarkView = if ([string]::IsNullOrWhiteSpace($MarkViewPath)) { Find-MarkView } else { $MarkViewPath }
    $dryHWiNFO = Find-HWiNFO

    Write-Host "Режим проверки установщика. Изменения не будут внесены."
    $dryAhkText = if ($dryAhk) { $dryAhk } else { "НЕ НАЙДЕН" }
    $dryMarkViewText = if ($dryMarkView) { $dryMarkView } else { "НЕ НАЙДЕН" }
    $dryHWiNFOText = if ($dryHWiNFO) { $dryHWiNFO } else { "НЕ НАЙДЕН АВТОМАТИЧЕСКИ" }
    Write-Host "AutoHotkey: $dryAhkText"
    Write-Host "MarkView: $dryMarkViewText"
    Write-Host "HWiNFO: $dryHWiNFOText"
    Write-Host "Будут созданы: user_config.ahk, ярлык в автозагрузке, ярлык на рабочем столе, два задания планировщика."
    exit
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Установщик SystemDocs Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrWhiteSpace($UserFullName)) {
    $UserFullName = Read-Value "Имя владельца в именительном падеже" (Get-ExistingConfigValue "UserFullName") -Required
}
if ([string]::IsNullOrWhiteSpace($UserFullNameGen)) {
    $UserFullNameGen = Read-Value "Имя владельца в родительном падеже" (Get-ExistingConfigValue "UserFullNameGen") -Required
}
if ([string]::IsNullOrWhiteSpace($UserFullNameDat)) {
    $UserFullNameDat = Read-Value "Имя владельца в дательном падеже" (Get-ExistingConfigValue "UserFullNameDat") -Required
}
if ([string]::IsNullOrWhiteSpace($OwnerAbsenceMessage)) {
    $defaultAbsence = Get-ExistingConfigValue "OwnerAbsenceMessage"
    if ([string]::IsNullOrWhiteSpace($defaultAbsence)) {
        $defaultAbsence = "ВЛАДЕЛЕЦ ПК УЕХАЛ В АРМИЮ"
    }
    $OwnerAbsenceMessage = Read-Value "Сообщение об отсутствии владельца" $defaultAbsence -Required
}
if ([string]::IsNullOrWhiteSpace($ContactPhone)) {
    $ContactPhone = Read-Value "Контактный телефон" (Get-ExistingConfigValue "ContactPhone") -Required
}

if ([string]::IsNullOrWhiteSpace($AhkPath)) {
    $AhkPath = Find-Ahk
    if ([string]::IsNullOrWhiteSpace($AhkPath)) {
        throw "AutoHotkey v1 не найден. Установите AHK v1.1 с официального сайта."
    }
    Write-Host "AutoHotkey: $AhkPath"
} elseif (-not (Test-Path $AhkPath)) {
    throw "Указанный файл AutoHotkey не найден: $AhkPath"
}

if ([string]::IsNullOrWhiteSpace($MarkViewPath)) {
    $MarkViewPath = Find-MarkView
}
if ([string]::IsNullOrWhiteSpace($MarkViewPath)) {
    $MarkViewPath = Read-Value "Полный путь к MarkView"
}
if (-not (Test-Path $MarkViewPath)) {
    throw "MarkView не найден: $MarkViewPath"
}
Write-Host "MarkView: $MarkViewPath"

$hwiNfoPath = Find-HWiNFO
if ([string]::IsNullOrWhiteSpace($hwiNfoPath)) {
    Write-Warning "HWiNFO64.exe не найден автоматически. Установите HWiNFO или проверьте ручную настройку тревог."
} else {
    Write-Host "HWiNFO: $hwiNfoPath"
}

$configPath = Join-Path $root "user_config.ahk"
$configText = @(
    "#Requires AutoHotkey v1.1.33+"
    "; Файл создан установщиком setup.ps1."
    "; Не публикуйте этот файл: он содержит личные данные."
    ""
    'UserFullName := "' + (Escape-AhkString $UserFullName) + '"'
    'UserFullNameGen := "' + (Escape-AhkString $UserFullNameGen) + '"'
    'UserFullNameDat := "' + (Escape-AhkString $UserFullNameDat) + '"'
    'OwnerAbsenceMessage := "' + (Escape-AhkString $OwnerAbsenceMessage) + '"'
    'ContactPhone := "' + (Escape-AhkString $ContactPhone) + '"'
    ""
    'ViewerPath := "' + (Escape-AhkString $MarkViewPath) + '"'
) -join "`r`n"

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($configPath, $configText + "`r`n", $utf8Bom)
Write-Host "Создана конфигурация: $configPath"

$startupFolder = [Environment]::GetFolderPath("Startup")
$startupLink = Join-Path $startupFolder "SystemDocs Monitor.lnk"
$desktopFolder = [Environment]::GetFolderPath("Desktop")
$cleanLink = Join-Path $desktopFolder "Я почистил ПК.lnk"
$testAlertsLink = Join-Path $desktopFolder "Проверить все тревоги.lnk"

$shell = New-Object -ComObject WScript.Shell

$shortcut = $shell.CreateShortcut($startupLink)
$shortcut.TargetPath = $AhkPath
$shortcut.Arguments = ('"{0}"' -f (Join-Path $scriptsPath "show_and_close.ahk"))
$shortcut.WorkingDirectory = $scriptsPath
$shortcut.Description = "Показывает памятку SystemDocs при входе в Windows"
$shortcut.Save()
Write-Host "Создан ярлык автозапуска: $startupLink"

$cleanShortcut = $shell.CreateShortcut($cleanLink)
$cleanShortcut.TargetPath = "cmd.exe"
$cleanShortcut.Arguments = '/d /c schtasks /run /tn "Clean_Mark_Task"'
$cleanShortcut.WorkingDirectory = $root
$cleanShortcut.Description = "Отмечает выполненную чистку корпуса ПК"
$cleanShortcut.Save()
Write-Host "Создан ярлык на рабочем столе: $cleanLink"

$testShortcut = $shell.CreateShortcut($testAlertsLink)
$testShortcut.TargetPath = "powershell.exe"
$testShortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $root "setup.ps1") + '" -TestAllAlerts'
$testShortcut.WorkingDirectory = $root
$testShortcut.Description = "Последовательно открывает все тестовые памятки тревог"
$testShortcut.Save()
Write-Host "Создан ярлык теста всех тревог: $testAlertsLink"

$reminderAction = New-ScheduledTaskAction -Execute $AhkPath `
    -Argument ('"{0}"' -f (Join-Path $scriptsPath "cleaning_reminder.ahk")) `
    -WorkingDirectory $scriptsPath
$reminderTrigger = New-ScheduledTaskTrigger -Daily -At "12:00"
$reminderPrincipal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName "Clean_Dust_Reminder" `
    -Action $reminderAction `
    -Trigger $reminderTrigger `
    -Principal $reminderPrincipal `
    -Description "Ежедневно проверяет дату чистки корпуса ПК" `
    -Force | Out-Null
Write-Host "Создано задание: Clean_Dust_Reminder"

$markAction = New-ScheduledTaskAction -Execute $AhkPath `
    -Argument ('"{0}"' -f (Join-Path $scriptsPath "mark_cleaned.ahk")) `
    -WorkingDirectory $scriptsPath
$markPrincipal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName "Clean_Mark_Task" `
    -Action $markAction `
    -Principal $markPrincipal `
    -Description "Отмечает чистку корпуса и обновляет сообщение Windows" `
    -Force | Out-Null
Write-Host "Создано задание: Clean_Mark_Task"

Write-Host ""
Write-Host "Установка завершена." -ForegroundColor Green
Write-Host "Осталось вручную настроить пороги HWiNFO64 в соответствии со шпаргалкой."
