#Requires AutoHotkey v2.0
#SingleInstance Force
; =============================================================================
; expandable-toolbar · 可扩展桌面小工具条 (AutoHotkey v2)
; 常驻置顶的横排图标工具条：点图标展开对应小面板、用完自动收回。跟终端无关
; (Tabby / Windows Terminal / PowerShell / cmd 都能用)，不用管理员权限。
; 收起后停几秒会自动缩成一个半透明"工具球"(点一下展开回来)，避免长期占地方、少挡内容。
; 仓库：https://github.com/yiren-pacvue/expandable-toolbar
;
; 内置三个工具（往下面 gTools 列表加一项即可扩展新工具）：
;   · 截图缩略图面板  盯截图文件夹，点缩略图把图片绝对路径插入当前窗口；
;                     右键缩略图看原图(左键点=插入 / 左键按住拖=移动 / 右键=关闭)
;   · 命令/文字片段   预存片段点击插入；支持别名 / 多行 / 文本或 .ps1 脚本两种模式 / 拖动排序 / 滚动
;   · 时间戳转时区    填秒级时间戳，实时显示 中国(UTC+8) / UTC / PST(-8) / PDT(-7)
;
; 工具条交互：
;   · 点某图标 → 展开它的面板(贴在工具条正下方，下方不够翻上)；再点该图标收起；点别的图标切换
;   · 拖动工具条挪位置(展开的面板会跟随)；支持双屏 + 高 DPI 缩放
;   · Ctrl+Alt+I → 面板 ↔ 工具条 来回切；托盘图标右键有更多菜单
;
; 命令行参数：/min 最小化启动(开机自启用)；/install、/uninstall 装/卸开机自启。
; 唯一会失效的情况：终端以"管理员身份"运行而本工具不是时，Windows 会挡住向管理员
;   窗口发按键；此时把本工具也用管理员跑即可。
; =============================================================================

; ---------------------------- 配置（可直接改）--------------------------------
Folder        := "C:\MyDownload\claude_picture"  ; 截图文件夹；也可在同目录 ini 里改
Cols          := 3        ; 缩略图列数
PanelRows     := 4        ; 面板一屏显示几行（决定面板高度）
MaxFiles      := 30       ; 最多加载几张（超过 PanelRows*Cols 的部分靠滚轮翻）
ThumbW        := 170      ; 缩略图格子宽（像素）；图片按原比例缩放居中放进格子
ThumbH        := 105      ; 缩略图格子高（像素）
LabelH        := 16       ; 每张图下方文字高度
FontSize      := 10       ; 面板文字字号（加大并加粗，避免看不清）
SendSpace     := true     ; 插入路径后是否补一个空格（和原 Tabby 插件一致）
WrapQuotes    := false    ; 路径是否加双引号（路径含空格时建议开；默认关）
ToggleKey     := "^!i"    ; 面板↔图标 热键（Ctrl+Alt+I）
RefreshMs     := 1500     ; 自动检查文件夹变化的间隔（毫秒）
ImgExts       := "png,jpg,jpeg,gif,bmp,webp"  ; 认作图片的扩展名
HeaderH       := 44       ; 顶部工具条高度
; ---- 右键缩略图看原图（预览里 左键点=插入路径 / 右键点=关闭）----
PreviewMaxRatio   := 0.9  ; 原图最多占所在屏幕的比例（留点边，别顶满）
; ---- 最小化后的"小工具条"外观（以后可加更多小工具）----
IconCell      := 32       ; 每个小图标格子的"宽"（决定横向间距/宽度）
IconRowH      := 24       ; 图标行"高"（决定工具条上下高度；越小越扁）
IconGap       := 10       ; 图标之间的自然间隔
IconPad       := 8        ; 工具条左右留白（宽度方向）
IconPadV      := 6        ; 工具条上下留白（高度方向，单独调，不影响宽度）
IconRadius    := 12       ; 容器圆角半径
IconNudgeUp   := 0        ; 图标整体上移像素；Fluent 图标自带居中，一般 0，偏上/下再微调
IconBg        := "F5F6F8" ; 工具条容器底色（浅色，仿参考图）
IconColor     := "5B5F6E" ; 图标颜色（灰蓝，仿参考图）
IconFont      := "Segoe Fluent Icons"  ; Win11 自带线条图标字体（若显示成方块，改成 "Segoe MDL2 Assets"）
ActivateWindowUnderIcon := true  ; 点图标展开时自动激活图标正下方的窗口(通常是 Claude 终端)，避免插错窗口
KeepOnTopMs   := 800      ; 每隔多久把当前可见窗口重新顶回"置顶层"最上面(毫秒)；防被别的置顶窗口盖住。设 0 关闭
SnipMaxRows   := 7        ; 命令片段面板最多显示几行，超过就出滚动条、滚轮翻
; ---- 收起后自动缩成"工具球"（半透明气泡，点一下变回工具条）----
EnableBubble  := true     ; 开关：收起状态(没展开面板)停留几秒后自动缩成气泡
BubbleDelayMs := 1500     ; 收起后多久缩成气泡（毫秒）
BubbleSize    := 34       ; 气泡直径（像素）
BubbleAlpha   := 128      ; 气泡不透明度 0-255（128≈50%，越小越通透）
BubbleRing    := 3        ; 边缘对比圈宽度（像素）
BubbleColor   := "F5F6F8" ; 气泡主体色
BubbleRingCol := "3A7BD5" ; 边缘对比圈颜色（选醒目色，半透明下也好定位）
; ---- 终端里用 Shift+滚轮 滚动 Claude 对话（绕过全屏滚轮失效）----
EnableShiftWheelScroll := true    ; 开关：在终端窗口里 Shift+滚轮 = 滚动 Claude 对话
PlainWheelScroll       := false   ; 进一步：不按 Shift 直接滚轮滚动（会覆盖滚轮原本的翻历史）；默认关
LinesPerNotch          := 1       ; 每个滚轮格滚几行（嫌快调小、嫌慢调大）；发的是 Alt+↑/↓，须与 ~/.claude/keybindings.json 的 scroll:lineUp/Down 对应
TermExes               := "Tabby.exe,WindowsTerminal.exe,powershell.exe,pwsh.exe,conhost.exe"  ; 认作"终端"的进程名
; -----------------------------------------------------------------------------

CoordMode("Mouse", "Screen")

; ---- 全局状态 ----
global MyGui := "", iconGui := "", gVisible := false, gTargetWin := 0, gLastSig := ""
global gItems := [], gScrollRow := 0, gTotalRows := 0, gRowsPerView := 0, gFileCount := 0
global gCountText := "", iconBtnHwnd := 0, gSizeCache := Map(), gPicCache := Map(), gScanSig := ""
global gPosX := "", gPosY := ""
global gArmedMinimize := false   ; 已插入过一次路径 → 武装：下次点面板外自动最小化
global gTools := [], gIconCtrls := [], gIconW := 0, gIconH := 0   ; 最小化小工具条
global snipGui := "", gSnips := [], gSnipVisible := false          ; 命令/文字片段工具（每条 {alias, cmd}）
global gSnipCtrlIdx := Map(), gSnipScroll := 0   ; 片段卡片控件 hwnd→序号 + 滚动偏移(跳过前几条)
global gEditing := false   ; 正在弹"添加/编辑片段"对话框：期间 TrackActive/KeepOnTop 都让路
global tzGui := "", gTzVisible := false, gTzInput := "", gTzOut := ""   ; 时间戳转时区工具
global gActivePanel := ""   ; 当前展开的是哪个面板：""=没展开 / "thumb" / "snip" / "tz"（工具条常驻）
global bubbleGui := "", bubbleCore := "", gBubbleVisible := false   ; "工具球"：外圈不透明对比环 + 内圆半透明 + 中心"工"字
global previewGui := "", gPreviewPath := ""   ; 右键看原图：预览窗 + 当前图路径（左键点=插入/按住拖=移动，右键=关闭）

; ---- 从同目录 ini 读取覆盖 ----
IniPath := A_ScriptDir "\截图面板.ini"
Folder   := IniRead(IniPath, "config", "Folder", Folder)
gPosX    := IniRead(IniPath, "pos", "X", "")
gPosY    := IniRead(IniPath, "pos", "Y", "")
LoadSnips()   ; 读取已存的命令/文字片段

; ---- 托盘菜单 ----
A_TrayMenu.Delete()
A_TrayMenu.Add("显示/隐藏面板`t" ToggleKey, (*) => TogglePanel())
A_TrayMenu.Add("打开截图文件夹", (*) => Run(Folder))
A_TrayMenu.Add("重新扫描", (*) => Rebuild())
A_TrayMenu.Add("命令/文字片段", (*) => OpenSnippets())
A_TrayMenu.Add()
A_TrayMenu.Add("设为开机自启", (*) => InstallStartup())
A_TrayMenu.Add("取消开机自启", (*) => UninstallStartup())
A_TrayMenu.Add()
A_TrayMenu.Add("退出", (*) => ExitApp())
A_TrayMenu.Default := "显示/隐藏面板`t" ToggleKey
A_IconTip := "截图缩略图面板 (" ToggleKey " 开关)"

; ---- 热键、定时器、消息、退出钩子 ----
Hotkey(ToggleKey, TogglePanel)
SetTimer(TrackActive, 250)
SetTimer(RefreshIfChanged, RefreshMs)
if (KeepOnTopMs > 0)
    SetTimer(KeepOnTop, KeepOnTopMs)   ; 定期重新置顶，防被别的置顶窗口盖到底层
OnMessage(0x201, IconLDown)     ; WM_LBUTTONDOWN：小图标的点击/拖动
OnMessage(0x201, SnipLDown)     ; WM_LBUTTONDOWN：片段卡片的点击(插入)/上下拖(排序)
OnMessage(0x201, BubbleLDown)   ; WM_LBUTTONDOWN：工具球的点击(展开)/拖动
OnMessage(0x201, PreviewLDown)  ; WM_LBUTTONDOWN：原图预览的点击(插入)/按住拖(移动)
OnExit(SaveState)

