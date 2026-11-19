#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
; ВЕРСИЯ: 1.5 / Дата сборки: 20.11.2026

#Include %A_ScriptDir%\..\user_config.ahk

SetWorkingDir %A_ScriptDir%
FileEncoding, UTF-8-RAW

BaseDir := A_ScriptDir . "\.."
DataPath := BaseDir . "\data"
AlertPath := BaseDir . "\config\alerts"

AlertType = %1%

; Ключи соответствуют аргументам HWiNFO; старый аргумент "power" оставлен для совместимости.
Map := {"cpu":"ALERT_CPU", "gpu":"ALERT_GPU", "vcore":"ALERT_VCORE"
  , "ram":"ALERT_RAM", "vrm":"ALERT_VRM", "ssd":"ALERT_SSD"
  , "fan":"ALERT_FAN", "v12":"ALERT_12V", "aux":"ALERT_AUX"
  , "pch":"ALERT_PCH", "vbat":"ALERT_VBAT", "pkg":"ALERT_GPU_PKG"
  , "hotspot":"ALERT_GPU_HOTSPOT", "power":"ALERT_GPU_POWER"
  , "gpu_power":"ALERT_GPU_POWER"
  , "wear":"ALERT_SSD_WEAR"}

  Name := Map[AlertType]
  if (Name = "")
  {
    ; Неизвестный аргумент не должен открывать случайную памятку.
    FileAppend, %A_Now% WARN: unknown alert type "%AlertType%"`n, *%DataPath%\errors.log
  ExitApp
}

File := AlertPath . "\" . Name . ".md"
IfNotExist, %File%
{
  ; Не запускаем MarkView с путём к отсутствующему файлу инструкции.
  FileAppend, %A_Now% WARN: alert file missing: %File%`n, *%DataPath%\errors.log
  ExitApp
}

FileAppend, %A_DD%.%A_MM%.%A_YYYY% %A_Hour%:%A_Min% - сработало предупреждение: %AlertType%`n, *%DataPath%\alerts.log

Run, "%ViewerPath%" "%File%"
; Даём MarkView время открыть инструкцию после запуска команды.
WinWait, ahk_exe markview.exe,, 10
if (ErrorLevel)
{
  FileAppend, %A_Now% ERROR: markview window not found (%AlertType%)`n, *%DataPath%\errors.log
  ExitApp
}

Target := ""
WinGet, wList, List, ahk_exe markview.exe
; MarkView может иметь несколько окон; выбираем первое с непустым заголовком.
Loop, %wList%
{
  id := wList%A_Index%
  WinGetTitle, t, ahk_id %id%
  if (t = "")
    continue
  Target := id
  break
}
if (Target = "")
{
  FileAppend, %A_Now% ERROR: no visible markview window`n, *%DataPath%\errors.log
  ExitApp
}

WinActivate, ahk_id %Target%
WinMaximize, ahk_id %Target%
Sleep, 500

; Рабочая область монитора: экран минус панель задач
SysGet, WA, MonitorWorkArea

; У полноэкранного окна рамку не трогаем; флаг нужен, чтобы вернуть стиль после нашего изменения.
FrameRemoved := 0
WinGetPos, wx, wy, ww, wh, ahk_id %Target%
if (ww < A_ScreenWidth or wh < (WA.Bottom - WA.Top))
{
  WinSet, Style, -0xC40000, ahk_id %Target%
  FrameRemoved := 1
  WinMove, ahk_id %Target%,, 0, 0, A_ScreenWidth, A_ScreenHeight
}

WinSet, AlwaysOnTop, On, ahk_id %Target%

; Таймер возвращает окно наверх, если другое приложение сбросит этот режим.
TopTarget := Target
SetTimer, ReassertTop, 2000

; Esc закрывает окно ТОЛЬКО когда MarkView активен
Hotkey, IfWinActive, ahk_id %TopTarget%
  Hotkey, Esc, CloseMarkView
Hotkey, IfWinActive

; Ждём либо закрытие окна, либо 5 минут
Loop, 150
{
  Sleep, 2000
  IfWinNotExist, ahk_id %TopTarget%
  {
    SetTimer, ReassertTop, Off
  ExitApp
}
}

; 5 минут прошли: снимаем «поверх всех» и возвращаем рамку с крестиком
SetTimer, ReassertTop, Off
WinSet, AlwaysOnTop, Off, ahk_id %TopTarget%
if (FrameRemoved)
  WinSet, Style, +0xC40000, ahk_id %TopTarget%
ExitApp

CloseMarkView:
  IfWinExist, ahk_id %TopTarget%
  {
    WinSet, AlwaysOnTop, Off, ahk_id %TopTarget%
    if (FrameRemoved)
      WinSet, Style, +0xC40000, ahk_id %TopTarget%
    Sleep, 200
    WinClose, ahk_id %TopTarget%
  }
  SetTimer, ReassertTop, Off
ExitApp
Return

ReassertTop:
  IfWinExist, ahk_id %TopTarget%
    WinSet, AlwaysOnTop, On, ahk_id %TopTarget%
  Else
  {
    SetTimer, ReassertTop, Off
    ExitApp
  }
Return
