#Requires AutoHotkey v2.0
#SingleInstance Force

; hotkey to exit script
Esc:: {
    TrayTip("Exited script using Esc key", "Epic Games Claimer")
    ExitApp
}

WIDTH := 1920
HEIGHT := 1080

; client mode to make relative to launcher window
CoordMode("Pixel", "Client")

iniPath := A_ScriptDir . "\epic_games_claimer.ini"

lastClaimed := IniRead(iniPath, "config", "last_claimed", "")
if (lastClaimed = now()) {
    ; don't activate if already claimed today
    ExitApp
}

isDailyActive := IniRead(iniPath, "settings", "daily_games", 1)
start := IniRead(iniPath, "settings", "daily_start", "")
end := IniRead(iniPath, "settings", "daily_end", "")
isRangeSet := start && end && start != end && isDailyActive
isDailyDate := isRangeSet && now() >= start && now() <= end
isHoliday := isDailyDate || (!isRangeSet && A_MM = 12)

; clear old range
if (A_MM = 12) {
    startYear := FormatTime(start, "yyyy")
    if (startYear < A_YYYY) {
        if (start) {
            IniDelete(iniPath, "settings", "daily_start")
        }
        if (end) {
            IniDelete(iniPath, "settings", "daily_end")
        }
    }
}

; activate on friday (day after new game) or daily in dec/jan
if (A_WDay = 6 || isHoliday) {
    main := Gui("+AlwaysOnTop", "Epic Games Claimer")
    main.onEvent("close", cancel)
    main.setFont("s10", "Verdana")
    if (isHoliday) {
        main.add("Text", , "Happy Holidays!")
    }
    main.add("Button", "Default w85 h50", "Continue").onEvent("click", runMain)
    main.add("Button", "x+m w85 h50", "Snooze").onEvent("click", openSnoozeGui)
    main.add("Button", "x+m w85 h50", "Settings").onEvent("click", openSettings)
    main.show()
} else {
    ExitApp
}

log(msg) {
    FileAppend(msg . "`n", "log.txt")
}

awaitColor(x, y, target, timeout, msg, isNegative := false) {
    startTime := A_TickCount
    loop {
        color := PixelGetColor(x, y)
        if ((color = target) != isNegative) {
            return true
        }
        checkTimeout(startTime, timeout, msg)
    }
}

checkTimeout(startTime, timeout, msg, isSilent := false) {
    if (A_TickCount - startTime > timeout) {
        ; color not found in time limit
        if (!isSilent) {
            TrayTip(msg . " not found", "Epic Games Claimer")
        }
        ExitApp
    }
    Sleep(100)
}

removeTime(date) {
    return FormatTime(date, "yyyyMMdd")
}

now() {
    return removeTime(A_Now)
}

searchForGame(searchX, claimX, isSilent := false) {
    ; look for blue free game banner
    timeout := 5000
    startTime := A_TickCount
    loop {
        ; scroll a bit farther down each time
        loop 2 {
            MouseClick("WheelDown")
        }
        ; search a line down the screen for free game banner
        found := PixelSearch(&x, &y, searchX, 350, searchX, 900, "0x26BBFF")
        if (found) {
            claimY := y - 300
            MouseMove(claimX, claimY)
            ; move mouse a tiny amount before clicking which
            ; avoids navigating to the wrong game
            MouseMove(claimX - 20, claimY - 20)

            loop 5 {
                ; keep clicking on game thumbnail while it loads
                Click(2)
                Sleep(25)
            }
            break
        }
        checkTimeout(startTime, timeout, "Free game", isSilent)
    }
}

calcLuminance(color) {
    red := (color >> 16) & 0xff
    green := (color >> 8) & 0xff
    blue := color & 0xff

    red := red / 255, green := green / 255, blue := blue / 255
    red := (red <= 0.03928) ? (red / 12.92) : ((red + 0.055) / 1.055) ** 2.4
    green := (green <= 0.03928) ? (green / 12.92) : ((green + 0.055) / 1.055) ** 2.4
    blue := (blue <= 0.03928) ? (blue / 12.92) : ((blue + 0.055) / 1.055) ** 2.4

    luminance := 0.2126 * red + 0.7152 * green + 0.0722 * blue
    return luminance
}

