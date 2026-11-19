#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
; ВЕРСИЯ: 1.1 / Дата сборки: 19.11.2026

SetWorkingDir %A_ScriptDir%
FileEncoding, UTF-8-RAW

; --- Пути относительно расположения скрипта ---
BaseDir := A_ScriptDir . "\.."
DataPath := BaseDir . "\data"
DateFile := DataPath . "\last_cleaning.txt"

; --- Отмечаем каждый запуск скрипта ---
FileAppend, %A_Now% reminder`n, %DataPath%\heartbeat.txt

; --- Дата чистки — это состояние, а не журнал; если файла нет, напоминаем сразу ---
IfNotExist, %DateFile%
{
  FileAppend, 20260101000000, %DateFile%
  FileAppend, %A_Now% WARN: last_cleaning.txt missing, recreated`n, %DataPath%\errors.log
}

FileRead, LastStamp, %DateFile%

; Метка A_Now должна иметь формат YYYYMMDDHH24MISS (14 цифр); иначе состояние сбрасывается.
if (StrLen(LastStamp) != 14 or not RegExMatch(LastStamp, "^\d+$"))
{
  FileAppend, %A_Now% WARN: invalid stamp "%LastStamp%", reset`n, %DataPath%\errors.log
  FileDelete, %DateFile%
  FileAppend, 20260101000000, %DateFile%
  LastStamp := "20260101000000"
}

; EnvSub вычитает дату последней чистки из текущей даты и оставляет число дней в Diff.
Diff := A_Now
EnvSub, Diff, LastStamp, Days

; --- Человекочитаемая дата последней чистки (пункт 10) ---
FormatTime, NiceDate, %LastStamp%, dd.MM.yyyy

; Проверяем от самого строгого порога к мягкому, чтобы показать только одно сообщение.
if (Diff >= 75)
{
  MsgBox, 16, СРОЧНО, Прошло %Diff% дней с последней чистки корпуса (крайний срок был 75).`n`nПожалуйста, продуй корпус от пыли СЕГОДНЯ.`nПоследняя чистка: %NiceDate%.`n`nПосле чистки запусти ярлык «Я почистил ПК» на рабочем столе.
  FileAppend, %A_Now% ALERT: %Diff% days since cleaning (critical)`n, %DataPath%\alerts.log
}
else if (Diff >= 60)
{
  MsgBox, 48, Внимание, Прошло %Diff% дней с последней чистки корпуса.`nПожалуйста, продуй корпус от пыли.`nПоследняя чистка: %NiceDate%.`n`nПосле чистки запусти ярлык «Я почистил ПК» на рабочем столе.
  FileAppend, %A_Now% ALERT: %Diff% days since cleaning (warning)`n, %DataPath%\alerts.log
}
else if (Diff >= 45)
{
  MsgBox, 64, Напоминание, Прошло уже %Diff% дней с последней чистки корпуса.`nВ ближайшие дни стоит продуть корпус от пыли.`nПоследняя чистка: %NiceDate%.`n`nПосле чистки запусти ярлык «Я почистил ПК» на рабочем столе.
  FileAppend, %A_Now% INFO: %Diff% days since cleaning (soft)`n, %DataPath%\alerts.log
}

; Статус определяется прошедшими днями; отдельная проверка ниже повышает WARN до CRIT.
Status := "OK"
if (Diff >= 45)
  Status := "WARN"
if (Diff >= 75)
  Status := "CRIT"

FileDelete, %DataPath%\status.txt
FileAppend, Status: %Status%`nLast cleaning: %NiceDate%`nDays since: %Diff%`nHeartbeat: %A_Now%`n, %DataPath%\status.txt

ExitApp
