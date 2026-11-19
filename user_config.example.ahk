#Requires AutoHotkey v1.1.33+
; Скопируйте этот файл в user_config.ahk и укажите свои данные.
; Не публикуйте user_config.ahk: в нем содержатся личные контакты.

UserFullName := "" ; Именительный падеж: Иван
UserFullNameGen := "" ; Родительный падеж: Ивана
UserFullNameDat := "" ; Дательный падеж: Ивану
OwnerAbsenceMessage := "" ; Например: ВЛАДЕЛЕЦ ПК УЕХАЛ В АРМИЮ
ContactPhone := ""

; Ищем MarkView в папке AppData текущего пользователя.
EnvGet, LocalAppData, LOCALAPPDATA
ViewerPath := LocalAppData . "\MarkView\markview.exe"