; ---- 注册"终端里 Shift+滚轮翻页"热键 ----
if EnableShiftWheelScroll {
    HotIf IsTerminalActive
    Hotkey("+WheelUp", (*) => DoScroll("up"))
    Hotkey("+WheelDown", (*) => DoScroll("down"))
    if PlainWheelScroll {
        Hotkey("WheelUp", (*) => DoScroll("up"))
        Hotkey("WheelDown", (*) => DoScroll("down"))
    }
    HotIf
}

; ---- 命令行参数：/install 装开机自启, /uninstall 卸, /min 最小化启动 ----
startMin := false
for a in A_Args {
    if (a = "/install") {
        InstallStartup()
        ExitApp()
    } else if (a = "/uninstall") {
        UninstallStartup()
        ExitApp()
    } else if (a = "/min") {
        startMin := true
    }
}
ShowBar()          ; 工具条常驻，启动先显示工具条
if !startMin
    Rebuild()      ; 非最小化启动：顺便展开缩略图面板
return

; ============================== 开机自启 =====================================
StartupLnk() => A_Startup "\截图缩略图面板.lnk"

InstallStartup() {
    ; 用运行本脚本的 AutoHotkey exe 作目标，参数带 /min（开机时最小化到上次位置）
    FileCreateShortcut(A_AhkPath, StartupLnk(), A_ScriptDir
        , '"' A_ScriptFullPath '" /min', "开机自启：截图缩略图面板(最小化到上次位置)")
}

UninstallStartup() {
    if FileExist(StartupLnk())
        FileDelete(StartupLnk())
}

; ================================ 滚轮 =======================================
#HotIf MouseOverPanel()
WheelUp::ScrollPanel(-1)
WheelDown::ScrollPanel(1)
#HotIf

#HotIf MouseOverSnip()
WheelUp::ScrollSnip(-1)
WheelDown::ScrollSnip(1)
#HotIf

MouseOverPanel() {
    global MyGui, gVisible
    if (!gVisible || MyGui = "")
        return false
    MouseGetPos(, , &winId)
    return (winId = MyGui.Hwnd)
}

MouseOverSnip() {
    global snipGui, gSnipVisible
    if (!gSnipVisible || snipGui = "")
        return false
    MouseGetPos(, , &winId)
    return (winId = snipGui.Hwnd)
}

; 命令片段面板滚动：改滚动偏移并重建面板
ScrollSnip(dir) {
    global gSnips, gSnipScroll, SnipMaxRows
    rows := gSnips.Length
    visRows := Min(rows, SnipMaxRows)
    maxScroll := Max(0, rows - visRows)
    nv := Max(0, Min(maxScroll, gSnipScroll + dir))
    if (nv != gSnipScroll) {
        gSnipScroll := nv
        OpenSnippets()
    }
}

ScrollPanel(dir) {
    global gScrollRow, gTotalRows, gRowsPerView
    maxScroll := Max(0, gTotalRows - gRowsPerView)
    newRow := Max(0, Min(maxScroll, gScrollRow + dir))
    if (newRow != gScrollRow) {
        gScrollRow := newRow
        ApplyScroll()
    }
}

; 当前活动窗口是否是"终端"（供 Shift+滚轮热键判断作用范围）
IsTerminalActive(*) {
    global TermExes
    try
        p := WinGetProcessName("A")
    catch
        return false
    for e in StrSplit(TermExes, ",")
        if (p = Trim(e))
            return true
    return false
}

; 滚动 N 行：离散发 N 个方向键（普通 SendInput，不加延时，不会被当成翻页）。
; {Blind} 保留当前物理修饰键原样：
;   · Shift+滚轮：Shift 物理按住 → 发出的是 Shift+↑/↓（keybindings 绑 shift+up/down → 滚一行）。
;     全程不碰 Shift、不用 Alt，所以既不会漏裸方向键翻历史、也不会因 Alt 掉键窜到顶部。
;   · 若开了 PlainWheelScroll（不按 Shift）：改发 Alt+↑/↓（keybindings 也绑了 alt+up/down）。
DoScroll(dir) {
    global LinesPerNotch
    k := (dir = "up") ? "Up" : "Down"
    useShift := GetKeyState("Shift", "P")
    seq := "{Blind}"
    Loop LinesPerNotch
        seq .= useShift ? ("{" k "}") : ("{Alt down}{" k "}{Alt up}")
    Send(seq)
}

; 换截图文件夹：弹目录选择框，选完存进 ini 并刷新
ChangeFolder(*) {
    global Folder, IniPath, gSizeCache
    sel := DirSelect("*" Folder, 3, "选择截图文件夹")
    if (sel = "" || sel = Folder)
        return
    Folder := sel
    gSizeCache := Map()      ; 换目录后清尺寸缓存
    try IniWrite(Folder, IniPath, "config", "Folder")
    Rebuild()
}

; ============================== 数据扫描 =====================================
; 单遍扫描：只保留 mtime 最新的 MaxFiles 张（top 始终降序）。不再对全部文件做 O(n²) 冒泡排序，
; 文件夹越来越大也只是 O(n·MaxFiles)。顺便算出"张数|最新时间"签名存 gScanSig，供 Rebuild 复用(免二次扫描)。
GetFiles() {
    global Folder, MaxFiles, ImgExts, gScanSig
    extList := StrSplit(StrLower(ImgExts), ",")
    top := []
    count := 0, maxM := 0
    if !DirExist(Folder) {
        gScanSig := "none"
        return top
    }
    Loop Files, Folder "\*.*" {
        ext := StrLower(A_LoopFileExt)
        isImg := false
        for e in extList {
            if (ext = e) {
                isImg := true
                break
            }
        }
        if !isImg
            continue
        count++
        m := A_LoopFileTimeModified
        if (m > maxM)
            maxM := m
        ; 已满且比当前最旧的还旧 → 不可能进前 MaxFiles，直接跳过
        if (top.Length >= MaxFiles && m <= top[top.Length].mtime)
            continue
        rec := { path: A_LoopFileFullPath, mtime: m, name: A_LoopFileName }
        inserted := false
        Loop top.Length {
            if (m > top[A_Index].mtime) {
                top.InsertAt(A_Index, rec)
                inserted := true
                break
            }
        }
        if !inserted
            top.Push(rec)
        if (top.Length > MaxFiles)
            top.Pop()
    }
    gScanSig := count "|" maxM
    return top
}

; 轻量变更签名：只数图片张数 + 记最新修改时间，不排序、不建对象。
; 每 1.5s 判断文件夹是否变化用它——文件夹再大也只是一次 O(n) 扫描。
FolderSignature() {
    global Folder, ImgExts
    extList := StrSplit(StrLower(ImgExts), ",")
    if !DirExist(Folder)
        return "none"
    count := 0, maxM := 0
    Loop Files, Folder "\*.*" {
        ext := StrLower(A_LoopFileExt)
        isImg := false
        for e in extList {
            if (ext = e) {
                isImg := true
                break
            }
        }
        if !isImg
            continue
        count++
        if (A_LoopFileTimeModified > maxM)
            maxM := A_LoopFileTimeModified
    }
    return count "|" maxM
}

ShortLabel(name) {
    stem := RegExReplace(name, "\.[^.]+$", "")
    if RegExMatch(name, "(\d{4})-(\d{2})-(\d{2})[_ ](\d{2})-(\d{2})-(\d{2})", &m)
        return m[2] "-" m[3] " " m[4] ":" m[5] ":" m[6]
    if (StrLen(stem) > 20)
        stem := "…" SubStr(stem, -17)
    return stem
}

; 读图片原始像素尺寸（带缓存，避免每次刷新都重解码）
GetImageSize(path, mtime) {
    global gSizeCache
    key := path "|" mtime
    if gSizeCache.Has(key)
        return gSizeCache[key]
    sz := { w: 0, h: 0 }
    hbm := 0
    try hbm := LoadPicture(path, "", &imgType)
    if hbm {
        bm := Buffer(40, 0)
        if DllCall("GetObject", "Ptr", hbm, "Int", 32, "Ptr", bm.Ptr)
            sz := { w: NumGet(bm, 4, "Int"), h: NumGet(bm, 8, "Int") }
        DllCall("DeleteObject", "Ptr", hbm)
    }
    gSizeCache[key] := sz
    return sz
}

; 取"缩放到 w×h 的位图句柄"，带缓存：同一图片(按 路径|修改时间|尺寸)只解码一次，之后复用。
; 这是刷新提速的关键——刷新时未变的缩略图直接复用缓存位图，不再重新解码。
GetScaledBitmap(path, mtime, w, h) {
    global gPicCache
    key := path "|" mtime "|" w "|" h
    if gPicCache.Has(key)
        return gPicCache[key]
    hbm := 0
    try hbm := LoadPicture(path, "w" w " h" h, &t)   ; 加载时直接缩放，返回位图句柄
    if hbm
        gPicCache[key] := hbm
    return hbm
}

; 删除本次重建没用到的缓存位图（图片被删/改名/换目录后），防 GDI 句柄泄漏
PrunePicCache(usedKeys) {
    global gPicCache
    toDelete := []
    for key in gPicCache
        if !usedKeys.Has(key)
            toDelete.Push(key)
    for key in toDelete {
        try DllCall("DeleteObject", "Ptr", gPicCache[key])
        gPicCache.Delete(key)
    }
}

