#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
SetTitleMatchMode, 2

#Include %A_ScriptDir%\..\user_config.ahk

SetWorkingDir %A_ScriptDir%
FileEncoding, UTF-8-RAW

DataPath := A_ScriptDir . "\..\data"

File := A_ScriptDir . "\..\docs\README.md"

; --- 1. Запоминаем окна до запуска ---
; Разделитель вокруг каждого ID не даёт принять часть одного ID за другой.
Pre := ""
WinGet, idList, List
Loop, %idList%
    Pre .= idList%A_Index% . "|"

; --- 2. Запускаем просмотрщик ---
Run, "%ViewerPath%" "%File%"

; --- 3. Ищем новое окно с заголовком (до 10 сек) ---
; Окно определяется по ID, чтобы не спутать его с уже открытым окном MarkView.
Target := ""
Loop, 50
{
    Sleep, 200
    WinGet, newList, List
    Loop, %newList%
    {
        id := newList%A_Index%
        if (InStr(Pre, "|" . id . "|"))
            continue
        WinGetTitle, wTitle, ahk_id %id%
        if (wTitle = "")
            continue
        Target := id
        break
    }
    if (Target != "")
        break
}

if (Target = "")
{
    FileAppend, %A_Now% ERROR: no new window appeared in 10s`n, %DataPath%\errors.log
    ExitApp
}

; --- 4. Разворачиваем и держим поверх всех ---
WinActivate, ahk_id %Target%
WinMaximize, ahk_id %Target%
WinSet, AlwaysOnTop, On, ahk_id %Target%

; --- 5. Повторно включаем режим «поверх всех» каждые 3 секунды ---
; MarkView или другое приложение может сбросить AlwaysOnTop, поэтому режим выставляется повторно.
TopTarget := Target
SetTimer, ReassertTop, 3000

; --- 6. Через 2 минуты снимаем «поверх всех» и останавливаем таймер ---
Sleep, 120000
SetTimer, ReassertTop, Off
WinSet, AlwaysOnTop, Off, ahk_id %TopTarget%
ExitApp

ReassertTop:
    IfWinExist, ahk_id %TopTarget%
        WinSet, AlwaysOnTop, On, ahk_id %TopTarget%
    Else
        SetTimer, ReassertTop, Off ; Если окно закрыли вручную, таймер больше не нужен
Return
