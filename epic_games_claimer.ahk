#Requires AutoHotkey v2.0

; hotkey to exit script
Esc::ExitApp

WIDTH := 1920
HEIGHT := 1080

iniPath := A_ScriptDir . "\epic_games_claimer.ini"

isDailyActive := IniRead(iniPath, "settings", "daily_games", 1)
start := IniRead(iniPath, "settings", "daily_start", "")
end := IniRead(iniPath, "settings", "daily_end", "")
isRangeSet := start && end && start != end && isDailyActive
isDailyDate := isRangeSet && A_Now >= start && A_Now <= end
isHoliday := isDailyDate || (!isRangeSet && A_MM = 12) || true

; clear old range
if (A_MM = 12) {
    startYear := FormatTime(start, "yyyy")
    if (startYear < A_YYYY) {
        if (start) {
            IniDelete(iniPath, "settings" , "daily_start")
        }
        if (end) {
            IniDelete(iniPath, "settings" , "daily_end")
        }
    }
}

; activate on friday (day after new game) or daily in dec/jan
if (A_WDay = 6 || isHoliday) {
    main := Gui("+AlwaysOnTop", "Epic Games Claimer")
    main.onEvent("close", cancel)
    main.setFont("s10", "Verdana")
    if (isHoliday) {
        main.add("Text",, "Happy Holidays!")
    }
    main.add("Button", "Default w85 h50", "Continue").onEvent("click", runMain)
    main.add("Button", "x+m w85 h50", "Snooze").onEvent("click", snooze)
    main.add("Button", "x+m w85 h50", "Settings").onEvent("click", openSettings)
    main.show()
} else {
    ExitApp
}

awaitColor(x, y, target, timeout, msg) {
    startTime := A_TickCount
    Loop {
        color := PixelGetColor(x, y)
        if (color = target) {
            return true
        }
        if (A_TickCount - startTime > timeout) {
            ; color not found in time limit
            err_msg(msg . " not found", "Epic Games Claimer")
            return false
        }
        Sleep(100)
    }
}

err_msg(msg, title) {
    TrayTip(msg, title)
    ExitApp
}

runMain(*) {
    main.destroy()

    Run("C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe")
    WinWaitActive("Epic Games Launcher")

    ; black right before load
    awaitColor(WIDTH / 2, 450, "0x000000", 15000, "Loading screen")

    ; black on store page
    awaitColor(WIDTH / 2, 450, "0x121212", 5000, "Home page")

    ; middle of screen
    middleX := 960
    middleY := 540
    MouseMove(middleX, middleY)

    ; scroll to the bottom (free game not loaded yet)
    Loop 18 {
        MouseClick("WheelDown")
    }

    awaitColor(1925, 600, "0xA6A6A6", 10000, "Scroll bar")

    ; scroll to free game when loaded
    Loop 5 {
        MouseClick("WheelDown")
    }

    ; wait for scroll to finish properly
    Sleep(500)
    awaitColor(500, 800, "0x0078F2", 5000, "Free game")

    ; click on free game
    Click(785, 610)

    timeout := 15000
    startTime := A_TickCount
    Loop {
        ; first check for content warning continue button
        color := PixelGetColor(965, 700)
        if (color = "0x0074E4") {
            ; click button, don't break loop
            Click(965, 720)
        }

        ; then check if page bg is light or dark
        color := PixelGetColor(1650, 200)

        red := (color >> 16) & 0xff
        green := (color >> 8) & 0xff
        blue := color & 0xff

        red := red / 255, green := green / 255, blue := blue / 255
        red := (red <= 0.03928) ? (red / 12.92) : ((red + 0.055) / 1.055) ** 2.4
        green := (green <= 0.03928) ? (green / 12.92) : ((green + 0.055) / 1.055) ** 2.4
        blue := (blue <= 0.03928) ? (blue / 12.92) : ((blue + 0.055) / 1.055) ** 2.4

        luminance := 0.2126 * red + 0.7152 * green + 0.0722 * blue

        ; use different img based on bg
        if (luminance > 0.5) {
            found := ImageSearch(&x, &y, 1450, 640, 1580, 1010, "*15 *TransWhite light_img.png")
        } else {
            found := ImageSearch(&x, &y, 1450, 640, 1580, 1010, "*15 *TransBlack dark_img.png")
        }
        if (found) {
            Click(1665, y + 118)
            break
        }

        if (A_TickCount - startTime > timeout) {
            err_msg("Get button not found", "Epic Games Claimer")
        }
        Sleep(100)
    }

    ; order game
    awaitColor(1525, 955, "0x0078F2", 10000, "Order button")
    Click(1525, 955)

    ExitApp
}

dailyCheckbox := ""
dt := ""
dt2 := ""
openSettings(*) {
    settings := Gui("+AlwaysOnTop", "Settings")
    settings.setFont("s10", "Verdana")

    dailyValue := IniRead(iniPath, "settings", "daily_games", 1)
    global dailyCheckbox
    dailyCheckbox := settings.add("CheckBox", dailyValue ? "Checked" : "", "Daily holiday games")

    y := A_MM = 1 ? (A_YYYY - 1) : A_YYYY
    rangeOptions := "Right Range" . y . "1201-" . y + 1 . "0131"

    dtValue := IniRead(iniPath, "settings", "daily_start", "")
    global dt
    dt := settings.add("DateTime", rangeOptions . (dtValue ? " Choose" . dtValue : ""), "LongDate")

    dt2Value := IniRead(iniPath, "settings", "daily_end", "")
    global dt2
    dt2 := settings.add("DateTime", rangeOptions . (dt2Value ? " Choose" . dt2Value : ""), "LongDate")

    saveBtn := settings.add("Button", "w85 h50", "Save").onEvent("click", saveSettings)
    settings.show()
}

saveSettings(*) {
    IniWrite(dailyCheckbox.value, iniPath, "settings", "daily_games")

    if (dt2.value < dt.value) {
        TrayTip("End date needs to be after start date", "Epic Games Claimer")
    } else {
        IniWrite(dt.value, iniPath, "settings", "daily_start")
        IniWrite(dt2.value, iniPath, "settings", "daily_end")
        TrayTip("Settings saved", "Epic Games Claimer")
    }
}

snooze(*) {
    main.hide()
    ; wait 5 min
    Sleep(300000)
    main.show()
}

cancel(*) {
    main.destroy()
    ExitApp
}