; 按原比例把 iw×ih 缩放进 boxW×boxH，返回缩放后尺寸和居中偏移（不放大小图）
FitBox(iw, ih, boxW, boxH) {
    if (iw <= 0 || ih <= 0)
        return { w: boxW, h: boxH, x: 0, y: 0 }
    scale := Min(boxW / iw, boxH / ih)
    if (scale > 1)
        scale := 1
    w := Max(1, Round(iw * scale)), h := Max(1, Round(ih * scale))
    return { w: w, h: h, x: (boxW - w) // 2, y: (boxH - h) // 2 }
}

; 把窗口位置钳制到"整个虚拟桌面(所有屏幕合起来)"范围内，而不是只在主屏。
; 修双屏 bug：旧代码用 A_ScreenWidth(主屏宽)钳制，副屏上的窗口会被硬拉回主屏右缘。
; 已实测：GetSystemMetrics 虚拟屏坐标与 AHK Gui 坐标同一套，高 DPI 下无需额外换算。
ClampToScreen(&x, &y, w, h) {
    vx := DllCall("GetSystemMetrics", "Int", 76)   ; SM_XVIRTUALSCREEN 虚拟屏左(副屏在左时为负)
    vy := DllCall("GetSystemMetrics", "Int", 77)   ; SM_YVIRTUALSCREEN 虚拟屏上(可能为负)
    vw := DllCall("GetSystemMetrics", "Int", 78)   ; SM_CXVIRTUALSCREEN 所有屏总宽
    vh := DllCall("GetSystemMetrics", "Int", 79)   ; SM_CYVIRTUALSCREEN 所有屏总高
    x := Max(vx, Min(x, vx + vw - w))
    y := Max(vy, Min(y, vy + vh - h))
}

; ---- 工具条常驻模型：面板贴在工具条旁、工具条一直显示 ----

; 算面板该开在哪：贴工具条正下方；若下方到屏幕底不够，就翻到工具条上方。最后整体钳进屏幕。
PlacePanelByBar(&x, &y, w, h) {
    global iconGui, gPosX, gPosY
    gap := 4
    if (iconGui != "" && DllCall("IsWindowVisible", "Ptr", iconGui.Hwnd)) {
        iconGui.GetPos(&bx, &by, &bw, &bh)
    } else {
        bx := (gPosX != "") ? gPosX : 100
        by := (gPosY != "") ? gPosY : 100
        bh := 30
    }
    x := bx
    vy := DllCall("GetSystemMetrics", "Int", 77)   ; 虚拟屏上边界
    vh := DllCall("GetSystemMetrics", "Int", 79)   ; 虚拟屏总高
    yDown := by + bh + gap
    y := (yDown + h <= vy + vh) ? yDown : (by - gap - h)   ; 下方够就往下，否则翻上
    ClampToScreen(&x, &y, w, h)
}

; 确保工具条已创建并显示在 gPosX/gPosY（常驻，不再随面板隐藏）
ShowBar() {
    global iconGui, gPosX, gPosY, gIconW, gIconH, IconRadius, gActivePanel, EnableBubble, BubbleDelayMs
    HideBubble()          ; 从气泡切回工具条：先收掉气泡
    if (iconGui = "")
        CreateIcon()
    ix := (gPosX != "") ? gPosX : (A_ScreenWidth - gIconW - 20)
    iy := (gPosY != "") ? gPosY : 100
    ClampToScreen(&ix, &iy, gIconW, gIconH)
    iconGui.Show("x" ix " y" iy " w" gIconW " h" gIconH " NoActivate")
    RoundWindow(iconGui.Hwnd, IconRadius)
    ; 收起状态(没展开面板)时，过几秒自动缩成气泡；有面板展开则取消
    if (EnableBubble && gActivePanel = "")
        SetTimer(ShrinkToBubble, -BubbleDelayMs)
    else
        SetTimer(ShrinkToBubble, 0)
}

; 拖动工具条后，把当前展开的面板一起挪到工具条新位置旁
RepositionActivePanel() {
    global gActivePanel, MyGui, snipGui, tzGui
    pane := ""
    if (gActivePanel = "thumb" && MyGui != "")
        pane := MyGui
    else if (gActivePanel = "snip" && snipGui != "")
        pane := snipGui
    else if (gActivePanel = "tz" && tzGui != "")
        pane := tzGui
    if (pane = "")
        return
    pane.GetPos(, , &pw, &ph)
    x := 0, y := 0
    PlacePanelByBar(&x, &y, pw, ph)
    pane.Move(x, y)
}

; 把某窗口塞回置顶层最上面（不抢焦点、不移位、不改大小）
Topmost(hwnd) {
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
}

; ---- 工具球（收起后的半透明气泡）----
; 收起状态(只剩工具条、没展开面板)停留一段时间后，把工具条缩成一个半透明小圆球，
; 半透明避免长期挡住下方内容，边缘留一圈醒目对比色帮你定位；点一下气泡就展开回工具条。
ShrinkToBubble() {
    global gActivePanel, iconGui, gBubbleVisible
    if (gActivePanel != "" || gBubbleVisible)   ; 有面板展开 / 已经是气泡 → 不缩
        return
    if (iconGui != "")
        try iconGui.Hide()
    ShowBubble()
}

; 显示气泡（两层）：
;   外圈 bubbleGui = 不透明的对比色"环"(环形窗，中心镂空) → 白底也看得见轮廓；
;   内圆 bubbleCore = 半透明圆(通透、少挡内容) + 中心不透明"工"字(标识这是工具条)。
; 两层拼成一个完整圆：环在最外一圈、内圆填中间。位置与工具条共用 gPosX/gPosY。
ShowBubble() {
    global bubbleGui, bubbleCore, gBubbleVisible, gPosX, gPosY, gIconW
    global BubbleSize, BubbleAlpha, BubbleRing, BubbleColor, BubbleRingCol, IconFont
    D := BubbleSize, ring := BubbleRing
    ringPx := Round(ring * (A_ScreenDPI / 96))
    bx := (gPosX != "") ? gPosX : (A_ScreenWidth - gIconW - 20)
    by := (gPosY != "") ? gPosY : 100
    ClampToScreen(&bx, &by, D, D)
    if (bubbleGui = "") {   ; 外圈环：不透明强对比色
        bubbleGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x08000000", "工具球")
        bubbleGui.MarginX := 0, bubbleGui.MarginY := 0
        bubbleGui.BackColor := BubbleRingCol
    }
    if (bubbleCore = "") {   ; 内圆：半透明球体 + 居中"工"字(不透明子控件；工字用普通字体，非图标字体)
        bubbleCore := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x08000000")
        bubbleCore.MarginX := 0, bubbleCore.MarginY := 0
        bubbleCore.BackColor := BubbleColor
        d2 := D - 2 * ring
        bubbleCore.SetFont("s" Round(D * 0.42) " c" BubbleRingCol, IconFont)   ; 用工具条同款图标字体
        bubbleCore.Add("Text", "x0 y0 w" d2 " h" d2 " Center 0x200 BackgroundTrans", Chr(0xE90F))  ; E90F=扳手(代表工具)
    }
    bubbleGui.Show("x" bx " y" by " w" D " h" D " NoActivate")
    RingWindow(bubbleGui.Hwnd, ringPx)                  ; 外圈裁成环(中心镂空)，不设半透明→白底也可见
    d2 := D - 2 * ring
    bubbleCore.Show("x" (bx + ring) " y" (by + ring) " w" d2 " h" d2 " NoActivate")
    RoundWindow(bubbleCore.Hwnd, d2 // 2)               ; 内圆
    WinSetTransparent(BubbleAlpha, bubbleCore.Hwnd)     ; 内圆半透明(通透)
    gBubbleVisible := true
}

HideBubble() {
    global bubbleGui, bubbleCore, gBubbleVisible
    if (bubbleGui != "")
        try bubbleGui.Hide()
    if (bubbleCore != "")
        try bubbleCore.Hide()
    gBubbleVisible := false
}

; 气泡按下左键：几乎没动=点击→展开成工具条；动了=拖动(更新位置，球和条共用 gPosX/gPosY)
; 气泡按下左键：手动拖动(外圈+内球两层同时移动，始终贴合)；几乎没动=点击→展开成工具条。
; 不用系统 WM_NCLBUTTONDOWN 拖动，因为那只拖一个窗口、另一层会分家。
BubbleLDown(wParam, lParam, msg, hwnd) {
    global bubbleGui, bubbleCore, gBubbleVisible, gPosX, gPosY, IniPath, BubbleRing
    static busy := false
    if (bubbleGui = "" || !gBubbleVisible || busy)
        return
    MouseGetPos(&mx0, &my0, &winId)
    if (winId != bubbleGui.Hwnd && winId != bubbleCore.Hwnd)   ; 点外环或内圆都算
        return
    busy := true
    ; 用物理坐标(GetWindowRect + SetWindowPos)：鼠标是物理像素，若用 Gui.Move(逻辑坐标)在高 DPI 下会漂移
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", bubbleGui.Hwnd, "Ptr", rc)   ; 以外圈为基准
    gx0 := NumGet(rc, 0, "Int"), gy0 := NumGet(rc, 4, "Int")
    ringPx := Round(BubbleRing * (A_ScreenDPI / 96))
    SWP := 0x15   ; SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE
    moved := false
    while GetKeyState("LButton", "P") {
        MouseGetPos(&cx, &cy)
        dx := cx - mx0, dy := cy - my0
        if (!moved && (Abs(dx) > 2 || Abs(dy) > 2))
            moved := true
        if moved {   ; 两层一起移动，始终贴合
            DllCall("SetWindowPos", "Ptr", bubbleGui.Hwnd, "Ptr", 0, "Int", gx0 + dx, "Int", gy0 + dy, "Int", 0, "Int", 0, "UInt", SWP)
            DllCall("SetWindowPos", "Ptr", bubbleCore.Hwnd, "Ptr", 0, "Int", gx0 + dx + ringPx, "Int", gy0 + dy + ringPx, "Int", 0, "Int", 0, "UInt", SWP)
        }
        Sleep 10
    }
    busy := false
    if !moved {
        HideBubble()
        ShowBar()          ; 点一下 → 展开回工具条
    } else {
        bubbleGui.GetPos(&ax, &ay)
        gPosX := ax, gPosY := ay
        try IniWrite(gPosX, IniPath, "pos", "X")
        try IniWrite(gPosY, IniPath, "pos", "Y")
    }
}

; ============================== 面板构建 =====================================
Rebuild(*) {
    global MyGui, iconGui, Folder, Cols, PanelRows, ThumbW, ThumbH, LabelH, HeaderH, FontSize
    global gPosX, gPosY, gVisible, gLastSig, gItems, gScrollRow, gTotalRows, gRowsPerView
    global gFileCount, gCountText, gScanSig, snipGui, gSnipVisible, gSizeCache, tzGui, gTzVisible, gActivePanel
    Critical         ; 建面板期间不被定时器/热键打断，避免重入把半成品面板搅乱

    ; 打开缩略图面板时，先关掉其它面板（同一时间只显示一个）
    if (snipGui != "") {
        try snipGui.Hide()
        gSnipVisible := false
    }
    if (tzGui != "") {
        try tzGui.Hide()
        gTzVisible := false
    }

    if (MyGui != "") {
        try MyGui.Destroy()   ; 不再把面板位置存进 gPosX/gPosY（那是工具条位置）
        MyGui := ""
    }

    files := GetFiles()
    gLastSig := gScanSig            ; GetFiles 扫描时已算好签名，直接用，免二次扫描
    gFileCount := files.Length
    gItems := []
    gScrollRow := 0
    gRowsPerView := PanelRows
    gTotalRows := Ceil(Max(files.Length, 1) / Cols)

    rowH := ThumbH + LabelH + 8
    winW := 10 + Cols * ThumbW + (Cols - 1) * 10 + 10
    winH := HeaderH + PanelRows * rowH + 6

    MyGui := Gui("+AlwaysOnTop +ToolWindow", "截图面板 · 点图插入路径")
    MyGui.Opt("+E0x08000000")
    MyGui.BackColor := "FFFFFF"
    MyGui.SetFont("s" FontSize " w600 c202020", "Segoe UI")
    MyGui.MarginX := 10, MyGui.MarginY := 8
    MyGui.OnEvent("Close", OnPanelClose)
    MyGui.OnEvent("Escape", (*) => Minimize())

    b := MyGui.Add("Button", "x10 y8 w70 h26", "🔄 刷新")
    b.OnEvent("Click", Rebuild)
    fb := MyGui.Add("Button", "x84 y8 w82 h26", "📁 换目录")
    fb.OnEvent("Click", ChangeFolder)
    mb := MyGui.Add("Button", "x" (winW - 36) " y8 w26 h26", "—")
    mb.OnEvent("Click", (*) => Minimize())
    gCountText := MyGui.Add("Text", "x172 y13 w" (winW - 172 - 44) " Left", "")

    usedKeys := Map()
    if (files.Length = 0) {
        MyGui.Add("Text", "x10 y" HeaderH " w" (winW - 20), "文件夹里暂时没有图片：`n" Folder)
    } else {
        for i, f in files {
            idx := i - 1
            col := Mod(idx, Cols)
            row := idx // Cols
            sz := GetImageSize(f.path, f.mtime)
            fit := FitBox(sz.w, sz.h, ThumbW, ThumbH)
            item := { row: row, col: col, offX: fit.x, offY: fit.y }
            ; 整格可点区：铺满格子、放在最底层(先加=z序在下)。图片按比例缩小后四周有留白，
            ; 点在留白上也能命中这个可点区 → 修"有时点了插不进去"。
            hit := MyGui.Add("Text", "x0 y0 w" ThumbW " h" ThumbH " 0x100")
            hit.OnEvent("Click", InsertPath.Bind(f.path))
            hit.OnEvent("ContextMenu", ShowPreview.Bind(f.path))   ; 右键 → 看原图
            item.hit := hit
            hbm := GetScaledBitmap(f.path, f.mtime, fit.w, fit.h)
            if hbm {
                usedKeys[f.path "|" f.mtime "|" fit.w "|" fit.h] := true
                ; HBITMAP:* 里的 * = 复用缓存位图、控件销毁时不释放它(由 PrunePicCache 统一管)
                pic := MyGui.Add("Picture", "x0 y0 w" fit.w " h" fit.h, "HBITMAP:*" hbm)
                pic.OnEvent("Click", InsertPath.Bind(f.path))
                pic.OnEvent("ContextMenu", ShowPreview.Bind(f.path))   ; 右键 → 看原图
                item.pic := pic
            } else {
                ph := MyGui.Add("Text", "x0 y0 w" ThumbW " h" ThumbH " Border Center 0x200", "(读不出)")
                ph.OnEvent("Click", InsertPath.Bind(f.path))
                item.pic := ph
                item.offX := 0, item.offY := 0
            }
            lbl := MyGui.Add("Text", "x0 y0 w" ThumbW " Center 0x100", ShortLabel(f.name))
            lbl.OnEvent("Click", InsertPath.Bind(f.path))
            lbl.OnEvent("ContextMenu", ShowPreview.Bind(f.path))   ; 右键 → 看原图
            item.lbl := lbl
            gItems.Push(item)
        }
    }
    PrunePicCache(usedKeys)
    ; 回收尺寸缓存：只留当前这批图，避免长期运行 gSizeCache 无限增长
    sizeKeep := Map()
    for f in files
        sizeKeep[f.path "|" f.mtime] := true
    for k in gSizeCache.Clone()
        if !sizeKeep.Has(k)
            gSizeCache.Delete(k)

    sx := 0, sy := 0
    PlacePanelByBar(&sx, &sy, winW, winH)   ; 贴工具条下方(不够翻上)
    ApplyScroll()
    MyGui.Show("x" sx " y" sy " w" winW " h" winH " NoActivate")
    gVisible := true
    gActivePanel := "thumb"
    ShowBar()      ; 工具条常驻：确保它还显示着
}

ApplyScroll() {
    global gItems, gScrollRow, gRowsPerView, gTotalRows, gFileCount, gCountText
    global ThumbW, ThumbH, LabelH, HeaderH, Cols
    rowH := ThumbH + LabelH + 8
    for it in gItems {
        dr := it.row - gScrollRow
        if (dr < 0 || dr >= gRowsPerView) {
            it.hit.Visible := false
            it.pic.Visible := false
            it.lbl.Visible := false
        } else {
            cellX := 10 + it.col * (ThumbW + 10)
            cellY := HeaderH + dr * rowH
            it.hit.Move(cellX, cellY)
            it.pic.Move(cellX + it.offX, cellY + it.offY)
            it.lbl.Move(cellX, cellY + ThumbH + 1)
            it.hit.Visible := true
            it.pic.Visible := true
            it.lbl.Visible := true
        }
    }
    if (gCountText != "") {
        if (gTotalRows > gRowsPerView) {
            fromRow := gScrollRow + 1
            toRow := Min(gScrollRow + gRowsPerView, gTotalRows)
            gCountText.Text := "共 " gFileCount " 张 · 滚轮翻 · 行 " fromRow "-" toRow "/" gTotalRows
        } else {
            gCountText.Text := "共 " gFileCount " 张 · 最新在左上"
        }
    }
}

OnPanelClose(*) {
    Minimize()   ; 点面板关闭按钮 = 收起面板(工具条留着)，统一清 gActivePanel
}

TogglePanel(*) {
    global gActivePanel
    if (gActivePanel != "")
        Minimize()        ; 有面板开着 → 收起(工具条留着)
    else
        Rebuild()         ; 没面板 → 展开缩略图
}

; ============================== 插入路径 =====================================
InsertPath(path, *) {
    global SendSpace, WrapQuotes
    text := WrapQuotes ? ('"' path '"') : path
    if SendSpace
        text .= " "
    InsertAndMinimize(text)
}

; ============================== 右键看原图 ===================================
; 右键缩略图 → 在鼠标所在的那块屏幕居中显示原图（无边框、置顶、不抢焦点）。
; 预览开着时：左键点图=插入路径；左键按住拖=移动原图位置；右键点图=关掉预览。
; 鼠标移动(不按键)、键盘都不管。左键的"点击 vs 拖动"由 PreviewLDown 区分。
ShowPreview(path, *) {
    global previewGui, gPreviewPath, PreviewMaxRatio
    ClosePreview()                       ; 同一时间只留一个预览
    if !FileExist(path)
        return
    mtime := ""
    try mtime := FileGetTime(path, "M")
    sz := GetImageSize(path, mtime)
    MouseGetPos(&mx, &my)
    GetMonitorAt(mx, my, &monL, &monT, &monR, &monB)   ; 鼠标所在屏幕
    availW := Round((monR - monL) * PreviewMaxRatio)
    availH := Round((monB - monT) * PreviewMaxRatio)
    fit := FitBox(sz.w, sz.h, availW, availH)           ; 按原比例缩进屏幕(不放大小图)
    winW := Max(1, fit.w), winH := Max(1, fit.h)
    if (sz.w <= 0 || sz.h <= 0) {                       ; 读不出尺寸就给个兜底大小
        winW := Min(availW, 800), winH := Min(availH, 600)
    }
    winX := monL + ((monR - monL) - winW) // 2
    winY := monT + ((monB - monT) - winH) // 2

    previewGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "原图预览")
    previewGui.Opt("+E0x08000000")                      ; WS_EX_NOACTIVATE：不抢焦点
    previewGui.BackColor := "202020"
    previewGui.MarginX := 0, previewGui.MarginY := 0
    gPreviewPath := path
    pic := previewGui.Add("Picture", "x0 y0 w" winW " h" winH, path)   ; Picture 控件自动解码+缩放
    pic.OnEvent("ContextMenu", (*) => ClosePreview())   ; 右键 → 关掉预览（左键交给 PreviewLDown）
    previewGui.Show("x" winX " y" winY " w" winW " h" winH " NoActivate")
    Topmost(previewGui.Hwnd)
}

; 预览窗按下左键：几乎没动=点击→插入这张图的路径；动了=按住拖动，移动原图窗口位置。
; 拖动用物理坐标(GetWindowRect + SetWindowPos)，避开高 DPI 下 Gui.Move 逻辑坐标漂移（同工具球做法）。
PreviewLDown(wParam, lParam, msg, hwnd) {
    global previewGui, gPreviewPath
    static busy := false
    if (previewGui = "" || busy)
        return
    MouseGetPos(&mx0, &my0, &winId)
    if (winId != previewGui.Hwnd)          ; 只处理落在预览窗上的左键
        return
    busy := true
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", previewGui.Hwnd, "Ptr", rc)
    gx0 := NumGet(rc, 0, "Int"), gy0 := NumGet(rc, 4, "Int")
    SWP := 0x15   ; SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE
    moved := false
    while GetKeyState("LButton", "P") {
        MouseGetPos(&cx, &cy)
        dx := cx - mx0, dy := cy - my0
        if (!moved && (Abs(dx) > 4 || Abs(dy) > 4))
            moved := true
        if moved                            ; 子控件(图片)随顶层窗一起移，只挪顶层窗即可
            DllCall("SetWindowPos", "Ptr", previewGui.Hwnd, "Ptr", 0, "Int", gx0 + dx, "Int", gy0 + dy, "Int", 0, "Int", 0, "UInt", SWP)
        Sleep 10
    }
    busy := false
    if !moved {                             ; 几乎没动 = 点击 → 插入这张图的路径（先关预览再走插入+收起）
        path := gPreviewPath
        ClosePreview()
        InsertPath(path)
    }
    ; 拖动过：预览就停在新位置，不记 ini（临时窗，下次右键按鼠标所在屏重新居中）
}

ClosePreview() {
    global previewGui
    if (previewGui != "") {
        try previewGui.Destroy()
        previewGui := ""
    }
}

; 找包含点 (px,py) 的那块屏幕(整屏范围)；找不到就退回主屏
GetMonitorAt(px, py, &l, &t, &r, &b) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if (px >= ml && px < mr && py >= mt && py < mb) {
            l := ml, t := mt, r := mr, b := mb
            return
        }
    }
    MonitorGet(MonitorGetPrimary(), &l, &t, &r, &b)
}

