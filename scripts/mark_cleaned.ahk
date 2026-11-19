#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
; ВЕРСИЯ: 1.1 / Дата сборки: 19.11.2026

#Include %A_ScriptDir%\..\user_config.ahk

SetWorkingDir %A_ScriptDir%
FileEncoding, UTF-8-RAW

; --- Пути относительно расположения скрипта ---
BaseDir := A_ScriptDir . "\.."
DataPath := BaseDir . "\data"

; Проверяем обязательные данные до изменения системного сообщения Windows.
if (UserFullName = "" or OwnerAbsenceMessage = "")
{
  MsgBox, 48, Требуется настройка, Заполните имя владельца и сообщение об отсутствии в user_config.ahk.
  ExitApp
}

; --- Автоповышение до прав администратора (для записи в HKLM) ---
if not A_IsAdmin
{
  Run *RunAs "%A_ScriptFullPath%"
  ExitApp
}

; --- Собираем сообщение Windows из настроек владельца и даты запуска ---
NoticeText := OwnerAbsenceMessage . ". КОМПЬЮТЕР ПРИНАДЛЕЖИТ ВЛАДЕЛЬЦУ. "
. "ЗАПРЕЩЕНО: ЗАПУСКАТЬ ТЯЖЁЛЫЕ ИГРЫ, ТЕСТЫ, ПРОГРАММЫ ДЛЯ РАЗГОНА, МЕНЯТЬ НАСТРОЙКИ BIOS. "
. "ЕСЛИ КОМПЬЮТЕР ЗАВИС - УДЕРЖИВАТЬ КНОПКУ ПИТАНИЯ 5-7 СЕКУНД. "
. "ЕСЛИ НЕТ КАРТИНКИ НА ЭКРАНЕ - ПРОВЕРИТЬ КАБЕЛЬ МОНИТОРА. "
. "ЕСЛИ ПОЯВИТСЯ ОКНО С ИНСТРУКЦИЕЙ - ПРОЧИТАЙ И ДЕЙСТВУЙ ПО НЕЙ. "
. "ЕСЛИ БУДЕТ СООБЩЕНИЕ ПРО ДИСК (SSD) - НЕ ЗАПУСКАЙ НИЧЕГО ТЯЖЁЛОГО И СОХРАНИ ВАЖНЫЕ ФАЙЛЫ. "
. "ЧИСТКА ОТ ПЫЛИ - РАЗ В 2 МЕСЯЦА. ПОСЛЕДНЯЯ ЧИСТКА: " . A_DD . "." . A_MM . "." . A_YYYY . ". "
. "ПОЛНАЯ ШПАРГАЛКА: docs\CheatSheet.md."

; Windows показывает этот заголовок и текст перед входом в систему.
RegWrite, REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, legalnoticecaption, % "ВНИМАНИЕ: ВЛАДЕЛЕЦ ПК — " . UserFullName
RegWrite, REG_SZ, HKEY_LOCAL_MACHINE, SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, legalnoticetext, %NoticeText%

; Если не удалось записать текст уведомления, дату чистки не обновляем.
if (ErrorLevel)
{
  MsgBox, 48, Ошибка, Не удалось записать в реестр.`nСкрипт должен быть запущен от имени администратора.
  FileAppend, %A_Now% ERROR: registry write failed`n, %DataPath%\errors.log
  ExitApp
}

; Файл хранит только дату последней отметки, поэтому заменяем старое значение.
FileDelete, %DataPath%\last_cleaning.txt
FileAppend, %A_Now%, %DataPath%\last_cleaning.txt

; --- Дописываем лог (с проверкой) ---
FileAppend, %A_YYYY%-%A_MM%-%A_DD% чистка отмечена`n, %DataPath%\cleaning_log.txt
if (ErrorLevel)
  FileAppend, %A_Now% ERROR: cleaning_log write failed`n, %DataPath%\errors.log

; После отметки чистки обнуляем счётчик дней и возвращаем статус в норму.
FormatTime, NiceDate, %A_Now%, dd.MM.yyyy
FileDelete, %DataPath%\status.txt
FileAppend, Status: OK`nLast cleaning: %NiceDate%`nDays since: 0`n, %DataPath%\status.txt

MsgBox, 64, Готово, Отмечено: корпус продут сегодня (%NiceDate%).`nСообщение при входе обновлено автоматически.`nСледующее напоминание - примерно через 2 месяца.
ExitApp