claimGame() {
    timeout := 15000
    startTime := A_TickCount
    loop {
        ; first check for content warning continue button
        color := PixelGetColor(965, 700)
        if (color = "0x0074E4") {
            ; click button, don't break loop
            Click(965, 720)
        }

        ; then check if page bg is light or dark
        color := PixelGetColor(1650, 200)
        luminance := calcLuminance(color)

        getSearchOptions(target) {
            ; use different img based on bg
            lightMask := "*15 *TransWhite utils/masks/" . target . "/light.png"
            darkMask := "*15 *TransBlack utils/masks/" . target . "/dark.png"

            ; for light bg, check dark mask first (light text)
            primaryMask := luminance > 0.5 ? darkMask : lightMask
            ; secondary mask is opposite one
            secondaryMask := primaryMask = lightMask ? darkMask : lightMask

            return [primaryMask, secondaryMask]
        }

        ; top left
        x1 := 1450
        y1 := 540
        ; bottom right
        x2 := 1580
        y2 := 1010

        ; first check if on correct page (Base Game text is visible)
        searchOptions := getSearchOptions("base_game")
        ; use opposite (for light bg, search for dark text)
        baseGameMask := searchOptions[2]
        found := ImageSearch(&x, &y, x1, y1, x2, y2, baseGameMask)
        if (!found) {
            continue
        }

        ; then make sure it's a free game by checking for -100% badge
        searchOptions := getSearchOptions("100")
        primaryMask := searchOptions[1]
        secondaryMask := searchOptions[2]

        ; reduce search area because now position is known
        y1 := y + 40
        x2 := 1530
        y2 := y1 + 30
        ; check for same color text (ex: light bg and light text)
        found := ImageSearch(&x, &y, x1, y1, x2, y2, primaryMask)
        if (!found) {
            ; if not found, check other mask (ex: light bg and dark text)
            found := ImageSearch(&x, &y, x1, y1, x2, y2, secondaryMask)
        }

        if (found) {
            Click(1665, y + 85)
            break
        }

        checkTimeout(startTime, timeout, "Get button")
    }

    ; order game
    awaitColor(1525, 955, "0x0078F2", 20000, "Order button")
    Click(1465, 960)

    ; check for yellow square icon above continue browsing button
    awaitColor(990, 480, "0xD6F85F", 10000, "Continue browsing button")
    ; click continue browsing
    Click(815, 720)

    ; go back to store
    ; awaitColor(60, 200, "0xFFFFFF", 5000, "Store button")
    ; Click(60, 200)
}

runMain(*) {
    main.destroy()

    Run("C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe")
    WinWaitActive("Epic Games Launcher")
    ; make sure launcher is maximized
    WinMaximize

    ; black right before load
    awaitColor(WIDTH / 2, 450, "0x000000", 15000, "Loading screen")

    ; black on store page
    awaitColor(1200, 80, "0x101014", 5000, "Home page")

    ; make sure mouse is on correct monitor
    MouseMove(WIDTH / 2, HEIGHT / 2)

    ; scroll to bottom (above free game)
    loop 30 {
        MouseClick("WheelDown")
    }

    ; search for first game (sometimes there are two)
    searchForGame(550, 550 + 150)
    claimGame()

    ; second game
    ; search on the right of the "free now" text
    ; because when there's only one game, it's bigger and could be found
    ; searchForGame(1250, 1250 - 150, true)
    ; claimGame()

    IniWrite(now(), iniPath, "config", "last_claimed")

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
        IniWrite(removeTime(dt.value), iniPath, "settings", "daily_start")
        IniWrite(removeTime(dt2.value), iniPath, "settings", "daily_end")
        TrayTip("Settings saved", "Epic Games Claimer")
    }
}

snooze(snoozeGui, time, *) {
    snoozeGui.destroy()
    main.hide()
    Sleep(time)
    main.show()
}

openSnoozeGui(*) {
    snoozeGui := Gui("+AlwaysOnTop", "Snooze")
    snoozeGui.setFont("s10", "Verdana")

    sBtn1 := snoozeGui.add("Button", "Default w85 h50", "5 min")
    sBtn1.onEvent("click", (*) => snooze(snoozeGui, 300000))

    sBtn2 := snoozeGui.add("Button", "x+m w85 h50", "30 min")
    sBtn2.onEvent("click", (*) => snooze(snoozeGui, 1.8e6))

    sBtn3 := snoozeGui.add("Button", "x+m w85 h50", "2 hr")
    sBtn3.onEvent("click", (*) => snooze(snoozeGui, 3.6e6))

    snoozeGui.show()
}

cancel(*) {
    main.destroy()
    ExitApp
}