; 统一的"插入即收起"流程（缩略图/片段共用）：
;   1) 激活目标窗口(=展开面板时记下的"工具正下方"那个窗口，通常是 Claude 终端)；
;   2) 把文字打进去；
;   3) 立即收回小工具条(仍保持最顶层)。
; 面板/工具条平时 NoActivate 不抢焦点；只有这一刻用户主动点了图片/片段，才激活下层窗口。
InsertAndMinimize(text) {
    global gTargetWin, MyGui, snipGui, iconGui
    target := gTargetWin
    if !target {                       ; 兜底：没记到目标就用当前活动窗口(排除本工具三个窗口)
        a := WinActive("A")
        if (a && a != (MyGui != "" ? MyGui.Hwnd : 0)
              && a != (snipGui != "" ? snipGui.Hwnd : 0)
              && a != (iconGui != "" ? iconGui.Hwnd : 0))
            target := a
    }
    if target {
        try WinActivate("ahk_id " target)
        try WinWaitActive("ahk_id " target, , 0.4)   ; 等它真正到前台，避免键发丢
    }
    Sleep 20
    SendText(text)
    Minimize()                         ; 收回小工具条(KeepOnTop 会让它继续保持最顶层)
}

TrackActive() {
    global MyGui, snipGui, tzGui, iconGui, gTargetWin, gEditing, bubbleGui
    if gEditing            ; 编辑对话框是本工具窗口，别把它记成插入目标
        return
    a := WinActive("A")
    if !a
        return
    if (MyGui != "" && a = MyGui.Hwnd)
        return
    if (snipGui != "" && a = snipGui.Hwnd)
        return
    if (tzGui != "" && a = tzGui.Hwnd)
        return
    if (iconGui != "" && a = iconGui.Hwnd)
        return
    if (bubbleGui != "" && a = bubbleGui.Hwnd)
        return
    gTargetWin := a
}

; 把当前可见的那个窗口(缩略图面板 / 片段面板 / 小工具条)重新塞回"置顶层"最上面。
; 只有 +AlwaysOnTop 建窗口时设一次是不够的：本工具的窗口都 NoActivate、从不被激活，
; 而多个置顶窗口之间按"最近激活"排序 → 别的置顶窗口一出现就会盖到本工具上面。
; 这里用 SetWindowPos(HWND_TOPMOST) + SWP_NOACTIVATE 定期把它顶回顶部：不抢焦点、不移位、不改大小。
KeepOnTop() {
    global MyGui, snipGui, tzGui, iconGui, gVisible, gSnipVisible, gTzVisible, gEditing, bubbleGui, bubbleCore, gBubbleVisible, previewGui
    if gEditing            ; 编辑对话框开着时别顶，免得盖住对话框
        return
    ; 工具条常驻：先顶工具条
    if (iconGui != "" && DllCall("IsWindowVisible", "Ptr", iconGui.Hwnd))
        Topmost(iconGui.Hwnd)
    if (gBubbleVisible && bubbleGui != "") {   ; 气泡两层都保持置顶(先外环、再内圆，内圆在上)
        Topmost(bubbleGui.Hwnd)
        if (bubbleCore != "")
            Topmost(bubbleCore.Hwnd)
    }
    ; 再顶当前展开的面板（放到工具条之上）
    if (gVisible && MyGui != "")
        Topmost(MyGui.Hwnd)
    else if (gSnipVisible && snipGui != "")
        Topmost(snipGui.Hwnd)
    else if (gTzVisible && tzGui != "")
        Topmost(tzGui.Hwnd)
    if (previewGui != "")   ; 原图预览最优先：放在最后顶，压在面板/工具条之上
        Topmost(previewGui.Hwnd)
}

RefreshIfChanged() {
    global gVisible, gLastSig
    if !gVisible
        return
    if (FolderSignature() != gLastSig)   ; 轻量扫描，变了才重建
        Rebuild()
}

; ============================== 最小化图标 ===================================
; 收起：只隐藏当前面板，工具条常驻不动（点当前工具图标 / 面板的—按钮 / Esc 都走这里）
Minimize(*) {
    global MyGui, snipGui, tzGui, gVisible, gSnipVisible, gTzVisible, gActivePanel, gArmedMinimize
    gArmedMinimize := false
    ClosePreview()     ; 收起/切换面板时，顺手关掉可能还开着的原图预览
    if (MyGui != "")
        try MyGui.Hide()
    if (snipGui != "")
        try snipGui.Hide()
    if (tzGui != "")
        try tzGui.Hide()
    gVisible := false
    gSnipVisible := false
    gTzVisible := false
    gActivePanel := ""
    ShowBar()      ; 工具条常驻：确保它还显示着
}

; 小工具条：一个圆角深色容器，横排放若干小图标，图标之间留间隔、四周留白。
; 以后要加工具，只往下面 gTools 里加一项 {icon, tip, action} 即可，尺寸会自动算。
CreateIcon() {
    global iconGui, iconBtnHwnd, gTools, gIconCtrls, gIconW, gIconH
    global IconCell, IconRowH, IconGap, IconPad, IconPadV, IconRadius, IconNudgeUp, IconBg, IconColor, IconFont

    ; 图标用 Segoe Fluent Icons 里的字形（Chr(码位)），单色线条、天生居中。
    ; 以后加工具就往下面加一项 {icon, tip, action}，容器宽度和点击分派都会自动跟上。
    gTools := [
        { icon: Chr(0xE722), tip: "展开截图面板", action: ExpandFromIcon, panel: "thumb" }   ; E722=相机
      , { icon: Chr(0xE70B), tip: "命令/文字片段", action: OpenSnippets, panel: "snip" }       ; E70B=便签
      , { icon: Chr(0xE774), tip: "时间戳转时区", action: OpenTimeConverter, panel: "tz" }      ; E774=世界/地球
    ]
    n := gTools.Length
    gIconW := IconPad * 2 + n * IconCell + (n - 1) * IconGap
    gIconH := IconPadV * 2 + IconRowH

    iconGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x08000000", "截图面板图标")
    iconGui.MarginX := 0, iconGui.MarginY := 0
    iconGui.BackColor := IconBg
    iconGui.SetFont("s" Round(IconCell * 0.52) " c" IconColor, IconFont)

    gIconCtrls := []
    for i, tool in gTools {
        cx := IconPad + (i - 1) * (IconCell + IconGap)
        ; 0x100=SS_NOTIFY(静态文字能收点击) 0x200=SS_CENTERIMAGE(垂直居中) Center(水平居中)
        c := iconGui.Add("Text"
            , "x" cx " y" (IconPadV - IconNudgeUp) " w" IconCell " h" IconRowH " Center 0x100 0x200 BackgroundTrans"
            , tool.icon)
        gIconCtrls.Push(c)
    }
    iconBtnHwnd := gIconCtrls.Length ? gIconCtrls[1].Hwnd : 0
}

; 把窗口裁成圆角（CreateRoundRectRgn + SetWindowRgn）。
; 关键：SetWindowRgn 用物理像素。高 DPI 下若按逻辑像素算，区域会比窗口小 → 右边图标被裁半个。
; 所以直接用 GetWindowRect 取窗口真实像素尺寸来建区域，圆角半径按 DPI 系数缩放。
RoundWindow(hwnd, r) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc.Ptr)
    w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")    ; 物理宽
    h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")   ; 物理高
    rr := Round(r * 2 * (A_ScreenDPI / 96))
    hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1
        , "Int", rr, "Int", rr, "Ptr")
    DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", hRgn, "Int", 1)   ; 系统接管并释放该区域
}

; 把窗口裁成"圆环"（外圆挖掉内圆）——给气泡的外圈描边用；ringPx 是环宽(物理像素)
RingWindow(hwnd, ringPx) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc.Ptr)
    w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    hOuter := DllCall("CreateEllipticRgn", "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1, "Ptr")
    hInner := DllCall("CreateEllipticRgn", "Int", ringPx, "Int", ringPx, "Int", w + 1 - ringPx, "Int", h + 1 - ringPx, "Ptr")
    DllCall("CombineRgn", "Ptr", hOuter, "Ptr", hOuter, "Ptr", hInner, "Int", 4)   ; RGN_DIFF=4：外圆减内圆=环
    DllCall("DeleteObject", "Ptr", hInner)
    DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", hOuter, "Int", 1)
}

; 小图标按下左键：用系统原生拖动(DPI 安全、跟手)。松开后按位移判断：
;   几乎没动 = 当作点击 → 展开；动了 = 记住新位置。
IconLDown(wParam, lParam, msg, hwnd) {
    global iconGui, gPosX, gPosY, IniPath, gTools, IconCell, IconGap, IconPad, gActivePanel
    static busy := false
    if (iconGui = "" || busy)
        return
    MouseGetPos(&mx, &my, &winId)
    if (winId != iconGui.Hwnd)
        return
    busy := true
    iconGui.GetPos(&bx, &by)
    ; 按下时算出点在第几个图标上。MouseGetPos 是物理像素，图标布局是逻辑像素，
    ; 用窗口真实左边界(物理) + DPI 系数把逻辑格子换算成物理，避免缩放下点错图标。
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", iconGui.Hwnd, "Ptr", rc.Ptr)
    winLeft := NumGet(rc, 0, "Int")
    s := A_ScreenDPI / 96
    relX := mx - winLeft
    hitIdx := 0
    Loop gTools.Length {
        cellX := (IconPad + (A_Index - 1) * (IconCell + IconGap)) * s
        if (relX >= cellX && relX <= cellX + IconCell * s) {
            hitIdx := A_Index
            break
        }
    }
    ; WM_NCLBUTTONDOWN + HTCAPTION：交给系统做窗口拖动，阻塞到鼠标松开
    try SendMessage(0xA1, 2, 0, , "ahk_id " iconGui.Hwnd)
    iconGui.GetPos(&ax, &ay)
    busy := false
    if (Abs(ax - bx) <= 2 && Abs(ay - by) <= 2) {
        ; 没挪动 = 点击（点在图标间隔/留白上则忽略）
        if hitIdx {
            tool := gTools[hitIdx]
            if (gActivePanel = tool.panel)
                Minimize()               ; 再点当前已展开工具的图标 → 收起面板(工具条留着)
            else
                tool.action.Call()       ; 点别的工具 → 切换/展开
        }
    } else {
        gPosX := ax, gPosY := ay
        try IniWrite(gPosX, IniPath, "pos", "X")
        try IniWrite(gPosY, IniPath, "pos", "Y")
        RepositionActivePanel()          ; 工具条挪了，展开着的面板跟过去
    }
}

ExpandFromIcon() {
    global gArmedMinimize
    gArmedMinimize := false
    Rebuild()   ; 工具条常驻：直接重建缩略图面板(贴到工具条下方)；插入目标靠 gTargetWin 兜底
}

; 从图标点开某个面板前的公用准备：
;   1) 把面板要开的位置定到图标当前位置（gPosX/gPosY）；
;   2) 藏起图标；
;   3) 若开了 ActivateWindowUnderIcon，激活图标正下方的窗口（通常是压在下面的 Claude 终端），
;      这样面板(NoActivate)开出来后点插入，就插到那个窗口、不会跑偏。
; 只有图标当前可见时才动作（面板重建时的自调用会 no-op，不影响面板现有位置）。
PrepareFromIcon() {
    global iconGui, gPosX, gPosY, gTargetWin, ActivateWindowUnderIcon
    if (iconGui = "" || !DllCall("IsWindowVisible", "Ptr", iconGui.Hwnd))
        return
    iconGui.GetPos(&icx, &icy, &icw, &ich)
    gPosX := icx, gPosY := icy
    iconGui.Hide()
    if ActivateWindowUnderIcon {
        Sleep 10
        cx := icx + icw // 2, cy := icy + ich // 2
        pt := (cx & 0xFFFFFFFF) | ((cy & 0xFFFFFFFF) << 32)
        hwnd := DllCall("WindowFromPoint", "Int64", pt, "Ptr")
        if hwnd {
            root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")   ; GA_ROOT=2 取顶层窗口
            if root {
                try WinActivate("ahk_id " root)
                gTargetWin := root
            }
        }
    }
}

; ============================== 命令/文字片段 ================================
; 片段存到脚本同目录的文本文件，一行一条，长期保留。
SnipFile() => A_ScriptDir "\截图面板-命令片段.txt"

; 文件格式（UTF-8）：每条片段 = 别名 + US(0x1F) + 命令内容，条与条之间用 RS(0x1E) 分隔。
; 命令内容可含换行(多行命令)；这两个控制字符正常内容里不会出现，所以能安全分隔。
; 兼容旧格式：老文件是"一行一条纯命令"(不含这两个字符)，按行读进来、别名留空。
LoadSnips() {
    global gSnips
    gSnips := []
    path := SnipFile()
    if !FileExist(path)
        return
    content := FileRead(path, "UTF-8")
    if (content = "")
        return
    if (InStr(content, Chr(0x1E)) || InStr(content, Chr(0x1F))) {
        ; 新格式每条 = alias US cmd US mode US sid（后两个字段旧文件没有，缺省=text/空）
        for rec in StrSplit(content, Chr(0x1E)) {
            if (rec = "")
                continue
            parts := StrSplit(rec, Chr(0x1F))
            alias := (parts.Length >= 1) ? parts[1] : ""
            cmd := (parts.Length >= 2) ? parts[2] : ""
            mode := (parts.Length >= 3 && parts[3] = "script") ? "script" : "text"
            sid := (parts.Length >= 4) ? parts[4] : ""
            if (Trim(alias) = "" && Trim(cmd, " `t`r`n") = "")
                continue
            obj := { alias: alias, cmd: cmd, mode: mode }
            if (sid != "")
                obj.sid := Integer(sid)
            gSnips.Push(obj)
        }
    } else {
        ; 最老格式：一行一条纯命令，别名留空、按文本模式
        for line in StrSplit(content, "`n", "`r")
            if (Trim(line) != "")
                gSnips.Push({ alias: "", cmd: line, mode: "text" })
    }
}

; 脚本模式片段的存放：每条一个 .ps1，文件名 cmd_<sid>.ps1（sid 是分配后不变的编号）
ScriptSubDir() => A_ScriptDir "\命令脚本"
ScriptPath(sid) => ScriptSubDir() "\cmd_" sid ".ps1"

; 写单个脚本文件。用带 BOM 的 UTF-8：PowerShell 5.1 靠 BOM 认 UTF-8，否则中文会乱码
WriteScriptFile(sid, cmd) {
    try {
        f := FileOpen(ScriptPath(sid), "w", "UTF-8")
        f.Write(cmd)
        f.Close()
    }
}

; 某条片段"点一下要插入到终端的内容"：脚本模式=调用命令(回车即执行)，文本模式=命令原文
SnipInsertText(s) {
    if (s.mode = "script" && s.HasOwnProp("sid") && s.sid != "")
        return "& '" ScriptPath(s.sid) "'"
    return s.cmd
}

SaveSnips() {
    global gSnips, IniPath
    ; 1) 脚本模式片段：没编号的分配一个、写出 .ps1、记下在用的编号
    dir := ScriptSubDir()
    try DirCreate(dir)
    usedSids := Map()
    nextSid := Integer(IniRead(IniPath, "snip", "nextSid", 1))
    for s in gSnips {
        if (s.mode = "script") {
            if (!s.HasOwnProp("sid") || s.sid = "" || s.sid = 0) {
                s.sid := nextSid
                nextSid += 1
            }
            usedSids[s.sid] := true
            WriteScriptFile(s.sid, s.cmd)
        }
    }
    try IniWrite(nextSid, IniPath, "snip", "nextSid")
    ; 2) 清理：删掉目录里已经没人用的 cmd_*.ps1（片段被删 / 改回文本模式后留下的）
    Loop Files, dir "\cmd_*.ps1" {
        if RegExMatch(A_LoopFileName, "^cmd_(\d+)\.ps1$", &m)
            if !usedSids.Has(Integer(m[1]))
                try FileDelete(A_LoopFileFullPath)
    }
    ; 3) 写数据文件：alias US cmd US mode US sid，条间用 RS
    text := ""
    for s in gSnips {
        sid := (s.HasOwnProp("sid") && s.sid != "") ? s.sid : ""
        text .= s.alias Chr(0x1F) s.cmd Chr(0x1F) s.mode Chr(0x1F) sid Chr(0x1E)
    }
    try {
        f := FileOpen(SnipFile(), "w", "UTF-8")
        f.Write(text)
        f.Close()
    }
}

; 取命令的第一行（面板上做预览用）
FirstLine(cmd) {
    arr := StrSplit(cmd, "`n", "`r")
    return arr.Length ? arr[1] : ""
}

; 命令一共几行（去掉尾部空行后计数，用于"⋯还有 N 行"提示）
CmdLineCount(cmd) {
    trimmed := RegExReplace(cmd, "[\r\n]+$", "")
    if (trimmed = "")
        return 0
    return StrSplit(trimmed, "`n", "`r").Length
}

; 卡片第一行(粗)：有别名显示别名；没别名显示命令首行
SnipTitle(s) {
    return (Trim(s.alias) != "") ? s.alias : FirstLine(s.cmd)
}

; 卡片第二行(灰)：有别名→命令首行(多行再标"⋯+N 行")；没别名→只在多行时标"⋯还有 N 行"
SnipSub(s) {
    n := CmdLineCount(s.cmd)
    if (s.mode = "script")
        return "▶ 脚本 · " n " 行 · 插入后回车执行"
    if (Trim(s.alias) != "") {
        sub := FirstLine(s.cmd)
        if (n > 1)
            sub .= "   ⋯ +" (n - 1) " 行"
        return sub
    }
    return (n > 1) ? ("⋯ 还有 " (n - 1) " 行") : ""
}

; 面板文字截断 + 转义：太长截断加省略号；& 要写成 && 否则被当快捷键下划线
SnipShow(text, maxLen := 42) {
    show := (StrLen(text) > maxLen) ? SubStr(text, 1, maxLen) "…" : text
    return StrReplace(show, "&", "&&")
}

OpenSnippets(*) {
    global snipGui, MyGui, tzGui, iconGui, gSnips, gSnipVisible, gVisible, gTzVisible, gActivePanel, gSnipCtrlIdx, gSnipScroll, SnipMaxRows
    Critical         ; 建面板期间不被定时器/热键打断，避免重入
    gSnipCtrlIdx := Map()   ; 面板重建：旧控件 hwnd 全失效，重置映射

    if (MyGui != "") {         ; 关掉缩略图面板（同时只显示一个）
        try MyGui.Hide()
        gVisible := false
    }
    if (tzGui != "") {         ; 关掉时间面板
        try tzGui.Hide()
        gTzVisible := false
    }
    if (snipGui != "") {
        try snipGui.Destroy()
        snipGui := ""
    }

    padX := 10, gap := 8, headerH := 42, cardH := 46
    insW := 300, btnW := 30, arrowW := 16
    winW := padX * 2 + insW + gap + btnW + gap + btnW + 4 + arrowW + 10   ; 末尾 10 给滚动条
    rows := gSnips.Length
    visRows := Min(Max(rows, 1), SnipMaxRows)                  ; 最多显示这么多行
    gSnipScroll := Max(0, Min(gSnipScroll, Max(0, rows - visRows)))   ; 夹紧滚动偏移到有效范围
    winH := headerH + visRows * (cardH + gap) + 8

    snipGui := Gui("+AlwaysOnTop +ToolWindow", "命令片段 · 点击插入")
    snipGui.Opt("+E0x08000000")      ; NoActivate：点它不抢焦点，点片段就能插进终端
    snipGui.BackColor := "FFFFFF"
    snipGui.SetFont("s10 c202020", "Segoe UI")
    snipGui.MarginX := padX, snipGui.MarginY := 8
    snipGui.OnEvent("Close", (*) => Minimize())
    snipGui.OnEvent("Escape", (*) => Minimize())

    addb := snipGui.Add("Button", "x" padX " y8 w120 h26", "＋ 添加片段")
    addb.OnEvent("Click", (*) => AddSnip())
    mb := snipGui.Add("Button", "x" (winW - 36) " y8 w26 h26", "—")
    mb.OnEvent("Click", (*) => Minimize())

    if (rows = 0) {
        snipGui.Add("Text", "x" padX " y" headerH " w" (winW - padX * 2)
            , "还没有片段。点「＋ 添加片段」新增一条命令或文字。")
    } else {
        arrowX := padX + insW + gap + btnW + gap + btnW + 4
        Loop visRows {
            vis := A_Index
            idx := gSnipScroll + vis    ; 真实序号(算上滚动偏移)
            if (idx > rows)
                break
            s := gSnips[idx]
            cardY := headerH + (vis - 1) * (cardH + gap)
            ; 卡片三个控件(底/一行/二行)都记 hwnd→真实序号；点击插入 / 上下拖排序都由 SnipLDown 统一处理
            bg := snipGui.Add("Text", "x" padX " y" cardY " w" insW " h" cardH " 0x100 BackgroundF2F3F5")
            gSnipCtrlIdx[bg.Hwnd] := idx
            ; 第一行(粗)：别名，或没别名时的命令首行
            t1 := snipGui.Add("Text", "x" (padX + 8) " y" (cardY + 6) " w" (insW - 16) " 0x100 BackgroundTrans"
                , SnipShow(SnipTitle(s), 40))
            t1.SetFont("w600 c202020")
            gSnipCtrlIdx[t1.Hwnd] := idx
            ; 第二行(灰)：命令首行预览 / 多行提示 / 脚本标记
            sub := SnipSub(s)
            if (sub != "") {
                t2 := snipGui.Add("Text", "x" (padX + 8) " y" (cardY + 26) " w" (insW - 16) " 0x100 BackgroundTrans"
                    , SnipShow(sub, 44))
                t2.SetFont("s9 c8A8A8A")
                gSnipCtrlIdx[t2.Hwnd] := idx
            }
            ; ✎ 编辑 / ✕ 删除（右侧，垂直居中）
            eb := snipGui.Add("Button", "x" (padX + insW + gap) " y" (cardY + 9) " w" btnW " h28", "✎")
            eb.OnEvent("Click", EditSnip.Bind(idx))
            db := snipGui.Add("Button", "x" (padX + insW + gap + btnW + gap) " y" (cardY + 9) " w" btnW " h28", "✕")
            db.OnEvent("Click", DeleteSnip.Bind(idx))
            ; ▲▼ 低调小灰箭头：上下移一位（拖动之外的备选，视觉刻意做淡、不抢眼）
            up := snipGui.Add("Text", "x" arrowX " y" (cardY + 4) " w" arrowW " h18 Center 0x100", "▲")
            up.SetFont("s7 cC2C6CC")
            up.OnEvent("Click", MoveSnip.Bind(idx, idx - 1))
            dn := snipGui.Add("Text", "x" arrowX " y" (cardY + 24) " w" arrowW " h18 Center 0x100", "▼")
            dn.SetFont("s7 cC2C6CC")
            dn.OnEvent("Click", MoveSnip.Bind(idx, idx + 1))
        }
        ; 右侧滚动条(仅当条数超过可视行)：灰槽 + 深灰滑块，指示位置；滚轮翻
        if (rows > visRows) {
            trackH := visRows * (cardH + gap)
            sbX := winW - 8
            snipGui.Add("Text", "x" sbX " y" headerH " w6 h" trackH " BackgroundE8EAED", "")
            thumbH := Max(20, Round(trackH * visRows / rows))
            thumbY := headerH + Round((trackH - thumbH) * gSnipScroll / (rows - visRows))
            snipGui.Add("Text", "x" sbX " y" thumbY " w6 h" thumbH " BackgroundAEB4BC", "")
        }
    }

    sx := 0, sy := 0
    PlacePanelByBar(&sx, &sy, winW, winH)   ; 贴工具条下方
    snipGui.Show("x" sx " y" sy " w" winW " h" winH " NoActivate")
    gSnipVisible := true
    gActivePanel := "snip"
    ShowBar()      ; 工具条常驻
}

HideSnips() {
    global snipGui, gSnipVisible
    try snipGui.Hide()
    gSnipVisible := false
}

AddSnip() {
    ShowSnipEditor("添加片段", "", "", "text", AddSnipDone)
}
; 对话框点"确定"后的回调
AddSnipDone(alias, cmd, mode) {
    global gSnips, gSnipScroll
    if (Trim(alias) = "" && Trim(cmd, " `t`r`n") = "")   ; 别名和命令都空 → 不加
        return
    gSnips.Push({ alias: Trim(alias), cmd: RTrimNewlines(cmd), mode: mode })
    gSnipScroll := gSnips.Length   ; 滚到底，能看到刚加的这条(OpenSnippets 会夹紧)
    SaveSnips()
    OpenSnippets()
}

EditSnip(i, *) {
    global gSnips
    if (i < 1 || i > gSnips.Length)
        return
    s := gSnips[i]
    ShowSnipEditor("编辑片段", s.alias, s.cmd, s.mode, EditSnipDone.Bind(i, s))
}
EditSnipDone(i, s, alias, cmd, mode) {
    global gSnips
    if (i < 1 || i > gSnips.Length)
        return
    if (Trim(alias) = "" && Trim(cmd, " `t`r`n") = "")   ; 都清空当作不改（要删请用 ✕）
        return
    newObj := { alias: Trim(alias), cmd: RTrimNewlines(cmd), mode: mode }
    ; 脚本→脚本：沿用原来的文件编号(复用同一个 .ps1)；其它情况让 SaveSnips 重新分配/清理
    if (mode = "script" && s.mode = "script" && s.HasOwnProp("sid"))
        newObj.sid := s.sid
    gSnips[i] := newObj
    SaveSnips()
    OpenSnippets()
}

; 去掉命令末尾多余换行：避免最后一行带着回车插进终端、直接把最后一条命令执行掉
RTrimNewlines(cmd) => RegExReplace(cmd, "[\r\n]+$", "")

; 自建的"添加/编辑片段"对话框：别名(单行) + 命令(多行) + 确定/取消，返回 {ok, alias, cmd}。
; 不用 InputBox 的原因：AHK 的 InputBox 是单行输入框，没法输入多行命令。
; 开着时 gEditing=true，让 TrackActive 不把它记成插入目标、KeepOnTop 不拿面板盖住它。
; "添加/编辑片段"对话框：事件驱动、不阻塞。
; 为什么不用 WinWaitClose 阻塞：那样会卡在触发它的事件回调里，切到别的窗口后消息处理被拖住，
;   对话框能打字但按钮/关闭/最小化都没反应(卡死)。改成靠回调驱动，所有按钮都能正常响应。
; 用户点"确定" → 调 onDone(alias, cmd, mode)；取消/关闭/Esc → 只关窗口。
ShowSnipEditor(title, alias0, cmd0, mode0, onDone) {
    global gEditing
    gEditing := true
    dlg := Gui("+AlwaysOnTop +MinimizeBox -MaximizeBox -Resize", title)   ; 普通窗口(能最小化/关闭)，不用 ToolWindow
    dlg.SetFont("s10", "Segoe UI")
    dlg.MarginX := 12, dlg.MarginY := 10
    dlg.Add("Text", , "别名（可选，只用于面板上显示/识别）：")
    eAlias := dlg.Add("Edit", "w460", alias0)
    dlg.Add("Text", "y+10", "命令内容（可多行）：")
    eCmd := dlg.Add("Edit", "w460 r9 +Multi +WantReturn", cmd0)
    dlg.Add("Text", "xm y+10 Section", "插入方式：")
    rbText := dlg.Add("Radio", "ys", "直接插入文本")
    rbScript := dlg.Add("Radio", "ys", "存成 .ps1，插入后回车执行（适合多行命令）")
    (mode0 = "script") ? (rbScript.Value := 1) : (rbText.Value := 1)
    okb := dlg.Add("Button", "xm y+14 w110 Default", "确定")
    cancelb := dlg.Add("Button", "x+10 w110", "取消")

    onOk(*) {
        global gEditing
        alias := eAlias.Value
        cmd := eCmd.Value
        mode := rbScript.Value ? "script" : "text"
        gEditing := false
        try dlg.Destroy()
        onDone(alias, cmd, mode)
    }
    onCancel(*) {
        global gEditing
        gEditing := false
        try dlg.Destroy()
    }
    okb.OnEvent("Click", onOk)
    cancelb.OnEvent("Click", onCancel)
    dlg.OnEvent("Close", onCancel)
    dlg.OnEvent("Escape", onCancel)
    dlg.Show()
}

DeleteSnip(i, *) {
    global gSnips
    if (i < 1 || i > gSnips.Length)
        return
    gSnips.RemoveAt(i)
    SaveSnips()
    OpenSnippets()
}

; 片段卡片按下左键：几乎没动=点击插入；上下拖动=排序。用控件命中判断落点(避开标题栏/DPI 坐标换算)。
SnipLDown(wParam, lParam, msg, hwnd) {
    global snipGui, gSnips, gSnipVisible, gSnipCtrlIdx
    static busy := false
    if (snipGui = "" || !gSnipVisible || busy)
        return
    MouseGetPos(&mx, &my, &winId, &ctrl, 2)   ; flag=2：ctrl 返回控件 hwnd
    if (winId != snipGui.Hwnd || !gSnipCtrlIdx.Has(ctrl))
        return                                ; 没点在卡片上(按钮/空白) → 不管，交给按钮
    srcIdx := gSnipCtrlIdx[ctrl]
    busy := true
    startY := my, moved := false
    while GetKeyState("LButton", "P") {       ; 跟到松手；轻量循环+Sleep 不会卡死
        MouseGetPos(, &cy)
        if (Abs(cy - startY) > 6)
            moved := true
        Sleep 10
    }
    MouseGetPos(, , &upWin, &upCtrl, 2)        ; 松手落点
    busy := false
    if !moved {                                ; 没拖动 = 点击 → 插入该片段
        if (srcIdx >= 1 && srcIdx <= gSnips.Length)
            InsertText(SnipInsertText(gSnips[srcIdx]))
        return
    }
    dstIdx := srcIdx
    if (upWin = snipGui.Hwnd && gSnipCtrlIdx.Has(upCtrl))
        dstIdx := gSnipCtrlIdx[upCtrl]         ; 松手落在哪张卡片 → 插到那一位
    MoveSnip(srcIdx, dstIdx)
}

; 把第 src 条片段移到第 dst 位，存盘并重建面板
MoveSnip(src, dst, *) {
    global gSnips
    if (src < 1 || src > gSnips.Length || src = dst)
        return
    item := gSnips.RemoveAt(src)
    dst := Max(1, Min(dst, gSnips.Length + 1))
    gSnips.InsertAt(dst, item)
    SaveSnips()
    OpenSnippets()
}

; 把一段文字插入目标窗口（等同 InsertPath，但发的是原文，不加引号/空格），插完收回工具条
InsertText(text, *) {
    InsertAndMinimize(text)
}

; ============================== 时间戳转时区 ================================
; 填入秒级时间戳(13 位当毫秒自动识别)，实时显示各时区时间。可常驻。
OpenTimeConverter(*) {
    global tzGui, MyGui, snipGui, iconGui, gVisible, gSnipVisible, gTzVisible, gActivePanel
    global gTzInput, gTzOut
    Critical

    ; 关掉另外两个面板（同一时间只显示一个）
    if (MyGui != "") {
        try MyGui.Hide()
        gVisible := false
    }
    if (snipGui != "") {
        try snipGui.Hide()
        gSnipVisible := false
    }
    if (tzGui != "") {
        try tzGui.Destroy()
        tzGui := ""
    }

    padX := 12, headerH := 44, rowH := 30, winW := 420
    winH := headerH + 6 + 4 * rowH + 12

    tzGui := Gui("+AlwaysOnTop", "时间戳转时区")
    tzGui.SetFont("s10 c202020", "Segoe UI")
    tzGui.MarginX := padX, tzGui.MarginY := 8

    tzGui.Add("Text", "x" padX " y13", "秒时间戳：")
    gTzInput := tzGui.Add("Edit", "x+6 yp-3 w180", "")
    nowb := tzGui.Add("Button", "x+6 yp-1 w56 h26", "现在")
    mb := tzGui.Add("Button", "x" (winW - 36) " y8 w26 h26", "—")

    gTzOut := Map()
    zones := [["中国 (UTC+8)", 8], ["UTC", 0], ["PST (UTC-8)", -8], ["PDT (UTC-7)", -7]]
    y0 := headerH + 6
    for i, z in zones {
        yy := y0 + (i - 1) * rowH
        tzGui.Add("Text", "x" padX " y" (yy + 3) " w118", z[1])
        out := tzGui.Add("Text", "x" (padX + 122) " y" (yy + 3) " w" (winW - padX - 122 - 8) " 0x100", "—")
        out.OnEvent("Click", CopyTz.Bind(out))
        gTzOut[z[1]] := out
    }

    nowb.OnEvent("Click", (*) => (gTzInput.Value := TzNowSeconds(), RefreshTz()))
    mb.OnEvent("Click", (*) => Minimize())
    gTzInput.OnEvent("Change", (*) => RefreshTz())
    tzGui.OnEvent("Close", (*) => Minimize())
    tzGui.OnEvent("Escape", (*) => Minimize())

    sx := 0, sy := 0
    PlacePanelByBar(&sx, &sy, winW, winH)   ; 贴工具条下方
    tzGui.Show("x" sx " y" sy " w" winW " h" winH)
    gTzVisible := true
    gActivePanel := "tz"
    ShowBar()      ; 工具条常驻
    RefreshTz()
}

; 重算并刷新四个时区显示
RefreshTz() {
    global gTzInput, gTzOut
    if (gTzInput = "" || gTzOut = "")
        return
    digits := RegExReplace(Trim(gTzInput.Value), "\D", "")
    zones := Map("中国 (UTC+8)", 8, "UTC", 0, "PST (UTC-8)", -8, "PDT (UTC-7)", -7)
    if (digits = "") {
        for name, ctrl in gTzOut
            ctrl.Text := "—"
        return
    }
    ts := Integer(digits)
    if (StrLen(digits) >= 13)   ; 13 位当毫秒
        ts := ts // 1000
    for name, ctrl in gTzOut {
        try
            ctrl.Text := TzFormat(ts, zones[name])
        catch
            ctrl.Text := "（时间戳超出范围）"
    }
}

; Unix 秒 + 时区偏移(小时) → "yyyy-MM-dd HH:mm:ss 周X"
; 注意：日期和星期要分开 FormatTime——同一格式串里 dd(日) 之后的 ddd(星期) 不会被解析、会原样输出 "ddd"
TzFormat(ts, offsetHours) {
    utc := DateAdd("19700101000000", ts, "Seconds")
    t := DateAdd(utc, offsetHours, "Hours")
    return FormatTime(t, "yyyy-MM-dd HH:mm:ss") " " FormatTime(t, "ddd")
}

; 当前 Unix 秒时间戳
TzNowSeconds() {
    return DateDiff(A_NowUTC, "19700101000000", "Seconds")
}

; 点某行时间 → 复制到剪贴板，短暂提示
CopyTz(ctrl, *) {
    if (ctrl.Text = "" || ctrl.Text = "—")
        return
    A_Clipboard := ctrl.Text
    ToolTip("已复制：" ctrl.Text)
    SetTimer(() => ToolTip(), -900)
}

; ============================== 退出保存 =====================================
SaveState(*) {
    global iconGui, IniPath, Folder, gPosX, gPosY, bubbleGui, gBubbleVisible
    try {
        if (gBubbleVisible && bubbleGui != "") {   ; 气泡状态：存气泡位置
            bubbleGui.GetPos(&bx, &by)
            gPosX := bx, gPosY := by
        } else if (iconGui != "") {                ; 否则存工具条位置
            iconGui.GetPos(&ix, &iy)
            gPosX := ix, gPosY := iy
        }
    }
    try IniWrite(Folder, IniPath, "config", "Folder")
    try {
        if (gPosX != "")
            IniWrite(gPosX, IniPath, "pos", "X")
        if (gPosY != "")
            IniWrite(gPosY, IniPath, "pos", "Y")
    }
}
