#Requires -Version 5.1

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V79 UNIFICADO) - EDICIÓN APP (GUI)
#   V79 UNIFICADO - Novedades:
#     Unifica V76 + V79: todas las opciones (01-12) en un solo script.
#     Interfaz renovada: menú lateral por secciones, buscador y filtro por nivel,
#          columna NIVEL (CRÍTICO / ALERTA / OK / INFO), menú contextual (clic derecho),
#          exportar la vista a CSV, atajos de teclado y dos temas (Slate / Sombrio).
#     MODS ordenados: por versión de Minecraft y, dentro de cada una,
#          RENOMBRADOS > SOSPECHOSOS > APROBADOS (orden alfabético).
#     El panel de resultados se abre desde que empieza el análisis.
#   V76 - Novedades:
#     [ANTI-BYPASS] Detección de archivos renombrados:
#          - Metadatos PE internos (OriginalFilename, ProductName...).
#          - Contenido interno de .jar/.zip (entradas que delatan cheats).
#          - Extensión falsa por cabecera (MZ/PK).
#          - Alternate Data Streams (ADS) con macros ocultas.
#          - Ventanas activas con títulos de cheats/clients.
#          - Autoarranque (claves Run/RunOnce).
#     Interfaz renovada: paleta rojo / negro / verde.
#   V75 - Novedades:
#     [11] LILITH SERVICES (lilith-ps) integrado en el menú.
#     MODS separados por versión de Minecraft (detectada del nombre,
#          de la carpeta y del interior del .jar: fabric.mod.json,
#          mods.toml, mcmod.info, quilt.mod.json).
#     Detección de MACROS mejorada: procesos, software instalado
#          (registro), tareas programadas, servicios, archivos en
#          carpetas del usuario y carpeta de Inicio.
#   NUEVO: Opción 13 - Anti-Bypass Forense (Procesos, Hashes, Defender, Firmas)
# ============================================================

$script:AutoElevate     = $true   # $true = pedir permisos de Administrador (UAC) al abrir
$script:DoomsdayUrl      = "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1"
$script:SystemInformerUrl = "https://sourceforge.net/projects/systeminformer/files/latest/download"
$script:JournalTraceUrl   = "https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe"
$script:LilithServicesUrl = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1"
# URL raw de ESTE script en tu GitHub (para poder abrirlo con un solo comando y pedir UAC).
# Cambia el nombre del archivo si lo subes con otro nombre.
$script:SelfUrl         = "https://raw.githubusercontent.com/jgonzalo17/Doomsday-Detector/main/Sombrio_V79_GUI.ps1"
$script:IsChild         = (($args -contains "--sombrio-child") -or [bool]$global:SombrioChild)

# ------------------------------------------------------------
# RELANZAR OCULTO: abre la app sin ventana de consola (y con UAC si se desea)
# ------------------------------------------------------------
if (-not $script:IsChild -and $PSCommandPath -and $Host.Name -eq 'ConsoleHost') {
    $launched = $false
    try {
        $psExe   = (Get-Process -Id $PID).Path
        $argLine = "-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`" --sombrio-child"
        $isAdm   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($script:AutoElevate -and -not $isAdm) {
            try {
                Start-Process -FilePath $psExe -ArgumentList $argLine -Verb RunAs -ErrorAction Stop
                $launched = $true
            } catch { }   # UAC cancelado: se abre igual, sin privilegios
        }
        if (-not $launched) {
            Start-Process -FilePath $psExe -ArgumentList $argLine -WindowStyle Hidden -ErrorAction Stop
            $launched = $true
        }
    } catch { $launched = $false }
    if ($launched) { exit }
}

# ------------------------------------------------------------
# EJECUTADO CON "irm ... | iex": pedir UAC y abrir la app oculta en un proceso elevado
# ------------------------------------------------------------
if (-not $script:IsChild -and -not $PSCommandPath -and $script:AutoElevate -and $script:SelfUrl -and $Host.Name -eq 'ConsoleHost') {
    $isAdmIex = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmIex) {
        try {
            $cmdIex = "`$global:SombrioChild = `$true; iex ((irm '$($script:SelfUrl)') -replace '^\uFEFF')"
            $encIex = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmdIex))
            Start-Process -FilePath "powershell.exe" -Verb RunAs -WindowStyle Hidden -ErrorAction Stop `
                -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -EncodedCommand $encIex"
            return   # la app ya se abrió en el proceso elevado
        } catch { }  # UAC cancelado: se abre igual, sin privilegios
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'Sombrio.WinApi').Type) {
    try {
        Add-Type -Namespace Sombrio -Name WinApi -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@
    } catch { }
}
try { [void][Sombrio.WinApi]::SetProcessDPIAware() } catch { }
if (-not ([System.Management.Automation.PSTypeName]'Sombrio.Dwm').Type) {
    try {
        Add-Type -Namespace Sombrio -Name Dwm -MemberDefinition '[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);'
    } catch { }
}
function Set-DarkTitleBar($Form) {
    try {
        $h = $Form.Handle
        $on = 1
        [void][Sombrio.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$on, 4)
        foreach ($pair in @(@(35, $script:C.Panel), @(34, $script:C.Border), @(36, $script:C.Text))) {
            $c = $pair[1]
            $bgr = [int]($c.R + 256 * $c.G + 65536 * $c.B)
            [void][Sombrio.Dwm]::DwmSetWindowAttribute($h, [int]$pair[0], [ref]$bgr, 4)
        }
    } catch { }
}
[System.Windows.Forms.Application]::EnableVisualStyles()

# Si se ejecuta en esta misma consola (irm | iex siendo administrador), se oculta mientras la app está abierta.
$script:HiddenConsole = [IntPtr]::Zero
if (-not $script:IsChild) {
    try {
        $hwnd = [Sombrio.WinApi]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero -and [Sombrio.WinApi]::IsWindowVisible($hwnd)) { [void][Sombrio.WinApi]::ShowWindow($hwnd, 0); $script:HiddenConsole = $hwnd }
    } catch { }
}

# ============================================================
# ESTADO GLOBAL
# ============================================================
$script:DefaultModsPath = "$env:APPDATA\.minecraft\mods"
$script:Busy            = $false
$script:CancelRequested = $false
$script:CloseAfter      = $false
$script:ProgressPct     = 0
$script:ScanCount       = 0
$script:DeepHits        = 0
$script:LastReport      = $null
$script:ViewMode        = 'live'      # 'live' = resultados | 'registry' = registro de sesión
$script:ActiveCat       = 'Stats'
$script:CatData         = @{}
$script:RegData         = @{}
$script:RecycleMeta     = @{}
$script:CatButtons      = @{}
$script:NavActive       = ''
$script:NavButtons      = [System.Collections.Generic.List[object]]::new()
$script:JarVersionProbes = 0           # límite de aperturas de .jar para detectar versión (optimizado: 300)
$script:ContentProbes   = 0           # V76 - límite de lecturas de contenido/metadatos (optimizado: 300)
$script:FilterText      = ""          # buscador de la tabla de resultados
$script:FilterLevel     = 'all'       # all | red | warn
$script:SuppressFilter  = $false
$script:FilterBar = $null; $script:TxtFilter = $null; $script:CmbLevel = $null; $script:LblCount = $null

# ------------------------------------------------------------
# MEMORIA DE SESIÓN INDEPENDIENTE (Para la Opción 09)
# ------------------------------------------------------------
$script:LogMods      = [System.Collections.Generic.List[string]]::new()
$script:LogPrefetch  = [System.Collections.Generic.List[string]]::new()
$script:LogMemoria   = [System.Collections.Generic.List[string]]::new()
$script:LogMacros    = [System.Collections.Generic.List[string]]::new()
$script:LogServicios = [System.Collections.Generic.List[string]]::new()
$script:LogDisco     = [System.Collections.Generic.List[string]]::new()
$script:LogPapelera  = [System.Collections.Generic.List[string]]::new()
$script:LogHistorial = [System.Collections.Generic.List[string]]::new()
$script:LogAntiBypass = [System.Collections.Generic.List[string]]::new()
$script:LogScreenshots = [System.Collections.Generic.List[string]]::new()
$script:LogBrowser     = [System.Collections.Generic.List[string]]::new()
$script:LogMcLogs      = [System.Collections.Generic.List[string]]::new()

function Add-ToLog([System.Collections.Generic.List[string]]$LogList, [array]$Items) {
    if ($null -ne $Items) {
        foreach ($item in $Items) {
            if ($item -notmatch "======" -and $item -notmatch "Sin hallazgos") {
                if (-not $LogList.Contains($item)) {
                    $LogList.Add($item)
                }
            }
        }
    }
}

# ------------------------------------------------------------
# TEMAS: Slate (V79) y Sombrio (V76: rojo / negro / verde)
# Se elige en el menú [13]; se guarda en %APPDATA%\ElSombrio\theme.txt
# ------------------------------------------------------------
function New-Rgb([int]$R, [int]$G, [int]$B) { return [System.Drawing.Color]::FromArgb($R, $G, $B) }
$script:Themes = @{
    Slate = @{
        Bg = (New-Rgb 13 17 23);  Panel = (New-Rgb 19 24 32);  Panel2 = (New-Rgb 27 34 45);  Row2 = (New-Rgb 23 29 39)
        Border = (New-Rgb 52 63 80);  Hover = (New-Rgb 38 48 63);  Select = (New-Rgb 47 60 79)
        Accent = (New-Rgb 96 165 250);  Pink = (New-Rgb 226 130 150);  Blue = (New-Rgb 94 200 170);  DBlue = (New-Rgb 58 145 120)
        Text = (New-Rgb 228 233 240);  Muted = (New-Rgb 145 158 178)
        Red = (New-Rgb 240 118 118);  RedDark = (New-Rgb 150 62 68);  Green = (New-Rgb 118 208 152)
        Yellow = (New-Rgb 232 200 122);  TealDim = (New-Rgb 126 178 162)
    }
    Sombrio = @{
        Bg = (New-Rgb 8 4 6);  Panel = (New-Rgb 16 8 10);  Panel2 = (New-Rgb 28 12 14);  Row2 = (New-Rgb 20 10 12)
        Border = (New-Rgb 140 40 46);  Hover = (New-Rgb 70 20 24);  Select = (New-Rgb 95 26 30)
        Accent = (New-Rgb 255 84 92);  Pink = (New-Rgb 255 84 92);  Blue = (New-Rgb 80 220 140);  DBlue = (New-Rgb 45 150 95)
        Text = (New-Rgb 245 235 235);  Muted = (New-Rgb 190 140 145)
        Red = (New-Rgb 255 70 84);  RedDark = (New-Rgb 150 30 40);  Green = (New-Rgb 80 255 140)
        Yellow = (New-Rgb 255 200 90);  TealDim = (New-Rgb 140 200 170)
    }
    Noche = @{
        Bg = (New-Rgb 12 13 17);  Panel = (New-Rgb 18 19 25);  Panel2 = (New-Rgb 26 28 36);  Row2 = (New-Rgb 21 22 29)
        Border = (New-Rgb 40 43 54);  Hover = (New-Rgb 32 35 45);  Select = (New-Rgb 36 41 56)
        Accent = (New-Rgb 104 124 168);  Pink = (New-Rgb 122 100 156);  Blue = (New-Rgb 90 140 124);  DBlue = (New-Rgb 60 105 90)
        Text = (New-Rgb 208 213 224);  Muted = (New-Rgb 122 128 144)
        Red = (New-Rgb 198 86 94);  RedDark = (New-Rgb 110 50 56);  Green = (New-Rgb 94 160 114)
        Yellow = (New-Rgb 192 162 94);  TealDim = (New-Rgb 98 142 142)
    }
    Neon = @{
        Bg = (New-Rgb 7 9 18);  Panel = (New-Rgb 11 15 28);  Panel2 = (New-Rgb 17 23 42);  Row2 = (New-Rgb 13 18 34)
        Border = (New-Rgb 28 42 74);  Hover = (New-Rgb 20 34 64);  Select = (New-Rgb 16 48 84)
        Accent = (New-Rgb 0 224 255);  Pink = (New-Rgb 168 85 247);  Blue = (New-Rgb 52 255 170);  DBlue = (New-Rgb 20 180 120)
        Text = (New-Rgb 225 238 255);  Muted = (New-Rgb 118 140 175)
        Red = (New-Rgb 255 64 110);  RedDark = (New-Rgb 150 30 60);  Green = (New-Rgb 46 255 150)
        Yellow = (New-Rgb 255 205 70);  TealDim = (New-Rgb 90 190 200)
    }
    Pro = @{
        Bg = (New-Rgb 15 17 21);  Panel = (New-Rgb 21 24 30);  Panel2 = (New-Rgb 30 34 42);  Row2 = (New-Rgb 25 28 35)
        Border = (New-Rgb 44 50 61);  Hover = (New-Rgb 38 44 55);  Select = (New-Rgb 34 50 80)
        Accent = (New-Rgb 79 140 255);  Pink = (New-Rgb 96 112 140);  Blue = (New-Rgb 52 211 153);  DBlue = (New-Rgb 16 150 110)
        Text = (New-Rgb 230 234 241);  Muted = (New-Rgb 138 148 163)
        Red = (New-Rgb 248 81 73);  RedDark = (New-Rgb 140 40 40);  Green = (New-Rgb 63 185 80)
        Yellow = (New-Rgb 227 179 65);  TealDim = (New-Rgb 110 160 160)
    }
    Ocean = @{
        Bg = (New-Rgb 6 12 24);  Panel = (New-Rgb 10 20 38);  Panel2 = (New-Rgb 16 32 56);  Row2 = (New-Rgb 12 24 44)
        Border = (New-Rgb 30 80 140);  Hover = (New-Rgb 20 50 90);  Select = (New-Rgb 25 65 120)
        Accent = (New-Rgb 0 200 255);  Pink = (New-Rgb 0 200 255);  Blue = (New-Rgb 0 255 200);  DBlue = (New-Rgb 0 180 160)
        Text = (New-Rgb 220 240 255);  Muted = (New-Rgb 120 170 210)
        Red = (New-Rgb 255 80 100);  RedDark = (New-Rgb 160 40 60);  Green = (New-Rgb 0 255 160)
        Yellow = (New-Rgb 255 220 80);  TealDim = (New-Rgb 0 200 180)
    }
}
$script:ThemeFile = Join-Path $env:APPDATA 'ElSombrio\theme_v82.txt'
$script:ThemeName = 'Noche'
try {
    if (Test-Path -LiteralPath $script:ThemeFile) {
        $tn = (Get-Content -LiteralPath $script:ThemeFile -ErrorAction Stop | Select-Object -First 1).Trim()
        if ($script:Themes.ContainsKey($tn)) { $script:ThemeName = $tn }
    }
} catch { }
$script:C = $script:Themes[$script:ThemeName]


# ------------------------------------------------------------
# ARTE ORIGINAL: EL SOMBRIO GIRL
# ------------------------------------------------------------
$script:sideGirl = @(
    "                                                     .::---:               ::"
    "                                                    =-..-::-*=            -+.   -+-"
    "                                                   -: =.     :+          :=+   ==="
    "                                                  :+ .*       =:        ===-::.==."
    "                               -: +                :. ..:. -.=.     .."
    "                                                    =--=       .....  =:   .=  ==+-   .:++."
    "                                                     .-==.    =:...::-:    -.   :*-. :==-."
    "                                                        -=-. .+       :=-     :-: .=:=.+"
    "                                                          .:=---::::.   -=+:  .  .--.=.  "
    "                                                       :----:  ::.  :=:   :=-:   -  :=:::."
    "                                                     :-.:...::- :- ::::=:  -=.: :-.=-----+"
    "                                                    =. -: :..   . .:    ==  .-.  +-::+."
    "                                                  --. =.  .   :    =:    *+  -+=:..:=:"
    "                                            :---::. -:  -   :+:  =  =:    ++  .+ ..---"
    "                                             .---::...-.  :-:=  .+   =    .==  --. ..++"
    "                                            ---:.   :. .--..-+  :=    --.   =+.  +.:-:-+"
    "                                            =..: :=--=+-===..-  -..: = :--:.:=-  .=. *+."
    "                                            *.* -=  *-*..**=  : =..+.=:.   ..=.   .+ :*-"
    "                                            .--.+:  =-*.  .    :--@*=+=:.-=  :=    =:+:+"
    "                                              =:*:-. .+=     .    --.-=:  :-  +    -:=-"
    "                                              :.  ..=-  =-  :::    :-=-    .+=-    --+"
    "                                                   =-..  .-::..::--= ...-:-.-.     ==."
    "                                                  .=: :. -+:::+-..+..+. -==.      :+"
    "                                                    ::=--=.---+- .-=:=.. ..       :"
    "                                               .:-::--=: :+:.--*--+=. .:=:::"
    "                                              =:-:..:.:.  -..-.... :.:  .  --"
    "                                          .-=-  +=:.=::: .+: .==:=.:-+      =:"
    "                                          =-:. .+ ..  .  .+-:  .-=.=:-     ..+:"
    "                                              ::--. .:.    .-:.    .:-.   .      :-"
    "                                               .--=:.     =-.    .+:          .:"
    "                                                .-::.    .+:     =.          ."
    "                                                 .-==:  .=.     =.        .:"
    "                                                    :=--+     -=      .-:"
    "                                                      .+:    .+.    .:"
    "                                                      :=    .=.   .-"
    "                                                       =.   +."
    "                                                       -=  -=  .:"
    "                                                        +. +.  ="
    "                                                       -=+  .+"
    "                                                         +:  ="
    "                                                         :=  +"
    "                                                          +:-"
    "                                                          :=."
    "                                                         .::"
)

$script:BannerText = @'
███████╗ ██████╗ ███╗   ███╗██████╗ ██████╗ ██╗ ██████╗
██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║██╔═══██╗
███████╗██║   ██║██╔████╔██║██████╔╝██████╔╝██║██║   ██║
╚════██║██║   ██║██║╚██╔╝██║██╔══██╗██╔══██╗██║██║   ██║
███████║╚██████╔╝██║ ╚═╝ ██║██████╔╝██║  ██║██║╚██████╔╝
╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝
'@

# ------------------------------------------------------------
# REGLAS DE DETECCIÓN
# ------------------------------------------------------------
$script:IllegalKeywords = @(
    "antighosttotem", "fasttotem", "totemhelper", "autototem", "totem", "switchtotems",
    "acurateblock", "fastplace", "attacktroughgrass", "periodicattack", "toroautoattack",
    "maceattack", "autoclicker", "autoclick", "clicker", "macros", "freecam",
    "tweakeroo", "inventorynext", "hotbaroptimizer", "fastxp", "slotcycler",
    "quickhotkeys", "itemscroller", "autoswitch", "xray",
    "nojumpdelay", "noinputlag", "nohitdelay", "elytrabugfix", "firerocketkey",
    "marrowcrystal", "anchoroptimizer", "quickelytra", "clickcrystals",
    "radarbro", "zansmap", "voxelmap", "xaerosmap",
    "aimbot", "killaura", "reach", "fly", "scaffold", "criticals", "jclicker", "ghostclicker",
    "meteor", "wurst", "aristois", "bleachhack", "mathax", "liquidbounce", 
    "raven", "vape", "novoline", "flux", "impact", "inertia", "kami", "krypton"
)

$script:RegexHacks = (($script:IllegalKeywords | ForEach-Object {
    if ($_.Length -le 5) { "\b$_\b" } else { $_ }
}) -join "|")

# V75 - Lista de macros/autoclickers ampliada y mejorada
$script:MacroAutoclickCritical = @(
    "autoclicker", "auto-clicker", "auto_click", "autoclick", "clickbot", "click-bot",
    "gsautoclick", "gs auto clicker", "opautoclick", "op auto clicker",
    "fastclick", "fast clicker", "perfectclick", "perfect clicker", "clickstorm",
    "speed autoclicker", "extreme auto clicker", "super fast clicker",
    "freeautoclicker", "free auto clicker", "auto clicker typer",
    "jitbit", "murgee", "tinytask",
    "automouseclick", "auto mouse click", "mouserecorder", "robomouse", "ghost mouse",
    "supermouse", "super mouse", "mini mouse macro", "x-mouse", "xmouse",
    "macrorecorder", "macro-recorder", "macro_recorder", "macro creator",
    "macro express", "mouse and keyboard recorder",
    "pulover", "pulovers macro", "macroscheduler",
    "autohotkey", "ahk_", "\.ahk", "autoit", "\.au3", "\.vbs", "\.scr",
    "logitech gaming software", "lghub", "g hub", "razer synapse", "synapse3", "synapse2",
    "icue", "corsair icue", "steelseries engine", "bloody7", "a4tech", "redragon"
)
$script:RegexMacroCritical  = ($script:MacroAutoclickCritical -join "|")
$script:PathWhitelistPatterns = "site-packages|dist-packages|\\lib\\python|\\Lib\\|\\venv\\|\\\.venv\\|\\conda\\|node_modules|\\Scripts\\|pydevd"

$script:RxOpts            = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled'
$script:RxHacks           = [regex]::new($script:RegexHacks, $script:RxOpts)
$script:RxMacroCritical   = [regex]::new($script:RegexMacroCritical, $script:RxOpts)
$script:RxPathWhitelist   = [regex]::new($script:PathWhitelistPatterns, $script:RxOpts)
$script:RxMcProcess       = [regex]::new("java|javaw|lunarclient|craft", $script:RxOpts)
$script:RxJavaNames       = [regex]::new("javaw?\.exe|lunarclient|minecraft|craft", $script:RxOpts)
$script:RxMcVersion       = [regex]::new("(?<![\d._])1[._](\d{1,2})([._]\d+)?", $script:RxOpts)
# V76 - Títulos de ventana de clients/cheats conocidos
$script:RxCheatWindows    = [regex]::new("meteor client|meteorclient|wurst|aristois|bleachhack|liquidbounce|kami|impact client|inertia client|vape(?!r)|flux client|mathax|jclicker|killaura|scaffold", $script:RxOpts)
# V76 - Entradas internas de .jar que delatan un cheat renombrado
$script:RxCheatInner      = [regex]::new("meteor|wurstclient|wurst/client|aristois|bleachhack|liquidbounce|kami/client|killaura|scaffold|autototem|autoclick|freecam|xray|jesus|flight", $script:RxOpts)

$script:WindowsServices = @("dps", "appinfo", "pcasvc", "eventlog", "sysmain", "dusmsvc", "bam")

# ============================================================
# DETECCIÓN DE VERSIÓN DE MINECRAFT DE UN MOD (V75)
#   Orden: 1) nombre del archivo  2) carpeta padre  3) metadatos dentro del .jar
# ============================================================
function Get-JarMcVersion {
    param([string]$Path, [string]$FileName)
    # 1) Metadatos dentro del .jar (lo más fiable: evita confundir la versión del mod con la de Minecraft)
    if (-not [string]::IsNullOrWhiteSpace($Path) -and $script:JarVersionProbes -lt 300 -and (Test-Path -LiteralPath $Path)) {
        try {
            $len = (Get-Item -LiteralPath $Path -ErrorAction Stop).Length
            if ($len -lt 80MB) {
                $script:JarVersionProbes++
                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
                try {
                    foreach ($metaName in @('fabric.mod.json', 'quilt.mod.json', 'neoforge.mods.toml', 'META-INF/neoforge.mods.toml', 'META-INF/mods.toml', 'mcmod.info')) {
                        $entry = $zip.GetEntry($metaName)
                        if (-not $entry) { continue }
                        $sr = New-Object System.IO.StreamReader($entry.Open())
                        try { $txt = $sr.ReadToEnd() } finally { $sr.Dispose() }
                        $m = [regex]::Match($txt, '"minecraft"\s*:\s*(?:"|\[\s*")[^"]*?(1[._]\d{1,2}(?:[._]\d+)?)')
                        if (-not $m.Success) { $m = [regex]::Match($txt, 'modId\s*=\s*"minecraft"[\s\S]{0,300}?versionRange\s*=\s*"[\[\(~>=<\s]*(1[._]\d{1,2}(?:[._]\d+)?)') }
                        if (-not $m.Success) { $m = [regex]::Match($txt, 'acceptedMinecraftVersions\s*=\s*"?[\[\(~>=<\s]*(1[._]\d{1,2}(?:[._]\d+)?)') }
                        if (-not $m.Success) { $m = [regex]::Match($txt, '"mcversion"\s*:\s*"(1[._]\d{1,2}(?:[._]\d+)?)') }
                        if ($m.Success) { return ($m.Groups[1].Value -replace '_', '.') }
                    }
                } finally { $zip.Dispose() }
            }
        } catch { }
    }
    # 2) Nombre del archivo
    if ($FileName -and $script:RxMcVersion.IsMatch($FileName)) {
        return (($script:RxMcVersion.Match($FileName).Value) -replace '_', '.')
    }
    # 3) Carpeta padre
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $parent = Split-Path -Path $Path -Parent -ErrorAction SilentlyContinue
        if ($parent -and $script:RxMcVersion.IsMatch($parent)) {
            return (($script:RxMcVersion.Match($parent).Value) -replace '_', '.')
        }
    }
    return "Desconocida"
}

# ------------------------------------------------------------
# V75 - Agrupa los mods por versión de Minecraft y pone los
# ilegales primero dentro de cada grupo.
# ------------------------------------------------------------
function Group-ModsByVersion {
    param([array]$ModItems)
    $groups = [ordered]@{}
    foreach ($raw in @($ModItems)) {
        # Normaliza ítems que ya traen "[MC x - ETIQUETA]" (por ejemplo al regenerar desde el registro)
        $it = ([string]$raw) -replace '^\[MC\s+[^\]]*?\s-\s', '['
        if ($it -match '^=+') { continue }
        $path = ""
        if ($it -match '\|\s*Ruta:\s*(.+?)(?=\s+\|\s|\s*$)') { $path = $Matches[1].Trim() }
        $name = if ($path) { [IO.Path]::GetFileName($path) } else { "" }
        $ver  = Get-JarMcVersion -Path $path -FileName $name
        if (-not $groups.Contains($ver)) { $groups[$ver] = [System.Collections.Generic.List[string]]::new() }
        $groups[$ver].Add($it)
    }
    $sortedKeys = @($groups.Keys | Sort-Object -Descending {
        if ($_ -eq 'Desconocida') { [version]'0.0.0' } else { try { [version]$_ } catch { [version]'0.0.1' } }
    })
    $result = [System.Collections.Generic.List[string]]::new()
    # Orden alfabético por nombre del archivo (ignora la etiqueta [..] del inicio)
    $byName = { ([string]$_ -replace '^\[[^\]]*\]\s*', '') }
    foreach ($vk in $sortedKeys) {
        $items = @($groups[$vk])
        $ren = @($items | Where-Object { $_ -match 'RENOMBRADO' } | Sort-Object $byName)
        $sus = @($items | Where-Object { $_ -match 'ILEGAL|SOSPECHOSO' -and $_ -notmatch 'RENOMBRADO' } | Sort-Object $byName)
        $apr = @($items | Where-Object { $_ -notmatch 'ILEGAL|SOSPECHOSO|RENOMBRADO' } | Sort-Object $byName)
        $result.Add("====== MINECRAFT $vk  -  $($items.Count) mods  -  $($ren.Count + $sus.Count) sospechosos ======")
        foreach ($blk in @(@('RENOMBRADOS', $ren), @('SOSPECHOSOS', $sus), @('APROBADOS', $apr))) {
            $list = @($blk[1])
            if ($list.Count -eq 0) { continue }
            $result.Add("====== > $($blk[0]) ($($list.Count)) ======")
            foreach ($m in $list) {
                # Conserva la etiqueta original ([MOD ILEGAL], [MOD APROBADO]...) y le añade la versión
                if ($m -match '^\[[^\]]+\]') { $result.Add(($m -replace '^\[([^\]]+)\]', "[MC $vk - `$1]")) }
                else                         { $result.Add("[MC $vk - MOD] $m") }
            }
        }
    }
    return $result
}

# ============================================================
# V76 - ANTI-BYPASS: DETECCIÓN DE ARCHIVOS RENOMBRADOS
# ============================================================

# Metadatos internos PE: un .exe/.dll renombrado sigue delatando
# su nombre original (OriginalFilename, ProductName...).
function Test-PeSuspicious {
    param([string]$Path)
    try {
        $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
        $blob = ("$($vi.OriginalFilename) $($vi.InternalName) $($vi.ProductName) $($vi.FileDescription) $($vi.CompanyName)").Trim()
        if ($blob -and ($script:RxMacroCritical.IsMatch($blob) -or $script:RxHacks.IsMatch($blob))) { return $blob }
    } catch { }
    return $null
}

# Contenido interno de .jar/.zip: aunque el archivo se renombre,
# las entradas (clases, carpetas) delatan el cheat.
function Test-JarContentSuspicious {
    param([string]$Path)
    if ($script:ContentProbes -ge 300) { return $null }
    try {
        $len = (Get-Item -LiteralPath $Path -ErrorAction Stop).Length
        if ($len -gt 40MB) { return $null }
        $script:ContentProbes++
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $innerHits = [System.Collections.Generic.List[string]]::new()
            foreach ($entry in $zip.Entries) {
                $en = $entry.FullName
                if ($script:RxCheatInner.IsMatch($en) -and $en -notmatch '^META-INF/maven') {
                    if ($innerHits.Count -lt 4) { $innerHits.Add($en) }
                }
            }
            if ($innerHits.Count -gt 0) { return ($innerHits -join "; ") }
        } finally { $zip.Dispose() }
    } catch { }
    return $null
}

# Extensión falsa por cabecera: MZ en .jar/.zip/.png = ejecutable camuflado.
function Test-MagicMismatch {
    param([string]$Path, [string]$Extension)
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $b = [byte[]]::new(2); [void]$fs.Read($b, 0, 2)
            $isMz = ($b[0] -eq 0x4D -and $b[1] -eq 0x5A)
            $isPk = ($b[0] -eq 0x50 -and $b[1] -eq 0x4B)
            if ($isMz -and $Extension -in '.jar','.zip','.png','.jpg','.jpeg','.txt','.log','.json','.mp3','.mp4') {
                return "Ejecutable PE (MZ) oculto con extensión $Extension"
            }
            if ($isPk -and $Extension -in '.exe','.dll','.sys','.scr','.com') {
                return "Contenedor ZIP/JAR (PK) con extensión de ejecutable"
            }
        } finally { $fs.Dispose() }
    } catch { }
    return $null
}

# Alternate Data Streams: zonas ocultas donde se esconden macros.
function Get-SuspiciousAds {
    param([string]$Path)
    $hits = [System.Collections.Generic.List[string]]::new()
    try {
        foreach ($s in (Get-Item -LiteralPath $Path -Stream * -ErrorAction SilentlyContinue)) {
            if ($s.Stream -eq '::$DATA') { continue }
            $suspect = $false
            if ($script:RxMacroCritical.IsMatch($s.Stream) -or $script:RxHacks.IsMatch($s.Stream)) { $suspect = $true }
            if (-not $suspect -and $s.Length -gt 0 -and $s.Length -lt 2MB) {
                try {
                    $txt = Get-Content -LiteralPath $Path -Stream $s.Stream -Raw -ErrorAction Stop
                    if ($txt -and ($script:RxMacroCritical.IsMatch($txt) -or $script:RxHacks.IsMatch($txt))) { $suspect = $true }
                } catch { }
            }
            if ($suspect) { $hits.Add($s.Stream) }
        }
    } catch { }
    return $hits
}

# V76 - Ventanas activas del escritorio con títulos de cheats.
function Find-CheatWindows {
    $hits = [System.Collections.Generic.List[string]]::new()
    try {
        $cb = [Sombrio.WinApi+EnumWindowsProc]{
            param($hWnd, $lParam)
            try {
                if ([Sombrio.WinApi]::IsWindowVisible($hWnd)) {
                    $sb = New-Object System.Text.StringBuilder 512
                    [void][Sombrio.WinApi]::GetWindowText($hWnd, $sb, $sb.Capacity)
                    $t = $sb.ToString().Trim()
                    if ($t.Length -gt 3 -and $script:RxCheatWindows.IsMatch($t)) { $hits.Add($t) }
                }
            } catch { }
            return $true
        }
        [void][Sombrio.WinApi]::EnumWindows($cb, [IntPtr]::Zero)
    } catch { }
    return $hits
}

# ============================================================
# MOTOR DECOMPRESSOR SEGURO (se compila al abrir la ventana)
# ============================================================
$script:DecompressorSource = @'
using System;
using System.Runtime.InteropServices;
public class SombrioDecompressor {
    [DllImport("ntdll.dll")]
    public static extern uint RtlDecompressBufferEx(ushort CompressionFormat, byte[] UncompressedBuffer, int UncompressedBufferSize, byte[] CompressedBuffer, int CompressedBufferSize, out int FinalUncompressedSize, IntPtr WorkSpace);
    [DllImport("ntdll.dll")]
    public static extern uint RtlGetCompressionWorkSpaceSize(ushort CompressionFormat, out uint CompressBufferWorkSpaceSize, out uint CompressFragmentWorkSpaceSize);
    public static byte[] Decompress(byte[] compressed) {
        if (compressed == null || compressed.Length < 8) return null;
        if (compressed[0] != 0x4D || compressed[1] != 0x41 || compressed[2] != 0x43) return null;
        int uncompSize = BitConverter.ToInt32(compressed, 4);
        uint wsComp, wsFrag;
        if (RtlGetCompressionWorkSpaceSize(4, out wsComp, out wsFrag) != 0) return null;
        IntPtr workspace = Marshal.AllocHGlobal((int)wsFrag);
        byte[] result = new byte[uncompSize];
        try {
            int finalSize;
            byte[] compData = new byte[compressed.Length - 8];
            Array.Copy(compressed, 8, compData, 0, compData.Length);
            if (RtlDecompressBufferEx(4, result, uncompSize, compData, compData.Length, out finalSize, workspace) != 0) return null;
            return result;
        } finally { Marshal.FreeHGlobal(workspace); }
    }
}
'@

function Initialize-Decompressor {
    if (-not ([System.Management.Automation.PSTypeName]'SombrioDecompressor').Type) {
        try { Add-Type -TypeDefinition $script:DecompressorSource } catch { }
    }
}

# ============================================================
# UTILIDADES
# ============================================================
function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ItemColor {
    param([string]$Text)
    if ($Text -match 'ILEGAL|MALICIOSO|AUTOCLICK|AUTOCICK|HACK\b|PELIGRO|CRITICO|CRÍTICO|MACRO|RENOMBRADO|EXTENSIÓN FALSA|ADS SOSPECHOSO|VENTANA CHEAT|AUTOARRANQUE|SPOOF|ELIMINADO SOSPECHOSO') { return "Red" }
    if ($Text -match 'SOSPECHOSO|ALERTA') { return "Yellow" }
    if ($script:RxJavaNames.IsMatch($Text) -or $Text -match '\[JAVA\]') { return "Green" }
    if ($Text -match 'APROBADO|NORMAL|RUNNING|\bOK\b|\[MOD') { return "Green" }
    if ($Text -match '======') { return "DarkCyan" }
    if ($Text -match 'Total:|Resumen') { return "Yellow" }
    return "Cyan"
}

function ConvertTo-UiColor([string]$Name) {
    switch ($Name) {
        "Red"      { return $script:C.Red }
        "Green"    { return $script:C.Green }
        "Yellow"   { return $script:C.Yellow }
        "DarkCyan" { return $script:C.TealDim }
        default    { return $script:C.Accent }
    }
}

function Split-ReportItem([string]$Item) {
    $left = $Item
    $right = "---"
    $tag = ""
    $isHeader = $false

    $idx = $Item.IndexOf(" | ")
    if ($idx -ge 0) {
        $left  = $Item.Substring(0, $idx).Trim()
        $right = $Item.Substring($idx + 3).Trim()
    }
    if ($left -match '^=+\s*(.*?)\s*=+$') {
        $left = $Matches[1]; $right = ""; $isHeader = $true
    } elseif ($left -match '^\[(.+?)\]\s*(.*)$') {
        $tag = $Matches[1]; $left = $Matches[2]
    }
    return [pscustomobject]@{ Tag = $tag; Name = $left; Detail = $right; Header = $isHeader }
}

function Invoke-UiPump { [System.Windows.Forms.Application]::DoEvents() }

function Show-Info([string]$Text, [string]$Title = "EL SOMBRIO IF") {
    [void][System.Windows.Forms.MessageBox]::Show($Text, $Title, 'OK', 'Information')
}

# ------------------------------------------------------------
# PAPELERA: abrir directamente la ubicación con confirmación
# ------------------------------------------------------------
function Open-SelectedPath([string]$Path, [string]$OriginalPath = "", [string]$DeletedAt = "", [string]$RecyclePath = "", [string]$Name = "") {
    if ([string]::IsNullOrWhiteSpace($Path) -and [string]::IsNullOrWhiteSpace($OriginalPath) -and [string]::IsNullOrWhiteSpace($RecyclePath)) {
        Show-Info "No se encontró una ruta válida para este elemento." "PAPELERA"
        return
    }

    $target = if (-not [string]::IsNullOrWhiteSpace($OriginalPath) -and (Test-Path -LiteralPath $OriginalPath)) {
        $OriginalPath
    } elseif (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        $Path
    } elseif (-not [string]::IsNullOrWhiteSpace($RecyclePath) -and (Test-Path -LiteralPath $RecyclePath)) {
        $RecyclePath
    } else {
        $OriginalPath
    }

    $displayName = if ($Name) { $Name } else { [IO.Path]::GetFileName($target) }
    $dateLine = if ($DeletedAt) { "Eliminado: $DeletedAt`n" } else { "" }
    $originalLine = if ($OriginalPath) { "Ruta original: $OriginalPath`n" } else { "" }
    $recycleLine = if ($RecyclePath) { "Ruta en Papelera: $RecyclePath`n" } else { "" }

    $ans = [System.Windows.Forms.MessageBox]::Show(
        "Archivo: $displayName`n`n$dateLine$originalLine$recycleLine`n¿Deseas abrir la ubicación seleccionada?",
        "CONFIRMAR APERTURA",
        'YesNo',
        'Question'
    )
    if ($ans -ne 'Yes') { return }

    try {
        # 1) Archivo original: abrir directamente seleccionándolo en el Explorador.
        if (-not [string]::IsNullOrWhiteSpace($OriginalPath) -and (Test-Path -LiteralPath $OriginalPath)) {
            Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,"' + $OriginalPath + '"')
            return
        }

        # 2) Archivo físico de la Papelera: abrir la carpeta y seleccionar el elemento.
        if (-not [string]::IsNullOrWhiteSpace($RecyclePath) -and (Test-Path -LiteralPath $RecyclePath)) {
            Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,"' + $RecyclePath + '"')
            return
        }

        # 3) Ruta normal de otro módulo.
        if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
            Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,"' + $Path + '"')
            return
        }

        $parent = if ($OriginalPath) { Split-Path -Path $OriginalPath -Parent -ErrorAction SilentlyContinue } else { Split-Path -Path $Path -Parent -ErrorAction SilentlyContinue }
        if ($parent -and (Test-Path -LiteralPath $parent)) {
            Start-Process -FilePath "explorer.exe" -ArgumentList @($parent)
        } else {
            Show-Info "La ruta ya no está disponible:`n`n$OriginalPath" "PAPELERA"
        }
    } catch {
        Show-Info "No se pudo abrir la ubicación:`n`n$target`n`n$($_.Exception.Message)" "PAPELERA"
    }
}

function Get-RowPath($Row) {
    if ($null -eq $Row) { return "" }
    if ($script:ActiveCat -eq 'Papelera' -and $Row.Tag) {
        $m = $Row.Tag
        foreach ($c in @($m.OriginalPath, $m.Path, $m.RecyclePath)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$c)) { return [string]$c }
        }
        return ""
    }
    $detail = [string]$Row.Cells['detalle'].Value
    if ($detail -match 'Ruta original:\s*(.*?)\s*\|\s*Eliminado:') { return $Matches[1].Trim() }
    if ($detail -match 'Ruta:\s*(.+?)(?=\s+\|\s|\s*$)') { return $Matches[1].Trim() }
    return ""
}

function Open-SelectedGridItem {
    $row = $script:Grid.CurrentRow
    if (-not $row) { return }

    # Las filas de Papelera llevan el objeto exacto en Tag, evitando depender del texto de la tabla.
    if ($script:ActiveCat -eq 'Papelera' -and $row.Tag) {
        $meta = $row.Tag
        Open-SelectedPath -Path ([string]$meta.Path) `
            -OriginalPath ([string]$meta.OriginalPath) `
            -DeletedAt ([string]$meta.DeletedAt) `
            -RecyclePath ([string]$meta.RecyclePath) `
            -Name ([string]$meta.Name)
        return
    }

    $path = Get-RowPath $row
    if ([string]::IsNullOrWhiteSpace($path)) {
        Show-Info "Esta fila no contiene una ruta de archivo abrible." "RUTA"
        return
    }
    Open-SelectedPath -Path $path
}

function Invoke-GridMenuAction([string]$Action) {
    $row = $script:Grid.CurrentRow
    if (-not $row) { return }
    try {
        switch ($Action) {
            'open' { Open-SelectedGridItem }
            'path' {
                $p = Get-RowPath $row
                if ($p) { [System.Windows.Forms.Clipboard]::SetText($p); Set-Status "Ruta copiada al portapapeles." }
                else    { Set-Status "Esta fila no tiene una ruta." }
            }
            'name' { [System.Windows.Forms.Clipboard]::SetText([string]$row.Cells['elemento'].Value); Set-Status "Nombre copiado al portapapeles." }
            'row'  {
                $parts = foreach ($i in 0..3) { [string]$row.Cells[$i].Value }
                [System.Windows.Forms.Clipboard]::SetText(($parts -join ' | '))
                Set-Status "Fila copiada al portapapeles."
            }
        }
    } catch { Set-Status ("No se pudo completar la acción: " + $_.Exception.Message) }
}

function Export-GridView {
    $g = $script:Grid
    if ($null -eq $g -or $g.Rows.Count -eq 0) { Show-Info "No hay datos para exportar." "EXPORTAR"; return }
    try {
        $path = Join-Path ([Environment]::GetFolderPath("Desktop")) ("Sombrio_{0}_{1}.csv" -f $script:ActiveCat, (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine('"NIVEL","TIPO","ELEMENTO","DETALLE"')
        foreach ($r in $g.Rows) {
            $vals = foreach ($i in 0..3) { '"' + (([string]$r.Cells[$i].Value) -replace '"', '""') + '"' }
            [void]$sb.AppendLine(($vals -join ','))
        }
        [System.IO.File]::WriteAllText($path, $sb.ToString(), [System.Text.UTF8Encoding]::new($true))
        Set-Status ("Vista exportada: " + $path)
        try { Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,"' + $path + '"') } catch { }
    } catch { Show-Info ("No se pudo exportar:`n`n" + $_.Exception.Message) "EXPORTAR" }
}

function Clear-Filter {
    $script:SuppressFilter = $true
    $script:FilterText  = ""
    $script:FilterLevel = 'all'
    if ($script:TxtFilter) { $script:TxtFilter.Text = "" }
    if ($script:CmbLevel)  { $script:CmbLevel.SelectedIndex = 0 }
    $script:SuppressFilter = $false
}

# ============================================================
# PROGRESO / ESTADO
# ============================================================
function Set-Status([string]$Text) {
    if ($null -ne $script:LblStatus) { $script:LblStatus.Text = $Text }
    Invoke-UiPump
}

function Set-Progress([int]$Pct) {
    $Pct = [math]::Max(0, [math]::Min(100, $Pct))
    $script:ProgressPct = $Pct
    if ($null -ne $script:LblPct)  { $script:LblPct.Text = "$Pct%" }
    if ($null -ne $script:BarFill -and $null -ne $script:BarTrack) {
        $script:BarFill.Width = [int]($script:BarTrack.ClientSize.Width * $Pct / 100)
    }
}

function Set-Phase([int]$Step, [int]$Total, [string]$Text) {
    Set-Status $Text
    if ($Total -gt 0) { Set-Progress ([int][math]::Round((($Step - 1) / $Total) * 100)) }
    Invoke-UiPump
}

function Update-ScanMonitor {
    param(
        [long]$Scanned, [int]$Hits, [string]$CurrentFile,
        [datetime]$StartTime, [int]$Percent
    )
    $elapsed = (Get-Date) - $StartTime
    $speed = 0
    if ($elapsed.TotalSeconds -gt 0.5) { $speed = [math]::Round($Scanned / $elapsed.TotalSeconds) }
    try { $ts = $elapsed.ToString("hh\:mm\:ss") } catch { $ts = "{0:hh\:mm\:ss}" -f $elapsed }
    if ($null -ne $script:LblDetail) {
        $script:LblDetail.Text = ("{0:N0} archivos  |  {1:N0} arch/s  |  Rojos: {2}  |  {3}   >   {4}" -f $Scanned, $speed, $Hits, $ts, $CurrentFile)
    }
    Set-Progress $Percent
    Invoke-UiPump
}

function Start-ScanSession([string]$Text, [switch]$ShowPanel) {
    $script:Busy = $true
    $script:CancelRequested = $false
    foreach ($b in $script:NavButtons) {
        if ($b.Tag -notin @('panic', 'exit')) { $b.Enabled = $false }
    }
    if ($null -ne $script:BtnCancel)      { $script:BtnCancel.Visible = $true }
    if ($null -ne $script:BtnReport)      { $script:BtnReport.Visible = $false }
    if ($null -ne $script:BtnOpenSelected){ $script:BtnOpenSelected.Visible = $false }
    if ($null -ne $script:LblDetail)      { $script:LblDetail.Text = "" }
    # Mostrar el panel de resultados desde el inicio (antes quedaba la pantalla de inicio sin nada)
    if ($ShowPanel -and $null -ne $script:Grid) {
        $script:HomeArt.Visible = $false
        $script:Chips.Visible   = $false
        if ($script:FilterBar) { $script:FilterBar.Visible = $false }
        $script:Grid.Visible    = $true
        $script:Grid.Rows.Clear()
        $ri = $script:Grid.Rows.Add("INFO", "", $Text, "Los resultados aparecerán aquí al terminar el análisis...")
        $script:Grid.Rows[$ri].DefaultCellStyle.ForeColor = $script:C.Yellow
        $script:Grid.ClearSelection()
        $script:LblView.Text = "ANALIZANDO..."
    }
    Set-Progress 0
    Set-Status $Text
}

function Stop-ScanSession {
    $script:Busy = $false
    foreach ($b in $script:NavButtons) { $b.Enabled = $true }
    if ($null -ne $script:BtnCancel)      { $script:BtnCancel.Visible = $false }
    if ($script:LastReport -and (Test-Path -LiteralPath $script:LastReport) -and $null -ne $script:BtnReport) { $script:BtnReport.Visible = $true }
    if ($null -ne $script:BtnOpenSelected){ $script:BtnOpenSelected.Visible = $true }
    Invoke-UiPump
    if ($script:CloseAfter) { $script:Form.Close() }
}

# ============================================================
# VISTAS: INICIO / RESULTADOS POR CATEGORÍA
# ============================================================
$script:CatDefs = @(
    @{ Key = "Stats";      Text = "ESTADÍSTICAS" },
    @{ Key = "AntiBypass"; Text = "ANTI-BYPASS" },
    @{ Key = "Memoria";    Text = "MEMORIA" },
    @{ Key = "Prefetch";   Text = "PREFETCH" },
    @{ Key = "Papelera";   Text = "PAPELERA" },
    @{ Key = "Maliciosos"; Text = "MALICIOSOS" },
    @{ Key = "Mods";       Text = "MODS" },
    @{ Key = "Macros";     Text = "MACROS" },
    @{ Key = "Servicios";  Text = "SERVICIOS" },
    @{ Key = "Disco";      Text = "DISCO PROFUNDO" },
    @{ Key = "Historial";  Text = "HISTORIAL" },
    @{ Key = "Screenshots"; Text = "CAPTURAS (SS)" },
    @{ Key = "Browser";     Text = "NAVEGADOR" },
    @{ Key = "McLogs";      Text = "LOGS MC" }
)

function Get-CatItems([string]$Key) {
    $src = if ($script:ViewMode -eq 'registry') { $script:RegData } else { $script:CatData }
    if ($src.ContainsKey($Key) -and $src[$Key]) { return @($src[$Key]) }
    return @()
}

function Update-Chips {
    foreach ($def in $script:CatDefs) {
        $k   = $def.Key
        $btn = $script:CatButtons[$k]
        $real = @(Get-CatItems $k | Where-Object { $_ -notmatch '======' })
        $cnt  = $real.Count

        $btn.Text = if ($k -eq 'Stats') { $def.Text } else { "$($def.Text)   ·   $cnt" }

        $hasRed = $false
        if ($k -eq 'Maliciosos') { $hasRed = ($cnt -gt 0) }
        else { foreach ($it in $real) { if ((Get-ItemColor $it) -eq 'Red') { $hasRed = $true; break } } }

        $active = ($k -eq $script:ActiveCat)
        $btn.ForeColor = if ($active) { $script:C.Text } elseif ($hasRed) { $script:C.Red } else { $script:C.Muted }
        $btn.BackColor = if ($active) { $script:C.Select } else { $script:C.Panel2 }
        $btn.FlatAppearance.BorderColor = if ($active) { $script:C.Accent } elseif ($hasRed) { $script:C.RedDark } else { $script:C.Border }
    }
}

function Get-ItemLevel([string]$Item, [string]$Key) {
    $cn = if ($Key -eq 'Maliciosos') { 'Red' } else { Get-ItemColor $Item }
    if ($Key -eq 'Stats' -and $cn -ne 'Red') { return 'INFO' }
    switch ($cn) {
        'Red'    { return 'CRÍTICO' }
        'Yellow' { return 'ALERTA' }
        'Green'  { return 'OK' }
        default  { return 'INFO' }
    }
}

function Add-GridRow {
    param($G, [string]$Item, $P, [string]$Key, [string]$Level)
    $i = $G.Rows.Add($Level, $P.Tag, $P.Name, $P.Detail)
    $row = $G.Rows[$i]
    if ($Key -eq "Papelera" -and $script:RecycleMeta.ContainsKey($Item)) { $row.Tag = $script:RecycleMeta[$Item] }
    if ($P.Header) {
        # Encabezados: versión de Minecraft en verde, bloques RENOMBRADOS/SOSPECHOSOS en rojo, el resto en teal
        $row.DefaultCellStyle.ForeColor = if ($P.Name -match 'MINECRAFT') { $script:C.Green } elseif ($P.Name -match 'RENOMBRADOS|SOSPECHOSOS') { $script:C.Red } else { $script:C.TealDim }
        $row.DefaultCellStyle.Font = $script:FontBold
    } elseif ($Key -eq 'Maliciosos') {
        $row.DefaultCellStyle.ForeColor = $script:C.Red
    } else {
        $row.DefaultCellStyle.ForeColor = ConvertTo-UiColor (Get-ItemColor $Item)
    }
}

function Show-Category([string]$Key) {
    $script:ActiveCat = $Key
    $items = @(Get-CatItems $Key)
    $g = $script:Grid
    $g.SuspendLayout()
    $g.Rows.Clear()

    $text = [string]$script:FilterText
    $filtering = (-not [string]::IsNullOrWhiteSpace($text)) -or ($script:FilterLevel -ne 'all')
    $total = 0; $crit = 0; $warn = 0; $shown = 0
    $pendItem = $null; $pendP = $null

    foreach ($it in $items) {
        $str = [string]$it
        $p = Split-ReportItem $str
        if ($p.Header) {
            if ($filtering) { $pendItem = $str; $pendP = $p } else { Add-GridRow $g $str $p $Key '' }
            continue
        }
        $lvl = Get-ItemLevel $str $Key
        $total++
        if ($lvl -eq 'CRÍTICO') { $crit++ } elseif ($lvl -eq 'ALERTA') { $warn++ }
        if ($filtering) {
            if ($script:FilterLevel -eq 'red'  -and $lvl -ne 'CRÍTICO') { continue }
            if ($script:FilterLevel -eq 'warn' -and $lvl -notin @('CRÍTICO', 'ALERTA')) { continue }
            if ($text -and $str.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            if ($null -ne $pendItem) { Add-GridRow $g $pendItem $pendP $Key ''; $pendItem = $null }
        }
        Add-GridRow $g $str $p $Key $lvl
        $shown++
    }

    if ($items.Count -eq 0) {
        $i = $g.Rows.Add("OK", "", "Sin hallazgos registrados.", "---")
        $g.Rows[$i].DefaultCellStyle.ForeColor = $script:C.Green
    } elseif ($shown -eq 0 -and $filtering) {
        $i = $g.Rows.Add("INFO", "", "Ningún registro coincide con el filtro.", "Prueba con otro texto o cambia el nivel (Esc limpia el buscador).")
        $g.Rows[$i].DefaultCellStyle.ForeColor = $script:C.Muted
    }
    if ($script:LblCount) {
        $script:LblCount.Text = ("Mostrando {0} de {1}   ·   Críticos: {2}   ·   Alertas: {3}" -f $shown, $total, $crit, $warn)
        if ($items.Count -eq 0) { $script:LblCount.Text = "Sin registros en esta categoría" }
    }
    $g.ClearSelection()
    $g.ResumeLayout()
    Update-Chips
}

function Move-HomeArt {
    if ($script:HomeArt -and $script:HostPanel) {
        $script:HomeArt.Left = [math]::Max(0, [int](($script:HostPanel.ClientSize.Width  - $script:HomeArt.Width)  / 2))
        $script:HomeArt.Top  = [math]::Max(0, [int](($script:HostPanel.ClientSize.Height - $script:HomeArt.Height) / 2))
    }
}

function Show-Home {
    if ($script:BtnOpenSelected) { $script:BtnOpenSelected.Visible = $false }
    $script:Grid.Visible  = $false
    $script:Chips.Visible = $false
    if ($script:FilterBar) { $script:FilterBar.Visible = $false }
    $script:HomeArt.Visible  = $true
    $script:LblView.Text  = "CONSOLA CENTRAL DE OPERACIONES FORENSES"
    Move-HomeArt
}

function Show-Results {
    if ($script:BtnOpenSelected) { $script:BtnOpenSelected.Visible = $true }
    $script:HomeArt.Visible  = $false
    $script:Grid.Visible  = $true
    $script:Chips.Visible = $true
    Clear-Filter
    if ($script:FilterBar) { $script:FilterBar.Visible = $true }
    $script:LblView.Text  = if ($script:ViewMode -eq 'registry') { "REGISTRO DE ANÁLISIS  ·  MEMORIA ACUMULADA DE SESIÓN" } else { "PANEL DE RESULTADOS" }
    Show-Category $script:ActiveCat
}

function Publish-Results {
    param([hashtable]$Data, [string]$Focus)
    foreach ($k in $Data.Keys) { $script:CatData[$k] = @($Data[$k]) }
    $script:ViewMode  = 'live'
    $script:ActiveCat = $Focus
    Show-Results
}
# ============================================================
# EL SOMBRIO IF - MEJORAS DE INTERFAZ (bloque para pegar)
#
# DÓNDE PEGARLO: justo ANTES de la línea
#     # REPORTE FORENSE (Escritorio)
# (es decir, después de la función Publish-Results).
# Redefine funciones que ya existen (Update-Chips, Add-GridRow,
# Show-Category, Show-Results): en PowerShell gana la definición
# que aparece después, así que no hace falta borrar las originales.
#
# QUÉ AÑADE:
#   1. Columna NIVEL como insignia de color (CRÍTICO / ALERTA / OK / INFO).
#   2. Franja de tarjetas arriba de la tabla: Críticos, Alertas,
#      Elementos y VEREDICTO global (LIMPIO / REVISAR / SOSPECHOSO).
#   3. Ordenar la tabla con clic en el encabezado (NIVEL ordena por gravedad).
#   4. Punto rojo (●) en las categorías con hallazgos críticos.
#   5. Encabezado de tabla, altura de fila y líneas más limpias.
# ============================================================

# Escala de pantalla (DPI) para que los tamaños en píxeles se vean bien en pantallas 125% / 150%
$script:UiScale = 1.0
try { $gfx = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $script:UiScale = [math]::Max(1.0, $gfx.DpiY / 96.0); $gfx.Dispose() } catch { }
function Px([double]$n) { return [int][math]::Round($n * $script:UiScale) }

$script:UiEnhanced   = $false
$script:Strip        = $null
$script:StripCards   = @{}
$script:SortCol      = -1
$script:SortAsc      = $true
$script:VerdictKey   = ""
$script:VerdictCache = $null

# Mezcla dos colores (Alpha 0..1 = cuánto pesa Fg sobre Bg)
function Merge-Color([System.Drawing.Color]$Fg, [System.Drawing.Color]$Bg, [double]$Alpha) {
    $r = [int]($Bg.R + ($Fg.R - $Bg.R) * $Alpha)
    $g = [int]($Bg.G + ($Fg.G - $Bg.G) * $Alpha)
    $b = [int]($Bg.B + ($Fg.B - $Bg.B) * $Alpha)
    return [System.Drawing.Color]::FromArgb($r, $g, $b)
}

function Get-LevelRank([string]$Level) {
    switch ($Level) {
        'CRÍTICO' { return 0 }
        'ALERTA'  { return 1 }
        'INFO'    { return 2 }
        'OK'      { return 3 }
        default   { return 4 }
    }
}

function Get-LevelStyle([string]$Level) {
    $c = $script:C
    switch ($Level) {
        'CRÍTICO' { return @{ Fore = $c.Red;    Back = (Merge-Color $c.Red    $c.Panel 0.24) } }
        'ALERTA'  { return @{ Fore = $c.Yellow; Back = (Merge-Color $c.Yellow $c.Panel 0.20) } }
        'OK'      { return @{ Fore = $c.Green;  Back = (Merge-Color $c.Green  $c.Panel 0.14) } }
        default   { return @{ Fore = $c.Accent; Back = (Merge-Color $c.Accent $c.Panel 0.12) } }
    }
}

# ------------------------------------------------------------
# Veredicto global (con caché para no recalcular al cambiar de pestaña)
# ------------------------------------------------------------
function Get-GlobalVerdict {
    $key = $script:ViewMode
    $anyData = $false
    foreach ($def in $script:CatDefs) {
        $n = @(Get-CatItems $def.Key).Count
        if ($n -gt 0) { $anyData = $true }
        $key += "|$n"
    }
    if ($key -eq $script:VerdictKey -and $script:VerdictCache) { return $script:VerdictCache }

    $crit = @(Get-CatItems 'Maliciosos' | Where-Object { $_ -notmatch '======' }).Count
    $warn = 0
    if ($crit -eq 0) {
        foreach ($def in $script:CatDefs) {
            if ($def.Key -in @('Stats', 'Maliciosos')) { continue }
            foreach ($it in @(Get-CatItems $def.Key)) {
                $s = [string]$it
                if ($s -match '======') { continue }
                $cn = Get-ItemColor $s
                if ($cn -eq 'Red') { $crit++ } elseif ($cn -eq 'Yellow') { $warn++ }
            }
        }
    }

    $res = if (-not $anyData)  { @{ Text = 'SIN DATOS';    Color = 'Muted'  } }
           elseif ($crit -gt 0) { @{ Text = 'SOSPECHOSO';  Color = 'Red'    } }
           elseif ($warn -gt 0) { @{ Text = 'REVISAR';     Color = 'Yellow' } }
           else                 { @{ Text = 'LIMPIO';      Color = 'Green'  } }
    $script:VerdictKey   = $key
    $script:VerdictCache = $res
    return $res
}

# ------------------------------------------------------------
# Franja de tarjetas (se crea una sola vez, la primera vez que se muestran resultados)
# ------------------------------------------------------------
function New-StripCard([string]$Caption) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Dock = 'Fill'
    $card.Margin = [System.Windows.Forms.Padding]::new((Px 4), 0, (Px 4), 0)

    $val = New-Object System.Windows.Forms.Label
    $val.Dock = 'Fill'
    $val.TextAlign = 'MiddleLeft'
    $val.Padding = [System.Windows.Forms.Padding]::new((Px 14), 0, 0, 0)
    $val.Font = New-Object System.Drawing.Font('Segoe UI', [single]16, [System.Drawing.FontStyle]::Bold)
    $val.Text = '0'

    $cap = New-Object System.Windows.Forms.Label
    $cap.Dock = 'Top'
    $cap.Height = (Px 24)
    $cap.TextAlign = 'BottomLeft'
    $cap.Padding = [System.Windows.Forms.Padding]::new((Px 14), 0, 0, 0)
    $cap.Font = New-Object System.Drawing.Font('Segoe UI', [single]8, [System.Drawing.FontStyle]::Regular)
    $cap.Text = $Caption

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Left'
    $bar.Width = (Px 4)

    $card.Controls.Add($val)   # Fill primero
    $card.Controls.Add($cap)
    $card.Controls.Add($bar)
    return @{ Card = $card; Value = $val; Caption = $cap; Bar = $bar }
}

function Initialize-UiEnhancements {
    if ($script:UiEnhanced -or $null -eq $script:Grid) { return }
    $script:UiEnhanced = $true
    $g = $script:Grid

    # --- Estilo general de la tabla ---
    try {
        $g.EnableHeadersVisualStyles = $false
        $g.ColumnHeadersBorderStyle  = 'Single'
        $g.ColumnHeadersHeightSizeMode = 'DisableResizing'
        $g.ColumnHeadersHeight = (Px 38)
        $g.RowTemplate.Height  = (Px 32)
        $g.CellBorderStyle     = 'SingleHorizontal'
        $g.GridColor           = (Merge-Color $script:C.Border $script:C.Panel 0.5)
        $hs = $g.ColumnHeadersDefaultCellStyle
        $hs.BackColor          = $script:C.Panel2
        $hs.ForeColor          = $script:C.Muted
        $hs.SelectionBackColor = $script:C.Panel2
        $hs.SelectionForeColor = $script:C.Text
        $hs.Alignment          = 'MiddleLeft'
        $hs.Padding            = [System.Windows.Forms.Padding]::new((Px 8), 0, 0, 0)
        $hs.Font               = New-Object System.Drawing.Font('Segoe UI', [single]9, [System.Drawing.FontStyle]::Bold)
        foreach ($col in $g.Columns) { $col.SortMode = 'Programmatic' }
    } catch { }

    # --- Ordenar con clic en el encabezado ---
    try {
        $g.add_SortCompare({
            param($s, $e)
            try {
                $a = [string]$e.CellValue1; $b = [string]$e.CellValue2
                if ($e.Column.Index -eq 0) {
                    $e.SortResult = (Get-LevelRank $a) - (Get-LevelRank $b)
                } else {
                    $e.SortResult = [string]::Compare($a, $b, [StringComparison]::OrdinalIgnoreCase)
                }
                $e.Handled = $true
            } catch { }
        })
        $g.add_ColumnHeaderMouseClick({
            param($s, $e)
            try {
                if ($script:ActiveCat -eq 'Mods') {
                    Set-Status "MODS se mantiene agrupado por versión de Minecraft (no se reordena)."
                    return
                }
                if ($script:SortCol -eq $e.ColumnIndex) { $script:SortAsc = -not $script:SortAsc }
                else { $script:SortCol = $e.ColumnIndex; $script:SortAsc = $true }
                $dir = if ($script:SortAsc) { 'Ascending' } else { 'Descending' }
                foreach ($c in $s.Columns) { $c.HeaderCell.SortGlyphDirection = 'None' }
                $s.Sort($s.Columns[$e.ColumnIndex], [System.ComponentModel.ListSortDirection]$dir)
                $s.Columns[$e.ColumnIndex].HeaderCell.SortGlyphDirection = if ($script:SortAsc) { 'Ascending' } else { 'Descending' }
            } catch { }
        })
    } catch { }

    # --- Franja de tarjetas arriba de la tabla ---
    try {
        $hp = $g.Parent
        if ($hp -and $g.Dock -eq 'Fill') {
            $strip = New-Object System.Windows.Forms.TableLayoutPanel
            $strip.Dock = 'Top'
            $strip.Height = (Px 76)
            $strip.ColumnCount = 4
            $strip.RowCount = 1
            $strip.Padding = [System.Windows.Forms.Padding]::new(0, (Px 6), 0, (Px 6))
            for ($i = 0; $i -lt 4; $i++) {
                [void]$strip.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 25)))
            }
            [void]$strip.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))

            $names = @(@('Crit', 'CRÍTICOS'), @('Warn', 'ALERTAS'), @('Total', 'ELEMENTOS'), @('Verdict', 'VEREDICTO'))
            for ($i = 0; $i -lt 4; $i++) {
                $cd = New-StripCard $names[$i][1]
                $script:StripCards[$names[$i][0]] = $cd
                $strip.Controls.Add($cd.Card, $i, 0)
            }
            $hp.Controls.Add($strip)
            $script:Strip = $strip
            $strip.Visible = $g.Visible

            # La franja sigue a los chips: visible solo en el panel de resultados
            if ($script:Chips) {
                $script:Chips.add_VisibleChanged({
                    if ($script:Strip -and $script:Chips) { $script:Strip.Visible = $script:Chips.Visible }
                })
            }
        }
    } catch { $script:Strip = $null }
}

function Update-SummaryStrip([int]$Total, [int]$Crit, [int]$Warn) {
    if ($null -eq $script:Strip) { return }
    try {
        $c = $script:C
        $script:Strip.BackColor = $c.Bg
        $verdict = Get-GlobalVerdict
        $vColor = switch ($verdict.Color) { 'Red' { $c.Red } 'Yellow' { $c.Yellow } 'Green' { $c.Green } default { $c.Muted } }
        $data = @{
            Crit    = @{ Text = "$Crit";  Color = $(if ($Crit -gt 0) { $c.Red }    else { $c.Muted }) }
            Warn    = @{ Text = "$Warn";  Color = $(if ($Warn -gt 0) { $c.Yellow } else { $c.Muted }) }
            Total   = @{ Text = "$Total"; Color = $c.Accent }
            Verdict = @{ Text = $verdict.Text; Color = $vColor }
        }
        foreach ($k in $data.Keys) {
            $cd = $script:StripCards[$k]
            $cd.Card.BackColor    = $c.Panel2
            $cd.Value.BackColor   = $c.Panel2
            $cd.Caption.BackColor = $c.Panel2
            $cd.Caption.ForeColor = $c.Muted
            $cd.Value.Text        = $data[$k].Text
            $cd.Value.ForeColor   = $data[$k].Color
            $cd.Bar.BackColor     = $data[$k].Color
        }
    } catch { }
}

# ============================================================
# FUNCIONES REDEFINIDAS (sobrescriben a las originales)
# ============================================================

function Update-Chips {
    foreach ($def in $script:CatDefs) {
        $k   = $def.Key
        $btn = $script:CatButtons[$k]
        $real = @(Get-CatItems $k | Where-Object { $_ -notmatch '======' })
        $cnt  = $real.Count

        $hasRed = $false
        if ($k -eq 'Maliciosos') { $hasRed = ($cnt -gt 0) }
        else { foreach ($it in $real) { if ((Get-ItemColor $it) -eq 'Red') { $hasRed = $true; break } } }

        $label = if ($k -eq 'Stats') { $def.Text } else { "$($def.Text)   ·   $cnt" }
        if ($hasRed -and $k -ne 'Stats') { $label = "●  $label" }   # punto rojo = hay críticos
        $btn.Text = $label

        $active = ($k -eq $script:ActiveCat)
        $btn.ForeColor = if ($active) { $script:C.Text } elseif ($hasRed) { $script:C.Red } else { $script:C.Muted }
        $btn.BackColor = if ($active) { $script:C.Select } else { $script:C.Panel2 }
        $btn.FlatAppearance.BorderColor = if ($active) { $script:C.Accent } elseif ($hasRed) { $script:C.RedDark } else { $script:C.Border }
    }
}

function Add-GridRow {
    param($G, [string]$Item, $P, [string]$Key, [string]$Level)
    $i = $G.Rows.Add($Level, $P.Tag, $P.Name, $P.Detail)
    $row = $G.Rows[$i]
    if ($Key -eq "Papelera" -and $script:RecycleMeta.ContainsKey($Item)) { $row.Tag = $script:RecycleMeta[$Item] }

    if ($P.Header) {
        $row.DefaultCellStyle.ForeColor = if ($P.Name -match 'MINECRAFT') { $script:C.Green } elseif ($P.Name -match 'RENOMBRADOS|SOSPECHOSOS') { $script:C.Red } else { $script:C.TealDim }
        $row.DefaultCellStyle.BackColor = $script:C.Panel2
        $row.DefaultCellStyle.Font = $script:FontBold
        $row.Height = (Px 30)
        return
    }

    if ($Key -eq 'Maliciosos') { $row.DefaultCellStyle.ForeColor = $script:C.Red }
    else { $row.DefaultCellStyle.ForeColor = ConvertTo-UiColor (Get-ItemColor $Item) }

    # Insignia de color en la columna NIVEL
    if ($Level) {
        $st = Get-LevelStyle $Level
        $cell = $row.Cells[0]
        $cell.Style.ForeColor          = $st.Fore
        $cell.Style.BackColor          = $st.Back
        $cell.Style.SelectionForeColor = $st.Fore
        $cell.Style.SelectionBackColor = $st.Back
        $cell.Style.Alignment          = 'MiddleCenter'
        if ($script:FontBold) { $cell.Style.Font = $script:FontBold }
    }
}

function Show-Category([string]$Key) {
    $script:ActiveCat = $Key
    $items = @(Get-CatItems $Key)
    $g = $script:Grid
    $g.SuspendLayout()
    $g.Rows.Clear()

    # Al cambiar de categoría se reinicia el orden manual
    $script:SortCol = -1; $script:SortAsc = $true
    try { foreach ($c in $g.Columns) { $c.HeaderCell.SortGlyphDirection = 'None' } } catch { }

    $text = [string]$script:FilterText
    $filtering = (-not [string]::IsNullOrWhiteSpace($text)) -or ($script:FilterLevel -ne 'all')
    $total = 0; $crit = 0; $warn = 0; $shown = 0
    $pendItem = $null; $pendP = $null

    foreach ($it in $items) {
        $str = [string]$it
        $p = Split-ReportItem $str
        if ($p.Header) {
            if ($filtering) { $pendItem = $str; $pendP = $p } else { Add-GridRow $g $str $p $Key '' }
            continue
        }
        $lvl = Get-ItemLevel $str $Key
        $total++
        if ($lvl -eq 'CRÍTICO') { $crit++ } elseif ($lvl -eq 'ALERTA') { $warn++ }
        if ($filtering) {
            if ($script:FilterLevel -eq 'red'  -and $lvl -ne 'CRÍTICO') { continue }
            if ($script:FilterLevel -eq 'warn' -and $lvl -notin @('CRÍTICO', 'ALERTA')) { continue }
            if ($text -and $str.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            if ($null -ne $pendItem) { Add-GridRow $g $pendItem $pendP $Key ''; $pendItem = $null }
        }
        Add-GridRow $g $str $p $Key $lvl
        $shown++
    }

    if ($items.Count -eq 0) {
        $i = $g.Rows.Add("OK", "", "Sin hallazgos registrados.", "---")
        $g.Rows[$i].DefaultCellStyle.ForeColor = $script:C.Green
        $st = Get-LevelStyle 'OK'
        $g.Rows[$i].Cells[0].Style.ForeColor = $st.Fore
        $g.Rows[$i].Cells[0].Style.BackColor = $st.Back
        $g.Rows[$i].Cells[0].Style.Alignment = 'MiddleCenter'
    } elseif ($shown -eq 0 -and $filtering) {
        $i = $g.Rows.Add("INFO", "", "Ningún registro coincide con el filtro.", "Prueba con otro texto o cambia el nivel (Esc limpia el buscador).")
        $g.Rows[$i].DefaultCellStyle.ForeColor = $script:C.Muted
    }
    if ($script:LblCount) {
        $script:LblCount.Text = ("Mostrando {0} de {1}   ·   Críticos: {2}   ·   Alertas: {3}" -f $shown, $total, $crit, $warn)
        if ($items.Count -eq 0) { $script:LblCount.Text = "Sin registros en esta categoría" }
    }
    $g.ClearSelection()
    $g.ResumeLayout()
    Update-Chips
    Update-SummaryStrip $total $crit $warn
}

function Show-Results {
    if ($script:BtnOpenSelected) { $script:BtnOpenSelected.Visible = $true }
    Initialize-UiEnhancements
    $script:HomeArt.Visible  = $false
    $script:Grid.Visible  = $true
    $script:Chips.Visible = $true
    Clear-Filter
    if ($script:FilterBar) { $script:FilterBar.Visible = $true }
    if ($script:Strip)     { $script:Strip.Visible = $true }
    $script:LblView.Text  = if ($script:ViewMode -eq 'registry') { "REGISTRO DE ANÁLISIS  ·  MEMORIA ACUMULADA DE SESIÓN" } else { "PANEL DE RESULTADOS" }
    Show-Category $script:ActiveCat
}

# ============================================================
# FIN DEL BLOQUE DE MEJORAS
# ============================================================


# ============================================================
# REPORTE FORENSE (Escritorio)
# ============================================================
function Save-Report {
    param($Sections)
    $path = Join-Path ([Environment]::GetFolderPath("Desktop")) "Reporte_Sombrio_V79.txt"
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("===============================================================")
    [void]$sb.AppendLine(" REPORTE FORENSE - EL SOMBRIO IF V79")
    [void]$sb.AppendLine((" Fecha: {0}  |  Equipo: {1}  |  Usuario: {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:COMPUTERNAME, $env:USERNAME))
    [void]$sb.AppendLine("===============================================================")
    foreach ($title in $Sections.Keys) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("--- $title ---")
        $items = @($Sections[$title])
        if ($items.Count -eq 0) { [void]$sb.AppendLine("  (sin hallazgos)") }
        else { foreach ($it in $items) { [void]$sb.AppendLine("  $it") } }
    }
    [System.IO.File]::WriteAllText($path, $sb.ToString(), [System.Text.UTF8Encoding]::new($true))
    return $path
}

# ============================================================
# MÓDULOS DE ESCANEO
# ============================================================
function Invoke-DiskScan {
    param($Disco, $Maliciosos, $Mods = $null, [datetime]$StartTime, [int]$BasePct, [int]$SpanPct)

    $script:DiskModCount = 0

    $targetExt = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@('.jar','.zip','.exe','.dll','.ahk','.au3','.msi','.bat','.cmd','.ps1','.vbs','.scr','.hta','.com'),
        [System.StringComparer]::OrdinalIgnoreCase)

    $sysDrive = ($env:SystemDrive + "\")
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -eq 'Fixed' }

    $dirsToScan = @()
    $expectedBytes = 0L
    foreach ($drive in $drives) {
        $used = $drive.TotalSize - $drive.AvailableFreeSpace
        if ($drive.Name -eq $sysDrive) {
            $dirsToScan += "$env:USERPROFILE"
            if (Test-Path "${sysDrive}ProgramData") { $dirsToScan += "${sysDrive}ProgramData" }
            $expectedBytes += [math]::Min($used, 20000000000)   # estimación para el disco del sistema
        } else {
            $dirsToScan += $drive.RootDirectory.FullName
            $expectedBytes += $used
        }
    }
    if ($expectedBytes -lt 1000000000) { $expectedBytes = 1000000000 }

    $scannedBytes = 0L
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lastMs = 0L

    foreach ($root in $dirsToScan) {
        if ($script:CancelRequested) { break }
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $stack = [System.Collections.Generic.Stack[string]]::new()
        $stack.Push($root)

        while ($stack.Count -gt 0) {
            if ($script:CancelRequested) { break }
            $cur = $stack.Pop()
            $di  = [System.IO.DirectoryInfo]::new($cur)

            try {
                $skipDirs = @('WinSxS','node_modules','.git','\.vs','.nuget','Package Cache','WindowsApps')
                foreach ($sd in $di.GetDirectories()) {
                    if ($skipDirs | Where-Object { $sd.FullName -like "*$_*" }) { continue }
                    if (-not ($sd.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { $stack.Push($sd.FullName) }
                }
            } catch { }

            $files = $null
            try { $files = $di.GetFiles() } catch { continue }

            foreach ($f in $files) {
                $script:ScanCount++
                $scannedBytes += $f.Length

                if (($script:ScanCount % 60) -eq 0 -and ($sw.ElapsedMilliseconds - $lastMs) -gt 100) {
                    $diskPct = [math]::Min(99, [math]::Round(($scannedBytes / $expectedBytes) * 100))
                    $overall = $BasePct + [math]::Round($diskPct * $SpanPct / 100)
                    Update-ScanMonitor -Scanned $script:ScanCount -Hits $script:DeepHits `
                        -CurrentFile $f.FullName -StartTime $StartTime -Percent $overall
                    $lastMs = $sw.ElapsedMilliseconds
                    if ($script:CancelRequested) { break }
                }

                if (-not $targetExt.Contains($f.Extension)) { continue }
                $full = $f.FullName
                if ($script:RxPathWhitelist.IsMatch($full)) { continue }
                # V76 - Extensión falsa por cabecera (MZ/PK camuflado)
                $magicHit = Test-MagicMismatch -Path $full -Extension $f.Extension
                if ($magicHit) {
                    $script:DeepHits++
                    $Disco.Add("[EXTENSIÓN FALSA] $($f.Name) | Ruta: $full | Motivo: $magicHit")
                    $Maliciosos.Add("[EXTENSIÓN FALSA] $($f.Name) | Ruta: $full | Motivo: $magicHit")
                }
                # V76 - Metadatos PE internos (ejecutables renombrados)
                if ($f.Extension -in '.exe','.dll','.sys','.scr','.com') {
                    $peHit = Test-PeSuspicious -Path $full
                    if ($peHit) {
                        $script:DeepHits++
                        $Disco.Add("[ARCHIVO RENOMBRADO] $($f.Name) | Ruta: $full | Nombre interno: $peHit")
                        $Maliciosos.Add("[ARCHIVO RENOMBRADO] $($f.Name) | Ruta: $full | Nombre interno: $peHit")
                    }
                }
                # .jar de cualquier carpeta del disco = posible mod (la carpeta .minecraft\mods se audita aparte)
                $isJar = ($null -ne $Mods -and $f.Extension -eq '.jar' -and -not $full.StartsWith($script:DefaultModsPath, [StringComparison]::OrdinalIgnoreCase))
                if ($isJar) { $script:DiskModCount++ }
                # V76 - Contenido interno de .jar/.zip renombrados
                if ($f.Extension -in '.jar','.zip') {
                    $jarHit = Test-JarContentSuspicious -Path $full
                    if ($jarHit) {
                        $script:DeepHits++
                        if ($isJar) {
                            $Mods.Add("[MOD ILEGAL RENOMBRADO] $($f.Name) | Ruta: $full | Contenido: $jarHit")
                            $Maliciosos.Add("[MOD ILEGAL RENOMBRADO] $($f.Name) | Ruta: $full | Contenido: $jarHit")
                        } else {
                            $Disco.Add("[ARCHIVO RENOMBRADO] $($f.Name) | Ruta: $full | Contenido: $jarHit")
                            $Maliciosos.Add("[ARCHIVO RENOMBRADO] $($f.Name) | Ruta: $full | Contenido: $jarHit")
                        }
                    }
                }
                $hit  = ($script:RxHacks.IsMatch($f.Name) -or $script:RxMacroCritical.IsMatch($f.Name))
                $tiny = ($isJar -and $f.Length -lt 15KB -and $full -match 'mods|minecraft')
                if ($hit -or $tiny) {
                    $script:DeepHits++
                    # V76 - Alternate Data Streams ocultos (macros escondidas)
                    foreach ($ads in @(Get-SuspiciousAds -Path $full)) {
                        $Disco.Add("[ADS SOSPECHOSO] $($f.Name) | Ruta: $full | Stream: $ads")
                        $Maliciosos.Add("[ADS SOSPECHOSO] $($f.Name) | Ruta: $full | Stream: $ads")
                    }
                    if ($hit) { $Disco.Add("[ARCHIVO ILEGAL] $($f.Name) | Ruta: $full") }
                    if ($isJar) {
                        if ($hit) {
                            $Mods.Add("[MOD ILEGAL] $($f.Name) | Ruta: $full")
                            $Maliciosos.Add("[MOD ILEGAL] $($f.Name) | Ruta: $full")
                        } else {
                            $Mods.Add("[MOD SOSPECHOSO] $($f.Name) | Ruta: $full | Motivo: tamaño anómalo ($([math]::Round($f.Length/1KB,1)) KB)")
                            $Maliciosos.Add("[MOD SOSPECHOSO] $($f.Name) | Ruta: $full | Motivo: tamaño anómalo")
                        }
                    } else {
                        $Maliciosos.Add("[EN DISCO] $($f.Name) | Ruta: $full")
                    }
                } elseif ($isJar) {
                    $Mods.Add("[MOD APROBADO] $($f.Name) | Ruta: $full")
                }
            }
        }
    }
    Update-ScanMonitor -Scanned $script:ScanCount -Hits $script:DeepHits -CurrentFile "COMPLETADO" -StartTime $StartTime -Percent 100
}

function Start-GlobalScan {
    Start-ScanSession "Iniciando auditoría global..." -ShowPanel
    try {
        $memoria     = [System.Collections.Generic.List[string]]::new()
        $prefetchHoy = [System.Collections.Generic.List[string]]::new()
        $maliciosos  = [System.Collections.Generic.List[string]]::new()
        $mods        = [System.Collections.Generic.List[string]]::new()
        $macros      = [System.Collections.Generic.List[string]]::new()
        $servicios   = [System.Collections.Generic.List[string]]::new()
        $disco       = [System.Collections.Generic.List[string]]::new()
        $statsBox    = [System.Collections.Generic.List[string]]::new()
        $screenshots = [System.Collections.Generic.List[string]]::new()
        $browser     = [System.Collections.Generic.List[string]]::new()
        $mcLogs      = [System.Collections.Generic.List[string]]::new()

        $script:ScanCount = 0
        $script:DeepHits  = 0
        $script:JarVersionProbes = 0
        $script:ContentProbes   = 0
        $papeleraData = [System.Collections.Generic.List[string]]::new()
        $script:RecycleMeta = @{}
        $scanStart = Get-Date
        $cRam = 0; $cPref = 0; $cPap = 0; $cMods = 0; $cSvc = 3

        # 1 - Memoria
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 1 7 "1/7  Analizando Memoria RAM..."
                $allProcs = Get-Process -ErrorAction SilentlyContinue
                $cRam = @($allProcs).Count
                foreach ($proc in ($allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) })) {
                    $memoria.Add("[JAVA] INSTANCIA ACTIVA : $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
                }
                foreach ($proc in ($allProcs | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
                    $memoria.Add("[PROCESO MACRO MALICIOSO] $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
                    $maliciosos.Add("[EN MEMORIA] $($proc.Name).exe | PID: $($proc.Id)")
                }
                # V76 - Procesos cuyo archivo fue renombrado (metadatos PE internos)
                foreach ($proc in ($allProcs | Where-Object { $_.Path -and -not $script:RxPathWhitelist.IsMatch($_.Path) })) {
                    $viProc = Test-PeSuspicious -Path $proc.Path
                    if ($viProc) {
                        $memoria.Add("[PROCESO RENOMBRADO] $($proc.Name).exe | Nombre interno: $viProc | Ruta: $($proc.Path)")
                        $maliciosos.Add("[PROCESO RENOMBRADO] $($proc.Name).exe | Nombre interno: $viProc")
                    }
                }
                # V76 - Ventanas activas del escritorio con títulos de cheats/clients
                foreach ($wt in @(Find-CheatWindows)) {
                    if (-not $memoria.Contains("[VENTANA CHEAT] $wt")) {
                        $memoria.Add("[VENTANA CHEAT] $wt | Ruta: Ventana activa en el escritorio")
                        $maliciosos.Add("[VENTANA CHEAT] $wt")
                    }
                }
                Add-ToLog $script:LogMemoria $memoria
            } catch { }
        }

        # 2 - Prefetch
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 2 7 "2/7  Extrayendo Prefetch..."
                $hoy = (Get-Date).Date
                $pfFiles = @(Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue)
                $cPref = $pfFiles.Count
                foreach ($item in ($pfFiles | Where-Object { $_.LastWriteTime.Date -ge $hoy } | Sort-Object LastWriteTime -Descending)) {
                    if ($script:RxHacks.IsMatch($item.Name)) {
                        $prefetchHoy.Add("[PREFETCH MALICIOSO] $($item.Name) | Hora: $($item.LastWriteTime)")
                        $maliciosos.Add("[PREFETCH HACK] $($item.Name) | Hora: $($item.LastWriteTime)")
                    } else {
                        $prefetchHoy.Add("[PREFETCH] $($item.Name) | Hora: $($item.LastWriteTime)")
                    }
                }
                Add-ToLog $script:LogPrefetch $prefetchHoy
            } catch { }
        }

        # 3 - Papelera
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 3 7 "3/7  Analizando Papelera de Reciclaje..."
                $shell    = New-Object -ComObject Shell.Application
                $papelera = $shell.NameSpace(10)

                if ($papelera) {
                    $cPap = $papelera.Items().Count

                    foreach ($item in $papelera.Items()) {
                        $name = [string]$item.Name
                        $originalPath = ""
                        $deletedAt = $null
                        $recyclePath = [string]$item.Path

                        try { $originalPath = [string]$item.ExtendedProperty("System.Recycle.ItemPathDisplay") } catch { }
                        try { $deletedAt = $item.ExtendedProperty("System.Recycle.DateDeleted") } catch { }

                        if ([string]::IsNullOrWhiteSpace($originalPath)) {
                            try { $originalPath = [string]$item.ExtendedProperty("System.ItemPathDisplay") } catch { }
                        }

                        $deletedText = if ($deletedAt -is [datetime]) {
                            $deletedAt.ToString("yyyy-MM-dd HH:mm:ss")
                        } elseif ($deletedAt) {
                            [string]$deletedAt
                        } else {
                            "Fecha no disponible"
                        }

                        $entry = "[PAPELERA] $name | Ruta original: $originalPath | Eliminado: $deletedText | Papelera: $recyclePath"
                        $papeleraData.Add($entry)
                        $script:RecycleMeta[$entry] = [pscustomobject]@{
                            Name = $name
                            OriginalPath = $originalPath
                            DeletedAt = $deletedText
                            RecyclePath = $recyclePath
                            Path = $recyclePath
                        }

                        if ($script:RxHacks.IsMatch($name)) {
                            $maliciosos.Add("[PAPELERA HACK] $name | Ruta original: $originalPath | Eliminado: $deletedText")
                        }
                    }

                    Add-ToLog $script:LogPapelera $papeleraData
                }
            } catch { }
        }

        # 4 - Mods
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 4 7 "4/7  Auditando .minecraft/mods (el resto de mods del disco se detecta en el paso 7)..."
                if (Test-Path $script:DefaultModsPath) {
                    $localMods = @(Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip","*.dll" -ErrorAction SilentlyContinue)
                    $cMods = $localMods.Count
                    foreach ($mod in $localMods) {
                        $innerMod = Test-JarContentSuspicious -Path $mod.FullName
                        if ($innerMod) {
                            $mods.Add("[MOD ILEGAL RENOMBRADO] $($mod.Name) | Ruta: $($mod.FullName) | Contenido: $innerMod")
                            $maliciosos.Add("[MOD RENOMBRADO] $($mod.Name) | Ruta: $($mod.FullName) | Contenido: $innerMod")
                        } elseif ($script:RxHacks.IsMatch($mod.Name)) {
                            $mods.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                            $maliciosos.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                        } elseif ($mod.Length -lt 15KB) {
                            $mods.Add("[MOD SOSPECHOSO] $($mod.Name) | Ruta: $($mod.FullName) | Motivo: tamaño anómalo ($([math]::Round($mod.Length/1KB,1)) KB)")
                            $maliciosos.Add("[MOD SOSPECHOSO] $($mod.Name) | Ruta: $($mod.FullName) | Motivo: tamaño anómalo")
                        } else {
                            $mods.Add("[MOD APROBADO] $($mod.Name) | Ruta: $($mod.FullName)")
                        }
                    }
                }
            } catch { }
        }

        # 4b - Capturas SS estilo Ocean SS Tool
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 4 8 "4b/8  Analizando capturas de pantalla (Ocean SS)..."
                $screenshots = [System.Collections.Generic.List[string]]::new()
                # 1) Capturas en .minecraft/screenshots
                foreach ($sd in @("$env:APPDATA\.minecraft\screenshots", "$env:USERPROFILE\.minecraft\screenshots")) {
                    if (-not (Test-Path -LiteralPath $sd)) { continue }
                    foreach ($f in @(Get-ChildItem -LiteralPath $sd -File -ErrorAction SilentlyContinue)) {
                        $entry = "[SCREENSHOT] $($f.Name) | Ruta: $($f.FullName) | Fecha: $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) | Tamaño: $([math]::Round($f.Length/1KB,1)) KB"
                        if ($script:RxHacks.IsMatch($f.Name) -or $script:RxMacroCritical.IsMatch($f.Name)) {
                            $entry = "[SCREENSHOT SOSPECHOSO] $($f.Name) | Ruta: $($f.FullName) | Fecha: $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
                            $maliciosos.Add("[SCREENSHOT SOSPECHOSO] $($f.Name) | Ruta: $($f.FullName)")
                        }
                        if ($f.Length -lt 5KB -or $f.Length -gt 25MB) {
                            $screenshots.Add("[SCREENSHOT ANÓMALO] $($f.Name) | Tamaño: $([math]::Round($f.Length/1KB,1)) KB | Ruta: $($f.FullName)")
                            $maliciosos.Add("[SCREENSHOT ANÓMALO] $($f.Name) | Ruta: $($f.FullName)")
                        } else { $screenshots.Add($entry) }
                    }
                }
                # 2) Ventanas activas de clients
                foreach ($wt in @(Find-CheatWindows)) {
                    $screenshots.Add("[VENTANA CHEAT ACTIVA] $wt | Detectado en captura")
                    $maliciosos.Add("[VENTANA CHEAT ACTIVA] $wt")
                }
                # 3) Procesos de clients en memoria
                foreach ($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxHacks.IsMatch($_.Name) -or $script:RxMacroCritical.IsMatch($_.Name) })) {
                    $screenshots.Add("[PROCESO CLIENTE] $($proc.Name).exe | PID: $($proc.Id) | Ruta: $($proc.Path)")
                    $maliciosos.Add("[PROCESO CLIENTE] $($proc.Name).exe | PID: $($proc.Id)")
                }
                # 4) Archivos recientes en .minecraft (24h)
                $cutoff = (Get-Date).AddHours(-24)
                foreach ($md in @("$env:APPDATA\.minecraft", "$env:USERPROFILE\.minecraft")) {
                    if (-not (Test-Path -LiteralPath $md)) { continue }
                    foreach ($f in @(Get-ChildItem -LiteralPath $md -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $cutoff -and $_.Extension -in '.jar','.zip','.dll','.json','.txt','.cfg' })) {
                        $screenshots.Add("[ARCHIVO RECIENTE] $($f.Name) | Ruta: $($f.FullName) | Modificado: $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))")
                    }
                }
                # 5) Portapapeles
                try {
                    $clip = [System.Windows.Forms.Clipboard]::GetText()
                    if ($clip -and ($script:RxHacks.IsMatch($clip) -or $script:RxMacroCritical.IsMatch($clip))) {
                        $screenshots.Add("[PORTAPAPELES SOSPECHOSO] $clip")
                        $maliciosos.Add("[PORTAPAPELES SOSPECHOSO] $clip")
                    }
                } catch { }

                # 6) Software de grabación de pantalla / overlays (Ocean SS los detecta)
                $recorders = @("obs", "obs64", "obs32", "streamlabs", "xsplit", "bandicam", "fraps", "dxtory", "action", "shadowplay", "nvidia share", "medal", "replaymod")
                foreach ($rn in $recorders) {
                    $rp = Get-Process -Name $rn -ErrorAction SilentlyContinue
                    if ($rp) {
                        $screenshots.Add("[GRABADOR PANTALLA] $rn.exe | PID: $($rp.Id) | Puede usarse para ocultar cheats en SS")
                        $maliciosos.Add("[GRABADOR PANTALLA] $rn.exe | PID: $($rp.Id)")
                    }
                }

                # 7) Discord overlay / inyección
                foreach ($dp in @("discord", "discordptb", "discordcanary")) {
                    $dproc = Get-Process -Name $dp -ErrorAction SilentlyContinue
                    if ($dproc) {
                        $screenshots.Add("[DISCORD] $dp.exe | PID: $($dproc.Id) | Overlay activo (puede inyectar)")
                    }
                }

                # 8) Resource packs sospechosos (Xray textures)
                $rpDir = "$env:APPDATA\.minecraft\resourcepacks"
                if (Test-Path -LiteralPath $rpDir) {
                    foreach ($rp in @(Get-ChildItem -LiteralPath $rpDir -Directory -ErrorAction SilentlyContinue)) {
                        if ($script:RxHacks.IsMatch($rp.Name)) {
                            $screenshots.Add("[RESOURCE PACK SOSPECHOSO] $($rp.Name) | Ruta: $($rp.FullName)")
                            $maliciosos.Add("[RESOURCE PACK SOSPECHOSO] $($rp.Name) | Ruta: $($rp.FullName)")
                        }
                    }
                }

                # 9) Litematica / esquemáticos (puede usarse para scaffold)
                $litematica = "$env:APPDATA\.minecraft\schematics"
                if (Test-Path -LiteralPath $litematica) {
                    foreach ($sch in @(Get-ChildItem -LiteralPath $litematica -File -ErrorAction SilentlyContinue)) {
                        $screenshots.Add("[ESQUEMÁTICO] $($sch.Name) | Ruta: $($sch.FullName) | Fecha: $($sch.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))")
                    }
                }

                # 10) Múltiples instancias de Minecraft (multiclient)
                $mcProcs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'javaw?|lunarclient|minecraft' })
                if ($mcProcs.Count -gt 1) {
                    $screenshots.Add("[MULTICLIENT] $($mcProcs.Count) instancias de Minecraft detectadas")
                    $maliciosos.Add("[MULTICLIENT] $($mcProcs.Count) instancias de Minecraft")
                }
                Add-ToLog $script:LogScreenshots $screenshots
            } catch { }
        }

        # 4c - Extensiones de navegador sospechosas
        if (-not $script:CancelRequested) {
            try {
                $browser = [System.Collections.Generic.List[string]]::new()
                $extDirs = @(
                    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions",
                    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions",
                    "$env:APPDATA\Mozilla\Firefox\Profiles"
                )
                foreach ($ed in $extDirs) {
                    if (-not (Test-Path -LiteralPath $ed)) { continue }
                    foreach ($ext in @(Get-ChildItem -LiteralPath $ed -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'meteor|wurst|cheat|hack|xray' })) {
                        $browser.Add("[EXTENSIÓN SOSPECHOSA] $($ext.Name) | Ruta: $($ext.FullName)")
                        $maliciosos.Add("[EXTENSIÓN SOSPECHOSA] $($ext.Name) | Ruta: $($ext.FullName)")
                    }
                }
                Add-ToLog $script:LogBrowser $browser
            } catch { }
        }

        # 4d - Análisis de logs de Minecraft (comandos sospechosos)
        if (-not $script:CancelRequested) {
            try {
                $mcLogs = [System.Collections.Generic.List[string]]::new()
                $logDir = "$env:APPDATA\.minecraft\logs"
                if (Test-Path -LiteralPath $logDir) {
                    foreach ($lf in @(Get-ChildItem -LiteralPath $logDir -Filter '*.log' -File -ErrorAction SilentlyContinue)) {
                        $content = Get-Content -LiteralPath $lf.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -and ($script:RxHacks.IsMatch($content) -or $script:RxMacroCritical.IsMatch($content))) {
                            $mcLogs.Add("[LOG SOSPECHOSO] $($lf.Name) | Ruta: $($lf.FullName)")
                            $maliciosos.Add("[LOG SOSPECHOSO] $($lf.Name) | Ruta: $($lf.FullName)")
                        } else {
                            $mcLogs.Add("[LOG] $($lf.Name) | Ruta: $($lf.FullName) | Fecha: $($lf.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))")
                        }
                    }
                }
                Add-ToLog $script:LogMcLogs $mcLogs
            } catch { }
        }

        # 5 - Macros (V75: procesos + software instalado + startup)
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 5 7 "5/7  Verificando Macros, Autoclickers y software de periféricos..."
                foreach ($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
                    $maliciosos.Add("[EN MEMORIA] $($proc.Name).exe | PID: $($proc.Id)")
                }

                # Software de macros instalado (registro de Windows)
                $uninstKeys = @(
                    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
                )
                foreach ($app in @(Get-ItemProperty -Path $uninstKeys -ErrorAction SilentlyContinue)) {
                    $dn = [string]$app.DisplayName
                    if ([string]::IsNullOrWhiteSpace($dn)) { continue }
                    if ($script:RxPeriph.IsMatch($dn)) {
                        $macros.Add("[PERIFÉRICO ALERTA] $dn | Software de periférico instalado (puede guardar macros) | Ruta: $($app.InstallLocation)")
                    } elseif ($script:RxMacroStrict.IsMatch($dn)) {
                        $macros.Add("[SOFTWARE DE MACROS] $dn | Ruta: $($app.InstallLocation)")
                        $maliciosos.Add("[SOFTWARE DE MACROS] $dn | Ruta: $($app.InstallLocation)")
                    }
                }
                Invoke-UiPump

                # Tareas programadas (se omiten las de Microsoft)
                try {
                    foreach ($t in @(Get-ScheduledTask -ErrorAction Stop)) {
                        if ($t.TaskPath -like '\Microsoft\*') { continue }
                        $acts = (@($t.Actions) | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' '
                        $blob = "$($t.TaskName) $acts"
                        if ($script:RxMacroStrict.IsMatch($blob) -and -not $script:RxPathWhitelist.IsMatch($blob)) {
                            $macros.Add("[TAREA PROGRAMADA MACRO] $($t.TaskName) | Ruta: $($acts.Trim())")
                            $maliciosos.Add("[TAREA PROGRAMADA MACRO] $($t.TaskName) | Ruta: $($acts.Trim())")
                        }
                    }
                } catch { }

                # Servicios instalados con nombre de macro/autoclicker
                foreach ($svc in @(Get-Service -ErrorAction SilentlyContinue)) {
                    if ($script:RxMacroStrict.IsMatch("$($svc.Name) $($svc.DisplayName)")) {
                        $macros.Add("[SERVICIO MACRO] $($svc.DisplayName) | Estado: $($svc.Status)")
                        $maliciosos.Add("[SERVICIO MACRO] $($svc.DisplayName) | Estado: $($svc.Status)")
                    }
                }

                # Autoarranque: claves Run / RunOnce
                $runKeys = @(
                    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                    'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
                    'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
                )
                foreach ($rk in $runKeys) {
                    if (-not (Test-Path -Path $rk)) { continue }
                    $rkProps = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
                    if ($null -eq $rkProps) { continue }
                    foreach ($rp in $rkProps.PSObject.Properties) {
                        if ($rp.Name -like 'PS*') { continue }
                        $rv = [string]$rp.Value
                        $blob = "$($rp.Name) $rv"
                        if ($script:RxMacroStrict.IsMatch($blob) -or $script:RxHacks.IsMatch($blob)) {
                            $macros.Add("[AUTOARRANQUE] $($rp.Name) | Ruta: $rv | Clave: $rk")
                            $maliciosos.Add("[AUTOARRANQUE] $($rp.Name) | Ruta: $rv")
                        }
                    }
                }

                # Carpetas de Inicio (Startup)
                foreach ($sd in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
                    if (-not (Test-Path -LiteralPath $sd)) { continue }
                    foreach ($sf in @(Get-ChildItem -LiteralPath $sd -File -ErrorAction SilentlyContinue)) {
                        if ($script:RxMacroStrict.IsMatch($sf.Name) -or $script:RxHacks.IsMatch($sf.Name)) {
                            $macros.Add("[AUTOARRANQUE] $($sf.Name) | Ruta: $($sf.FullName)")
                            $maliciosos.Add("[AUTOARRANQUE] $($sf.Name) | Ruta: $($sf.FullName)")
                        }
                    }
                }

                # Archivos de macros en carpetas del usuario
                $macroExt = [System.Collections.Generic.HashSet[string]]::new(
                    [string[]]@('.exe', '.ahk', '.au3', '.vbs', '.scr', '.bat', '.cmd', '.ps1', '.lnk', '.jar', '.dll'),
                    [System.StringComparer]::OrdinalIgnoreCase)
                $userDirs = @(
                    "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Documents",
                    "$env:APPDATA", "$env:LOCALAPPDATA\Temp"
                )
                foreach ($ud in $userDirs) {
                    if ($script:CancelRequested) { break }
                    if (-not (Test-Path -LiteralPath $ud)) { continue }
                    Set-Status "5/7  Revisando archivos en $ud ..."
                    foreach ($mf in @(Get-ChildItem -LiteralPath $ud -Recurse -Depth 3 -File -ErrorAction SilentlyContinue)) {
                        if (-not $macroExt.Contains($mf.Extension)) { continue }
                        if ($script:RxPathWhitelist.IsMatch($mf.FullName)) { continue }
                        if ($script:RxMacroStrict.IsMatch($mf.Name)) {
                            $macros.Add("[ARCHIVO MACRO] $($mf.Name) | Ruta: $($mf.FullName)")
                            $maliciosos.Add("[ARCHIVO MACRO] $($mf.Name) | Ruta: $($mf.FullName)")
                            foreach ($adsName in @(Get-SuspiciousAds -Path $mf.FullName)) {
                                $macros.Add("[ADS SOSPECHOSO] $($mf.Name) | Ruta: $($mf.FullName) | Stream: $adsName")
                                $maliciosos.Add("[ADS SOSPECHOSO] $($mf.Name) | Ruta: $($mf.FullName) | Stream: $adsName")
                            }
                        }
                    }
                    Invoke-UiPump
                }
                Add-ToLog $script:LogMacros $macros
            } catch { }
        }

        # 6 - Servicios de Windows + historial reciente
        $historial = [System.Collections.Generic.List[string]]::new()
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 6 7 "6/7  Verificando servicios de Windows y historial reciente..."
                $cSvc = 0
                foreach ($svcName in $script:WindowsServices) {
                    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                    if ($svc) {
                        $cSvc++
                        $st = ""
                        try { $st = " | Inicio: $($svc.StartType)" } catch { }
                        if ($svc.Status -eq 'Running') {
                            $servicios.Add("[SERVICIO NORMAL] $($svc.DisplayName) ($svcName) | Estado: Running$st")
                        } else {
                            $servicios.Add("[SERVICIO ALERTA] $($svc.DisplayName) ($svcName) | Estado: $($svc.Status)$st | Un servicio detenido puede indicar manipulación")
                        }
                    } elseif (Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName") {
                        $cSvc++
                        $servicios.Add("[SERVICIO NORMAL] $svcName | Controlador del sistema presente")
                    } else {
                        $servicios.Add("[SERVICIO INFO] $svcName | No existe en este equipo")
                    }
                }

                # Registros de eventos borrados en los últimos 7 días (requiere administrador)
                foreach ($logDef in @(@('Security', 1102, 'seguridad'), @('System', 104, 'del sistema'))) {
                    try {
                        $evs = @(Get-WinEvent -FilterHashtable @{ LogName = $logDef[0]; Id = $logDef[1]; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 3 -ErrorAction Stop)
                        foreach ($ev in $evs) {
                            $servicios.Add("[ALERTA] Registro de eventos $($logDef[2]) borrado | Fecha: $($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))")
                        }
                    } catch { }
                }
                Add-ToLog $script:LogServicios $servicios

                # Historial: accesos recientes (carpeta Recent)
                $recentDir = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
                if (Test-Path -LiteralPath $recentDir) {
                    foreach ($lnk in @(Get-ChildItem -LiteralPath $recentDir -Filter '*.lnk' -File -ErrorAction SilentlyContinue)) {
                        $nm = [IO.Path]::GetFileNameWithoutExtension($lnk.Name)
                        if ($script:RxMacroStrict.IsMatch($nm) -or $script:RxHacks.IsMatch($nm)) {
                            $historial.Add("[HISTORIAL SOSPECHOSO] $nm | Último acceso: $($lnk.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) | Ruta: $($lnk.FullName)")
                        }
                    }
                }
                Add-ToLog $script:LogHistorial $historial
            } catch { }
        }

        # 7 - Disco profundo (también detecta mods fuera de .minecraft)
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 7 7 "7/7  Escaneo profundo de disco (puede tardar varios minutos)..."
                Invoke-DiskScan -Disco $disco -Maliciosos $maliciosos -Mods $mods -StartTime $scanStart -BasePct 86 -SpanPct 14
                $cMods += $script:DiskModCount
                Add-ToLog $script:LogDisco $disco
            } catch { }
        }

        # --- Consolidación de resultados ---
        Set-Status "Consolidando resultados..."
        $maliciososU = @($maliciosos | Select-Object -Unique)
        $modsGrouped = @(Group-ModsByVersion $mods)
        Add-ToLog $script:LogMods $modsGrouped

        $rxAb = 'RENOMBRADO|EXTENSIÓN FALSA|ADS SOSPECHOSO|VENTANA CHEAT|AUTOARRANQUE'
        $antiBypass = @((@($memoria) + @($mods) + @($macros) + @($disco)) | Where-Object { ([string]$_) -match $rxAb } | Select-Object -Unique)
        Add-ToLog $script:LogAntiBypass $antiBypass
        Add-ToLog $script:LogMods @($mods)

        $isAdm = Test-Administrator
        try { $elapsedTxt = ((Get-Date) - $scanStart).ToString("hh\:mm\:ss") } catch { $elapsedTxt = "-" }
        $statsBox.Add("[INFO] Fecha del análisis | $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
        $statsBox.Add("[INFO] Equipo / Usuario | $env:COMPUTERNAME / $env:USERNAME")
        $statsBox.Add("[INFO] Duración | $elapsedTxt")
        $statsBox.Add("[INFO] Procesos en memoria | $cRam")
        $statsBox.Add("[INFO] Archivos Prefetch | $cPref")
        $statsBox.Add("[INFO] Elementos en la Papelera | $cPap")
        $statsBox.Add("[INFO] Mods revisados | $cMods")
        $statsBox.Add("[INFO] Servicios de Windows revisados | $cSvc")
        $statsBox.Add("[INFO] Archivos recorridos en disco | $($script:ScanCount)")
        $statsBox.Add("[INFO] Hallazgos rojos | $($maliciososU.Count)")
        if (-not $isAdm) {
            $statsBox.Add("[ALERTA] Sin privilegios de administrador | Prefetch, servicios y registros de eventos pueden quedar incompletos")
        }
        if ($script:CancelRequested) {
            $statsBox.Add("[ALERTA] Análisis cancelado por el usuario | Los resultados son parciales")
        }

        $focus = if ($maliciososU.Count -gt 0) { 'Maliciosos' } else { 'Stats' }
        Publish-Results -Data @{
            Stats      = $statsBox
            AntiBypass = $antiBypass
            Memoria    = $memoria
            Prefetch   = $prefetchHoy
            Papelera   = $papeleraData
            Maliciosos = $maliciososU
            Mods       = $modsGrouped
            Macros     = $macros
            Servicios  = $servicios
            Disco      = $disco
            Historial  = $historial
            Screenshots = $screenshots
            Browser     = $browser
            McLogs      = $mcLogs
        } -Focus $focus

        try {
            $script:LastReport = Save-Report ([ordered]@{
                'ESTADÍSTICAS'       = @($statsBox)
                'MALICIOSOS'         = $maliciososU
                'ANTI-BYPASS'        = $antiBypass
                'MEMORIA'            = @($memoria)
                'PREFETCH (HOY)'     = @($prefetchHoy)
                'PAPELERA'           = @($papeleraData)
                'MODS'               = $modsGrouped
                'MACROS'             = @($macros)
                'SERVICIOS'          = @($servicios)
                'DISCO PROFUNDO'     = @($disco)
                'HISTORIAL'          = @($historial)
                'CAPTURAS (SS)'      = @($screenshots)
                'NAVEGADOR'          = @($browser)
                'LOGS MC'            = @($mcLogs)
            })
        } catch { }

        Set-Progress 100
        if ($script:CancelRequested) { Set-Status "Análisis cancelado. Se muestran los resultados parciales." }
        else { Set-Status ("Análisis completado  ·  {0} hallazgos rojos  ·  Duración {1}" -f $maliciososU.Count, $elapsedTxt) }
        if ($null -ne $script:LblDetail) { $script:LblDetail.Text = "Reporte guardado en el Escritorio (Reporte_Sombrio_V79.txt). Ctrl+E exporta la vista actual a CSV." }
    } catch {
        Show-Info ("Error durante el análisis:`n`n" + $_.Exception.Message) "ERROR"
    } finally {
        Stop-ScanSession
    }
}

# ============================================================
# EXPRESIONES AUXILIARES (macros reales vs. software de periféricos)
# ============================================================
$script:RxPeriph = [regex]::new('lghub|\bg hub\b|logitech gaming|synapse|\bicue\b|steelseries|bloody7|a4tech|redragon', $script:RxOpts)
$script:RxMacroStrict = [regex]::new((($script:MacroAutoclickCritical | Where-Object { $_ -notmatch 'logitech|lghub|g hub|synapse|icue|steelseries|bloody7|a4tech|redragon' }) -join '|'), $script:RxOpts)

# ============================================================
# REGISTRO DE SESIÓN (memoria acumulada de todos los análisis)
# ============================================================
function Show-Registry {
    if ($script:Busy) { return }
    $logs = [ordered]@{
        Memoria    = $script:LogMemoria
        Prefetch   = $script:LogPrefetch
        Papelera   = $script:LogPapelera
        Macros     = $script:LogMacros
        Servicios  = $script:LogServicios
        Disco      = $script:LogDisco
        Historial  = $script:LogHistorial
        AntiBypass = $script:LogAntiBypass
    }
    $total = 0
    foreach ($k in $logs.Keys) { $total += $logs[$k].Count }
    $total += $script:LogMods.Count
    if ($total -eq 0) {
        Show-Info "El registro de sesión está vacío.`n`nEjecuta primero la auditoría global (F5)." "REGISTRO"
        return
    }
    $reg = @{}
    foreach ($k in $logs.Keys) { $reg[$k] = @($logs[$k]) }
    $reg['Mods'] = @(Group-ModsByVersion @($script:LogMods))

    $red = [System.Collections.Generic.List[string]]::new()
    foreach ($k in @('Memoria', 'Macros', 'Disco', 'Historial', 'AntiBypass')) {
        foreach ($it in $reg[$k]) { if ((Get-ItemColor ([string]$it)) -eq 'Red' -and -not $red.Contains([string]$it)) { $red.Add([string]$it) } }
    }
    foreach ($it in $script:LogMods) { if ((Get-ItemColor ([string]$it)) -eq 'Red' -and -not $red.Contains([string]$it)) { $red.Add([string]$it) } }
    $reg['Maliciosos'] = @($red)
    $reg['Stats'] = @(
        "[INFO] Registro acumulado de la sesión | Memoria de todos los análisis hechos desde que se abrió la app",
        "[INFO] Hallazgos rojos acumulados | $($red.Count)",
        "[INFO] Entradas en total | $total"
    )
    $script:RegData   = $reg
    $script:ViewMode  = 'registry'
    $script:ActiveCat = if ($red.Count -gt 0) { 'Maliciosos' } else { 'Stats' }
    Show-Results
}

# ============================================================
# HERRAMIENTAS EXTERNAS
# ============================================================
function Confirm-Action([string]$Text, [string]$Title = "CONFIRMAR") {
    return ([System.Windows.Forms.MessageBox]::Show($Text, $Title, 'YesNo', 'Question') -eq 'Yes')
}

function Get-FileMagic([string]$Path) {
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try { $b = [byte[]]::new(2); [void]$fs.Read($b, 0, 2); return [System.Text.Encoding]::ASCII.GetString($b) } finally { $fs.Dispose() }
    } catch { return "" }
}

function Start-DoomsdayTool {
    if (-not (Confirm-Action "Se ejecutará el Doomsday Detector descargándolo desde:`n$($script:DoomsdayUrl)`n`nSe abrirá en una ventana de PowerShell.`n`n¿Continuar?" "DOOMSDAY DETECTOR")) { return }
    try {
        Set-Status "Abriendo Doomsday Detector..."
        # Equivale a: Set-ExecutionPolicy -Scope Process Bypass; iex (irm <url>)
        # Se descarga forzando UTF-8 para que no se rompan los acentos en PowerShell 5.1.
        $cmd = "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; " +
               "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " +
               "`$wc = New-Object Net.WebClient; `$wc.Encoding = [System.Text.Encoding]::UTF8; " +
               "Invoke-Expression (`$wc.DownloadString('$($script:DoomsdayUrl)'))"
        $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
        $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $psExe)) { $psExe = 'powershell.exe' }
        Start-Process -FilePath $psExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -EncodedCommand $enc"
        Set-Status "Doomsday Detector abierto en otra ventana."
    } catch {
        Show-Info ("No se pudo abrir el Doomsday Detector:`n`n" + $_.Exception.Message) "DOOMSDAY DETECTOR"
        Set-Status "Error al abrir el Doomsday Detector."
    }
}

function Start-SystemInformerTool {
    if (-not (Confirm-Action "Se descargará System Informer desde SourceForge.`n`n¿Continuar?" "SYSTEM INFORMER")) { return }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-Status "Descargando System Informer..."
        $dl = Join-Path $env:TEMP 'SystemInformer_download.bin'
        Invoke-WebRequest -Uri $script:SystemInformerUrl -OutFile $dl -UseBasicParsing -UserAgent 'Wget/1.21' -MaximumRedirection 10
        $magic = Get-FileMagic $dl
        if ($magic -eq 'PK') {
            $dest = Join-Path $env:TEMP 'SystemInformer'
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -LiteralPath $dl -DestinationPath $dest -Force
            $exe = Get-ChildItem -LiteralPath $dest -Recurse -Filter 'SystemInformer.exe' -File -ErrorAction SilentlyContinue |
                   Sort-Object { if ($_.FullName -match 'amd64|x64') { 0 } else { 1 } } | Select-Object -First 1
            if ($exe) { Start-Process -FilePath $exe.FullName; Set-Status "System Informer abierto." }
            else { Show-Info "Se descargó el paquete pero no se encontró SystemInformer.exe." "SYSTEM INFORMER" }
        } elseif ($magic -eq 'MZ') {
            $exePath = Join-Path $env:TEMP 'SystemInformer_setup.exe'
            Copy-Item -LiteralPath $dl -Destination $exePath -Force
            Start-Process -FilePath $exePath
            Set-Status "Instalador de System Informer abierto."
        } else {
            Show-Info "La descarga no es un archivo válido (SourceForge pudo devolver una página web)." "SYSTEM INFORMER"
        }
    } catch {
        Show-Info ("No se pudo descargar System Informer:`n`n" + $_.Exception.Message) "SYSTEM INFORMER"
        Set-Status "Error al descargar System Informer."
    }
}

function Start-JournalTraceTool {
    if (-not (Confirm-Action "Se descargará JournalTrace desde GitHub:`n$($script:JournalTraceUrl)`n`n¿Continuar?" "JOURNALTRACE")) { return }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-Status "Descargando JournalTrace..."
        $exePath = Join-Path $env:TEMP 'JournalTrace.exe'
        Invoke-WebRequest -Uri $script:JournalTraceUrl -OutFile $exePath -UseBasicParsing
        if ((Get-FileMagic $exePath) -ne 'MZ') { Show-Info "La descarga no es un ejecutable válido." "JOURNALTRACE"; return }
        Start-Process -FilePath $exePath
        Set-Status "JournalTrace abierto."
    } catch {
        Show-Info ("No se pudo abrir JournalTrace:`n`n" + $_.Exception.Message) "JOURNALTRACE"
        Set-Status "Error al abrir JournalTrace."
    }
}

function Start-LilithTool {
    if (-not (Confirm-Action "Se ejecutará Lilith Services (lilith-ps) descargándolo desde:`n$($script:LilithServicesUrl)`n`nSe abrirá en una ventana de PowerShell.`n`n¿Continuar?" "LILITH SERVICES")) { return }
    try {
        $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm '$($script:LilithServicesUrl)' | iex"
        $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -EncodedCommand $enc"
        Set-Status "Lilith Services abierto en otra ventana."
    } catch {
        Show-Info ("No se pudo abrir Lilith Services:`n`n" + $_.Exception.Message) "LILITH SERVICES"
    }
}


# ============================================================
# MENÚ "SELECCIONA UNA HERRAMIENTA" (2 aplicaciones)
# ============================================================
function Show-ToolsMenu {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "HERRAMIENTAS"
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $script:C.Bg
    $dlg.ClientSize = New-Object System.Drawing.Size((Px 400), (Px 214))

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Selecciona una herramienta (se descarga y ejecuta)"
    $lbl.ForeColor = $script:C.Red
    $lbl.Font = $script:FontBase
    $lbl.TextAlign = 'MiddleCenter'
    $lbl.SetBounds((Px 10), (Px 10), (Px 380), (Px 28))
    $dlg.Controls.Add($lbl)

    $defs = @(
        @{ Text = "System Informer  (descargar y ejecutar)"; Id = 'sysinformer' },
        @{ Text = "JournalTrace  (descargar y ejecutar)";    Id = 'journal' }
    )
    $y = 46
    foreach ($d in $defs) {
        $b = New-FlatButton $d.Text 360 40
        $b.Location = New-Object System.Drawing.Point((Px 20), (Px $y))
        $b.FlatAppearance.BorderColor = $script:C.Red
        $b.Tag = $d.Id
        $b.Add_Click({ param($s,$e) $id = [string]$s.Tag; $s.FindForm().Close(); Invoke-NavAction $id })
        $dlg.Controls.Add($b)
        $y += 50
    }
    $bc = New-FlatButton "Cerrar" 360 34
    $bc.Location = New-Object System.Drawing.Point((Px 20), (Px $y))
    $bc.ForeColor = $script:C.Muted
    $bc.Add_Click({ param($s,$e) $s.FindForm().Close() })
    $dlg.Controls.Add($bc)
    $dlg.CancelButton = $bc
    [void]$dlg.ShowDialog($script:Form)
    $dlg.Dispose()
}

# ============================================================
# REVISIÓN MANUAL (equivale a los comandos Win+R)
# ============================================================
function Get-ManualChecks {
    $la = $env:LOCALAPPDATA
    return @(
        @{ Cmd = 'C:\$Recycle.Bin';                                            Info = 'Archivos eliminados';                                   Kind = 'folder'; Target = 'C:\$Recycle.Bin' },
        @{ Cmd = 'regedit';                                                    Info = 'Registro de Windows';                                   Kind = 'exe';    Target = 'regedit.exe' },
        @{ Cmd = 'prefetch';                                                   Info = 'Programas ejecutados (requiere SysMain y EnablePrefetcher activos) -> Javaw.pf'; Kind = 'folder'; Target = "$env:SystemRoot\Prefetch" },
        @{ Cmd = '%temp%';                                                     Info = 'JNativeHook -> dependencia de autoclickers viejos';     Kind = 'folder'; Target = $env:TEMP },
        @{ Cmd = '%appdata%\.minecraft';                                       Info = 'mods / versions / logs / resourcepacks: buscar hacked client, xray, mods ilegales'; Kind = 'folder'; Target = "$env:APPDATA\.minecraft" },
        @{ Cmd = 'shell:recent';                                               Info = 'Archivos ejecutados recientemente';                     Kind = 'shell';  Target = 'shell:recent' },
        @{ Cmd = '...\PowerShell\PSReadLine';                                  Info = 'Historial de comandos de PowerShell';                   Kind = 'folder'; Target = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine" },
        @{ Cmd = 'msinfo32';                                                   Info = 'Información del sistema: Virtual Machine = BAN';        Kind = 'exe';    Target = 'msinfo32.exe' },
        @{ Cmd = 'C:\Windows\System32\drivers\etc';                            Info = 'Archivo hosts: dominios bloqueados';                    Kind = 'folder'; Target = "$env:SystemRoot\System32\drivers\etc" },
        @{ Cmd = '%LOCALAPPDATA%\Microsoft\Windows\History';                   Info = 'Páginas y archivos ejecutados (historial)';             Kind = 'folder'; Target = "$la\Microsoft\Windows\History" },
        @{ Cmd = 'OCEAN SS - Capturas';                                       Info = 'Abrir carpeta de capturas de Minecraft para revisión manual'; Kind = 'folder'; Target = "$env:APPDATA\.minecraft\screenshots" },
        @{ Cmd = 'OCEAN SS - Resource Packs';                                 Info = 'Revisar resource packs (posible Xray textures)';         Kind = 'folder'; Target = "$env:APPDATA\.minecraft\resourcepacks" },
        @{ Cmd = 'OCEAN SS - Schematics';                                     Info = 'Revisar esquemáticos Litematica (scaffold)';            Kind = 'folder'; Target = "$env:APPDATA\.minecraft\schematics" },
        @{ Cmd = 'OCEAN SS - Mods';                                           Info = 'Revisar mods manualmente';                              Kind = 'folder'; Target = "$env:APPDATA\.minecraft\mods" },
        @{ Cmd = 'OCEAN SS - Config';                                         Info = 'Revisar configs de clients (Meteor, Wurst, etc.)';      Kind = 'folder'; Target = "$env:APPDATA\.minecraft\config" }
    )
}

function Invoke-ManualCheck($Check) {
    try {
        switch ($Check.Kind) {
            'exe'    { Start-Process -FilePath $Check.Target }
            'shell'  { Start-Process -FilePath 'explorer.exe' -ArgumentList $Check.Target }
            'folder' {
                if (Test-Path -LiteralPath $Check.Target -ErrorAction SilentlyContinue) {
                    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $Check.Target + '"')
                } elseif ($Check.Target -like '*$Recycle.Bin*') {
                    Start-Process -FilePath 'explorer.exe' -ArgumentList 'shell:RecycleBinFolder'   # alternativa si no hay acceso a la carpeta real
                } else {
                    Show-Info "No existe o no se puede acceder a:`n$($Check.Target)" "REVISIÓN MANUAL"
                }
            }
        }
    } catch {
        Show-Info ("No se pudo abrir:`n$($Check.Target)`n`n" + $_.Exception.Message) "REVISIÓN MANUAL"
    }
}

function Show-ManualChecks {
    $checks = Get-ManualChecks
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "REVISIÓN MANUAL (Win+R)"
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.BackColor = $script:C.Bg
    $dlg.ClientSize = New-Object System.Drawing.Size((Px 760), (Px 560))

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Revisión manual: abre cada ubicación directamente"
    $title.ForeColor = $script:C.Red; $title.Font = $script:FontBold
    $title.SetBounds((Px 16), (Px 10), (Px 728), (Px 26))
    $dlg.Controls.Add($title)

    $pnl = New-Object System.Windows.Forms.Panel
    $pnl.SetBounds((Px 10), (Px 42), (Px 740), (Px 462))
    $pnl.AutoScroll = $true
    $pnl.BackColor = $script:C.Panel
    $dlg.Controls.Add($pnl)

    $y = 6
    foreach ($c in $checks) {
        $b = New-FlatButton "Abrir" 70 34
        $b.Location = New-Object System.Drawing.Point((Px 8), (Px $y))
        $b.Tag = $c
        $b.Add_Click({ param($s,$e) Invoke-ManualCheck $s.Tag })
        $pnl.Controls.Add($b)

        $l1 = New-Object System.Windows.Forms.Label
        $l1.Text = "Win+R  ›  " + $c.Cmd
        $l1.Font = $script:FontBold; $l1.ForeColor = $script:C.Accent
        $l1.AutoEllipsis = $true
        $l1.SetBounds((Px 90), (Px $y), (Px 630), (Px 18))
        $pnl.Controls.Add($l1)

        $l2 = New-Object System.Windows.Forms.Label
        $l2.Text = $c.Info
        $l2.Font = $script:FontBase; $l2.ForeColor = $script:C.Muted
        $l2.AutoEllipsis = $true
        $l2.SetBounds((Px 90), (Px ($y + 18)), (Px 630), (Px 18))
        $pnl.Controls.Add($l2)

        $y += 44
    }

    $bc = New-FlatButton "Cerrar" 120 32
    $bc.Location = New-Object System.Drawing.Point((Px 630), (Px 516))
    $bc.Add_Click({ param($s,$e) $s.FindForm().Close() })
    $dlg.Controls.Add($bc)
    $dlg.CancelButton = $bc
    [void]$dlg.ShowDialog($script:Form)
    $dlg.Dispose()
}

function Switch-Theme {
    $order = @('Noche', 'Neon', 'Pro', 'Slate', 'Sombrio', 'Ocean')
    $idx = [array]::IndexOf($order, $script:ThemeName)
    $new = $order[($idx + 1) % $order.Count]
    try {
        $dir = Split-Path -Path $script:ThemeFile -Parent
        if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
        Set-Content -LiteralPath $script:ThemeFile -Value $new -Encoding UTF8
        Show-Info "Tema '$new' guardado.`n`nCierra y vuelve a abrir la aplicación para verlo aplicado.`n(Temas: Noche, Neon, Pro, Slate, Sombrio, Ocean)" "TEMA"
    } catch {
        Show-Info ("No se pudo guardar el tema:`n`n" + $_.Exception.Message) "TEMA"
    }
}

function Set-NavActive([string]$Id) {
    $script:NavActive = $Id
    foreach ($b in $script:NavButtons) {
        $b.BackColor = $script:C.Panel
        $b.Invalidate()
    }
}

function Invoke-Panic {
    $script:CancelRequested = $true
    $script:CloseAfter = $true
    if ($script:Busy) { Set-Status "Cerrando: se está terminando el archivo en curso..." }
    else { $script:Form.Close() }
}

function Invoke-NavAction([string]$Id) {
    try {
        if ($Id -in @('global', 'live', 'registry', 'manual')) { Set-NavActive $Id }
        switch ($Id) {
            'global'      { if (-not $script:Busy) { Start-GlobalScan } }
            'live'        {
                if ($script:Busy) { return }
                if ($script:CatData.Count -gt 0) { $script:ViewMode = 'live'; Show-Results }
                else { Show-Info "Todavía no hay resultados.`n`nEjecuta primero la auditoría global (F5)." "RESULTADOS" }
            }
            'registry'    { Show-Registry }
            'doomsday'    { if (-not $script:Busy) { Start-DoomsdayTool } }
            'sysinformer' { if (-not $script:Busy) { Start-SystemInformerTool } }
            'journal'     { if (-not $script:Busy) { Start-JournalTraceTool } }
            'lilith'      { if (-not $script:Busy) { Start-LilithTool } }
            'tools'       { if (-not $script:Busy) { Show-ToolsDropdown } }
            'manual'      { Show-ManualChecks }
            'theme'       { Switch-Theme }
            'prank'       { if (-not $script:Busy) { Show-PrankScreen } }
            'panic'       { Invoke-Panic }
            'exit'        { $script:Form.Close() }
        }
    } catch {
        Show-Info ("Ocurrió un error:`n`n" + $_.Exception.Message) "EL SOMBRIO IF"
    }
}

function Update-FilterView {
    if ($script:SuppressFilter) { return }
    if ($script:Grid -and $script:Grid.Visible -and $script:FilterBar -and $script:FilterBar.Visible) { Show-Category $script:ActiveCat }
}

# ============================================================
# BROMA: HACKEO FALSO (100% inofensivo)
#   - No escribe archivos, no envía datos, no toca el sistema.
#   - Solo muestra una pantalla: alerta (3 s) > terminal falsa (15 s) > calavera (6 s).
#   - Esc o clic en cualquier momento la cierra. Se cierra sola a los ~24 s.
#   - Única conexión: consulta tu IP pública a api.ipify.org (solo para mostrarla).
#
# DÓNDE PEGARLO: justo ANTES de la línea
#     # CONSTRUCCIÓN DE LA VENTANA
# ============================================================

$script:Pr = $null

$script:RainSource = @'
using System;
using System.Drawing;
public class SombrioRain : IDisposable {
    int cols, rows, cw, ch;
    double[] heads, speeds;
    int[] lens;
    char[][] chars;
    Random rnd = new Random();
    SolidBrush[] bright = new SolidBrush[10];
    SolidBrush[] dim = new SolidBrush[10];
    Font font;
    const string Glyphs = "0123456789012345678901ABCDEF$#%@";
    char G() { return Glyphs[rnd.Next(Glyphs.Length)]; }
    void Reset(int i, bool initial) {
        heads[i] = initial ? -rnd.NextDouble() * rows : -rnd.Next(1, 10);
        speeds[i] = 0.25 + rnd.NextDouble() * 0.75;
        lens[i] = 8 + rnd.Next(14);
    }
    public SombrioRain(int width, int height, int cellW, int cellH, float fontPx) {
        cw = cellW; ch = cellH;
        cols = width / cw + 1; rows = height / ch + 1;
        heads = new double[cols]; speeds = new double[cols]; lens = new int[cols];
        chars = new char[cols][];
        for (int i = 0; i < cols; i++) {
            chars[i] = new char[rows];
            for (int r = 0; r < rows; r++) chars[i][r] = G();
            Reset(i, true);
        }
        for (int k = 0; k < 10; k++) {
            int gr = 30 + k * 21;
            bright[k] = new SolidBrush(k == 9 ? Color.FromArgb(215, 255, 225) : Color.FromArgb(0, gr, 12));
            dim[k]    = new SolidBrush(k == 9 ? Color.FromArgb(110, 160, 120) : Color.FromArgb(0, (int)(gr * 0.45), 6));
        }
        font = new Font("Consolas", fontPx, FontStyle.Bold, GraphicsUnit.Pixel);
    }
    public void Update() {
        for (int i = 0; i < cols; i++) {
            heads[i] += speeds[i];
            if (heads[i] - lens[i] > rows) Reset(i, false);
        }
        for (int m = 0; m < cols; m++) chars[rnd.Next(cols)][rnd.Next(rows)] = G();
    }
    public void Draw(Graphics g, bool dimmed) {
        SolidBrush[] br = dimmed ? dim : bright;
        for (int i = 0; i < cols; i++) {
            int head = (int)Math.Floor(heads[i]);
            int len = lens[i];
            for (int k = 0; k < len; k++) {
                int r = head - k;
                if (r < 0 || r >= rows) continue;
                int idx = (k == 0) ? 9 : Math.Max(0, 8 - (int)((double)k / len * 9));
                g.DrawString(chars[i][r].ToString(), font, br[idx], i * cw, r * ch);
            }
        }
    }
    public void Dispose() {
        for (int k = 0; k < 10; k++) { bright[k].Dispose(); dim[k].Dispose(); }
        font.Dispose();
    }
}
'@

# ------------------------------------------------------------
# IPs (solo para mostrarlas en pantalla)
# ------------------------------------------------------------
function Get-PrankIps {
    $local = "192.168.0.1"
    try {
        $ua = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
            ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
            Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        if ($ua) { $local = $ua.Address.IPAddressToString }
    } catch { }
    $pub = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $req = [System.Net.HttpWebRequest]::Create('https://api.ipify.org')
        $req.Timeout = 2500
        $req.UserAgent = 'Mozilla/5.0'
        $resp = $req.GetResponse()
        try {
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $pub = $sr.ReadToEnd().Trim()
        } finally { $resp.Close() }
        if ($pub -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { $pub = $null }
    } catch { $pub = $null }
    return @{ Local = $local; Public = $pub }
}

# ------------------------------------------------------------
# Calavera dibujada una sola vez en un Bitmap (nítida a cualquier resolución)
# ------------------------------------------------------------
function New-RoundRectPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return ,$p
}

function New-PrankSkullBitmap([int]$BoxH) {
    $sc  = $BoxH / 180.0
    $bw  = [int][math]::Ceiling(132 * $sc)
    $bmp = New-Object System.Drawing.Bitmap($bw, $BoxH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $col = [System.Drawing.Color]
    try {
        $g.SmoothingMode = 'AntiAlias'
        $g.ScaleTransform([single]$sc, [single]$sc)
        $g.TranslateTransform(16, 10)

        $boneC = $col::FromArgb(255, 226, 248, 232)
        $bone  = New-Object System.Drawing.SolidBrush($boneC)
        $blk   = New-Object System.Drawing.SolidBrush($col::FromArgb(255, 4, 8, 6))

        $cran = New-Object System.Drawing.Drawing2D.GraphicsPath
        $cran.AddEllipse(10, 4, 80, 76)
        $jaw  = New-RoundRectPath 27 68 46 34 9
        $bones = @(@(4, 108, 96, 150), @(96, 108, 4, 150))

        # Resplandor verde detrás de todo
        foreach ($wd in 26, 18, 11, 6) {
            $gp = New-Object System.Drawing.Pen($col::FromArgb(34, 0, 255, 110), [single]$wd)
            $gp.LineJoin = 'Round'; $gp.StartCap = 'Round'; $gp.EndCap = 'Round'
            foreach ($l in $bones) { $g.DrawLine($gp, [single]$l[0], [single]$l[1], [single]$l[2], [single]$l[3]) }
            $g.DrawPath($gp, $cran)
            $g.DrawPath($gp, $jaw)
            $gp.Dispose()
        }

        # Huesos cruzados con extremos redondeados (dos nudillos por punta)
        $bp = New-Object System.Drawing.Pen($boneC, [single]9)
        $bp.StartCap = 'Round'; $bp.EndCap = 'Round'
        foreach ($l in $bones) {
            $g.DrawLine($bp, [single]$l[0], [single]$l[1], [single]$l[2], [single]$l[3])
            $dx = $l[2] - $l[0]; $dy = $l[3] - $l[1]
            $len = [math]::Sqrt($dx * $dx + $dy * $dy)
            $px = -$dy / $len; $py = $dx / $len
            foreach ($pt in @(@($l[0], $l[1]), @($l[2], $l[3]))) {
                foreach ($sg in -1, 1) {
                    $cx = $pt[0] + $px * 5 * $sg; $cy = $pt[1] + $py * 5 * $sg
                    $g.FillEllipse($bone, [single]($cx - 6.5), [single]($cy - 6.5), [single]13, [single]13)
                }
            }
        }
        $bp.Dispose()

        # Cráneo y mandíbula
        $g.FillPath($bone, $cran)
        $g.FillPath($bone, $jaw)
        $edge = New-Object System.Drawing.Pen($col::FromArgb(170, 30, 80, 55), [single]1.2)
        $g.DrawPath($edge, $cran); $g.DrawPath($edge, $jaw)
        $edge.Dispose()

        # Sombras de las sienes y pómulos para dar volumen
        $sh = New-Object System.Drawing.SolidBrush($col::FromArgb(70, 110, 160, 130))
        $g.FillEllipse($sh, 12, 28, 14, 32)
        $g.FillEllipse($sh, 74, 28, 14, 32)
        $g.FillEllipse($sh, 24, 62, 14, 12)
        $g.FillEllipse($sh, 62, 62, 14, 12)
        $sh.Dispose()

        # Grieta
        $crackPen = New-Object System.Drawing.Pen($col::FromArgb(200, 55, 85, 68), [single]1.4)
        $crack = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new(63, 5), [System.Drawing.PointF]::new(58, 15),
            [System.Drawing.PointF]::new(66, 22), [System.Drawing.PointF]::new(60, 31),
            [System.Drawing.PointF]::new(64, 36))
        $g.DrawLines($crackPen, $crack)
        $crackPen.Dispose()

        # Cuencas de los ojos con brillo rojo
        $g.FillEllipse($blk, 19, 36, 27, 29)
        $g.FillEllipse($blk, 54, 36, 27, 29)
        $glowEye = New-Object System.Drawing.SolidBrush($col::FromArgb(70, 255, 40, 50))
        $pupil   = New-Object System.Drawing.SolidBrush($col::FromArgb(255, 255, 50, 60))
        foreach ($ex in 32.5, 67.5) {
            $g.FillEllipse($glowEye, [single]($ex - 8), [single]41, [single]16, [single]19)
            $g.FillEllipse($pupil,   [single]($ex - 3), [single]46, [single]6,  [single]8)
        }
        $glowEye.Dispose(); $pupil.Dispose()

        # Nariz
        $nose = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new(50, 60), [System.Drawing.PointF]::new(43, 77),
            [System.Drawing.PointF]::new(47, 79), [System.Drawing.PointF]::new(50, 75),
            [System.Drawing.PointF]::new(53, 79), [System.Drawing.PointF]::new(57, 77))
        $g.FillPolygon($blk, $nose)

        # Dientes (6 arriba, 6 abajo)
        $g.FillRectangle($blk, 29, 81, 42, 19)
        for ($i = 0; $i -lt 6; $i++) {
            $tx = 30 + $i * 6.7
            $g.FillRectangle($bone, [single]$tx, [single]82.5, [single]6.2, [single]8.5)
            $g.FillRectangle($bone, [single]$tx, [single]91.5, [single]6.2, [single]7.5)
        }

        $bone.Dispose(); $blk.Dispose(); $cran.Dispose(); $jaw.Dispose()
    } finally { $g.Dispose() }
    return ,$bmp
}

# ------------------------------------------------------------
# Ventanitas emergentes de susto (falsas, se cierran con un clic; Esc cierra todo)
# ------------------------------------------------------------
function New-PrankPopup($Pr, [string]$Title, [string]$Body, [bool]$WithBar, [int]$PosX = -1, [int]$PosY = -1) {
    $col = [System.Drawing.Color]
    $pw = [math]::Max([int]($Pr.W * 0.21), (Px 300))
    $ph = [math]::Max([int]($Pr.H * 0.17), (Px 130))
    $x = $PosX; $y = $PosY
    if ($x -lt 0) { $x = $Pr.X0 + $Pr.Rnd.Next(0, [math]::Max(1, $Pr.W - $pw)) }
    if ($y -lt 0) { $y = $Pr.Y0 + $Pr.Rnd.Next(0, [math]::Max(1, $Pr.H - $ph)) }

    $pf = New-Object System.Windows.Forms.Form
    $pf.FormBorderStyle = 'None'
    $pf.StartPosition = 'Manual'
    $pf.Bounds = New-Object System.Drawing.Rectangle($x, $y, $pw, $ph)
    $pf.BackColor = $col::FromArgb(255, 40, 50)
    $pf.Padding = [System.Windows.Forms.Padding]::new(2)
    $pf.ShowInTaskbar = $false
    $pf.TopMost = $true
    $pf.KeyPreview = $true

    $inner = New-Object System.Windows.Forms.Panel
    $inner.Dock = 'Fill'
    $inner.BackColor = $col::FromArgb(4, 10, 6)

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Bottom'
    $bar.Height = (Px 12)
    $bar.BackColor = $col::FromArgb(0, 60, 28)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.Dock = 'Left'
    $fill.Width = 0
    $fill.BackColor = $col::FromArgb(0, 255, 110)
    $bar.Controls.Add($fill)
    $bar.Visible = $WithBar

    $lb = New-Object System.Windows.Forms.Label
    $lb.Dock = 'Fill'
    $lb.Padding = [System.Windows.Forms.Padding]::new((Px 10), (Px 8), (Px 8), (Px 4))
    $lb.ForeColor = $col::FromArgb(0, 255, 110)
    $lb.Font = New-Object System.Drawing.Font('Consolas', [single]10.5, [System.Drawing.FontStyle]::Bold)
    $lb.Text = $Body

    $tt = New-Object System.Windows.Forms.Label
    $tt.Dock = 'Top'
    $tt.Height = (Px 26)
    $tt.BackColor = $col::FromArgb(190, 20, 34)
    $tt.ForeColor = $col::White
    $tt.TextAlign = 'MiddleLeft'
    $tt.Padding = [System.Windows.Forms.Padding]::new((Px 8), 0, 0, 0)
    $tt.Font = New-Object System.Drawing.Font('Consolas', [single]10, [System.Drawing.FontStyle]::Bold)
    $tt.Text = "!  $Title"

    $inner.Controls.Add($lb)
    $inner.Controls.Add($bar)
    $inner.Controls.Add($tt)
    $pf.Controls.Add($inner)

    $closer = {
        param($s, $e)
        try { $s.FindForm().Close() } catch { }
        # Al cerrar una ventanita aparecen dos nuevas (solo antes del pantallazo azul)
        try {
            $p = $script:Pr
            if ($p -and $p.BsodAt -eq 0 -and $p.Sw.ElapsedMilliseconds -ge 8000) {
                $p.Popups = @($p.Popups | Where-Object { -not $_.Form.IsDisposed })
                for ($i = 0; $i -lt 2; $i++) { if ($p.Popups.Count -lt 60) { Add-PrankPopupRandom $p } }
            }
        } catch { }
    }
    foreach ($c in @($pf, $inner, $lb, $tt, $bar, $fill)) { $c.Add_Click($closer) }
    $pf.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape') { try { $script:Pr.Form.Close() } catch { } } })

    $pf.Show($Pr.Form)
    return @{ Form = $pf; Fill = $fill; Max = ($pw - 4); Born = $Pr.Sw.ElapsedMilliseconds; Dur = (2500 + $Pr.Rnd.Next(0, 3500)); Bar = $WithBar }
}

function Add-PrankPopupRandom($Pr) {
    $d = $Pr.PopDefs[$Pr.Rnd.Next($Pr.PopDefs.Count)]
    $Pr.Popups += (New-PrankPopup $Pr $d.T $d.B $d.Bar)
}

function Close-PrankPopups($Pr) {
    foreach ($pp in @($Pr.Popups)) { try { if (-not $pp.Form.IsDisposed) { $pp.Form.Close() } } catch { } }
    $Pr.Popups = @()
}

# ------------------------------------------------------------
# Pantalla "Hackeo"
#   0-3 s     alerta parpadeante
#   3-8 s     terminal falsa con barra de carga (5 s)
#   8 s +     CAOS: la pantalla tiembla y se va llenando de ventanitas hasta cubrirla toda
#   luego     pantallazo azul falso (5 s)
#   al final  calavera + "JSJS FUE BROMA" (~6,5 s)
# Esc (o clic en el fondo) cierra todo en cualquier momento.
# ------------------------------------------------------------
function Show-PrankScreen {
    if ($script:Busy) { return }
    if (-not ([System.Management.Automation.PSTypeName]'SombrioRain').Type) {
        try { Add-Type -TypeDefinition $script:RainSource -ReferencedAssemblies 'System.Drawing' }
        catch { Show-Info ("No se pudo preparar la animación:`n`n" + $_.Exception.Message) "HACKEO"; return }
    }

    Set-Status "Preparando..."
    $ips   = Get-PrankIps
    $ipTxt = if ($ips.Public) { $ips.Public } else { $ips.Local }

    $scr = [System.Windows.Forms.Screen]::FromControl($script:Form).Bounds
    $w = $scr.Width; $h = $scr.Height
    $col = [System.Drawing.Color]
    $px  = [System.Drawing.GraphicsUnit]::Pixel
    $bold = [System.Drawing.FontStyle]::Bold

    $lines = [System.Collections.Generic.List[object]]::new()
    $lines.Add(@{ T = "> Iniciando conexión remota...";                     C = 'G' })
    $lines.Add(@{ T = "> Equipo objetivo: $env:COMPUTERNAME  |  Usuario: $env:USERNAME"; C = 'G' })
    $lines.Add(@{ T = "> Tu IP es: $ipTxt";                                 C = 'R' })
    if ($ips.Public -and $ips.Local) { $lines.Add(@{ T = "> Red local: $($ips.Local)"; C = 'G' }) }
    $lines.Add(@{ T = "> Escaneando puertos abiertos... [22] [80] [443] [3389]"; C = 'G' })
    $lines.Add(@{ T = "> Saltando firewall... [OK]";                        C = 'G' })
    $lines.Add(@{ T = "> Escalando privilegios a ADMINISTRADOR... [OK]";    C = 'Y' })
    $lines.Add(@{ T = "> Descifrando contraseñas guardadas... [OK]";        C = 'G' })
    $lines.Add(@{ T = "> Estamos robando tu información...";                C = 'R' })
    $lines.Add(@{ T = "> Copiando fotos, documentos y chats...";            C = 'G' })
    $lines.Add(@{ T = "> Activando cámara y micrófono... [OK]";             C = 'G' })
    $lines.Add(@{ T = "> Instalando keylogger... [ACTIVO]";                 C = 'Y' })
    $lines.Add(@{ T = "> Subiendo datos al servidor 666.13.37.1...";        C = 'G' })
    $lines.Add(@{ T = "> No apagues el equipo.";                            C = 'R' })
    $total = 0; foreach ($l in $lines) { $total += $l.T.Length }

    $popDefs = @(
        @{ T = 'ACCESO REMOTO';      B = "Conexión establecida desde`n666.13.37.1`nTu IP: $ipTxt"; Bar = $false },
        @{ T = 'CÁMARA ACTIVADA';    B = "● REC   Grabando cámara web...`nMicrófono: ACTIVO";       Bar = $false },
        @{ T = 'CONTRASEÑAS';        B = "Copiando 1,284 contraseñas...";                            Bar = $true  },
        @{ T = 'FOTOS Y VIDEOS';     B = "Subiendo 3,421 archivos...";                               Bar = $true  },
        @{ T = 'FIREWALL';           B = "Firewall DESACTIVADO`nPuertos 22, 80, 443 abiertos";       Bar = $false },
        @{ T = 'CUENTAS BANCARIAS';  B = "Extrayendo datos de acceso...";                            Bar = $true  },
        @{ T = 'CHATS';              B = "Mensajes copiados: 18,902";                                Bar = $true  },
        @{ T = 'ERROR 0xDEAD';       B = "Sistema comprometido.`nNo cierres esta ventana.";          Bar = $false },
        @{ T = 'DISCO C:';           B = "Copiando disco C: al servidor remoto...";                  Bar = $true  },
        @{ T = 'KEYLOGGER';          B = "Registrando teclas... [ACTIVO]`nÚltima: ********";         Bar = $false },
        @{ T = 'SESIÓN ROBADA';      B = "Cookies de sesión copiadas: 212";                          Bar = $true  }
    )

    # Cuadrícula de posiciones: al ocuparlas todas, las ventanitas cubren la pantalla completa
    $pw = [math]::Max([int]($w * 0.21), (Px 300))
    $ph = [math]::Max([int]($h * 0.17), (Px 130))
    $cols = [int][math]::Ceiling(($w - $pw) / ($pw * 0.85)) + 1
    $rows = [int][math]::Ceiling(($h - $ph) / ($ph * 0.85)) + 1
    $rndGrid = New-Object System.Random
    $cellList = [System.Collections.Generic.List[object]]::new()
    for ($r = 0; $r -lt $rows; $r++) {
        for ($c = 0; $c -lt $cols; $c++) {
            $cx = if ($cols -gt 1) { [int](($w - $pw) * $c / ($cols - 1)) } else { 0 }
            $cy = if ($rows -gt 1) { [int](($h - $ph) * $r / ($rows - 1)) } else { 0 }
            $jx = $rndGrid.Next(-(Px 8), (Px 8) + 1); $jy = $rndGrid.Next(-(Px 8), (Px 8) + 1)
            $cx = [math]::Max(0, [math]::Min(($w - $pw), ($cx + $jx)))
            $cy = [math]::Max(0, [math]::Min(($h - $ph), ($cy + $jy)))
            $cellList.Add(@{ X = $cx; Y = $cy })
        }
    }
    $cells = @($cellList | Sort-Object { $rndGrid.Next() })

    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = 'None'
    $f.StartPosition = 'Manual'
    $f.Bounds = $scr
    $f.BackColor = $col::Black
    $f.ShowInTaskbar = $false
    $f.KeyPreview = $true
    try { $f.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($f, $true, $null) } catch { }

    $center = New-Object System.Drawing.StringFormat
    $center.Alignment = 'Center'; $center.LineAlignment = 'Center'

    $skullH = [int]($h * 0.62)
    $script:Pr = @{
        Form  = $f
        W = $w; H = $h; X0 = $scr.Left; Y0 = $scr.Top
        Sw    = [System.Diagnostics.Stopwatch]::new()
        Rain  = New-Object SombrioRain($w, $h, (Px 18), (Px 18), [single](Px 16))
        Rnd   = New-Object System.Random
        Lines = $lines
        Total = $total
        PopDefs = $popDefs
        Popups = @()
        Cells = $cells
        GridIdx = 0
        LastPop = 0
        BsodAt = 0
        Center = $center
        Skull = New-PrankSkullBitmap $skullH
        FBig  = New-Object System.Drawing.Font('Consolas', [single]($h / 11), $bold, $px)
        FMid  = New-Object System.Drawing.Font('Consolas', [single]($h / 24), $bold, $px)
        FTerm = New-Object System.Drawing.Font('Consolas', [single]($h / 38), $bold, $px)
        FSmall = New-Object System.Drawing.Font('Consolas', [single]($h / 54), $bold, $px)
        FEnd  = New-Object System.Drawing.Font('Consolas', [single]($h / 11), $bold, $px)
        FBsod = New-Object System.Drawing.Font('Segoe UI', [single]($h / 5), [System.Drawing.FontStyle]::Regular, $px)
        BrGreen = New-Object System.Drawing.SolidBrush($col::FromArgb(0, 255, 110))
        BrDark  = New-Object System.Drawing.SolidBrush($col::FromArgb(0, 110, 50))
        BrRed   = New-Object System.Drawing.SolidBrush($col::FromArgb(255, 60, 70))
        BrYellow = New-Object System.Drawing.SolidBrush($col::FromArgb(255, 210, 70))
        BrWhite = New-Object System.Drawing.SolidBrush($col::White)
        BrFlash = New-Object System.Drawing.SolidBrush($col::FromArgb(70, 255, 0, 0))
        BrFlashW = New-Object System.Drawing.SolidBrush($col::FromArgb(60, 255, 255, 255))
        BrGlitch = New-Object System.Drawing.SolidBrush($col::FromArgb(90, 0, 255, 110))
        BrGlitchR = New-Object System.Drawing.SolidBrush($col::FromArgb(90, 255, 30, 50))
        BrVeil  = New-Object System.Drawing.SolidBrush($col::FromArgb(190, 0, 0, 0))
        BrPanel = New-Object System.Drawing.SolidBrush($col::FromArgb(222, 0, 6, 2))
        PenGreen = New-Object System.Drawing.Pen($col::FromArgb(0, 255, 110), [single]2)
        PenRed   = New-Object System.Drawing.Pen($col::FromArgb(255, 40, 50), [single](Px 8))
        Timer = New-Object System.Windows.Forms.Timer
    }
    $script:Pr.Timer.Interval = 45

    $f.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape') { $s.Close() } })
    $f.Add_MouseDown({ param($s, $e) $s.Close() })
    $f.Add_Shown({ $p = $script:Pr; if ($p) { $p.Sw.Start(); $p.Timer.Start(); try { [System.Media.SystemSounds]::Hand.Play() } catch { } } })
    $f.Add_FormClosing({ $p = $script:Pr; if ($p) { $p.Timer.Stop(); Close-PrankPopups $p } })

    $script:Pr.Timer.Add_Tick({
        $p = $script:Pr
        if ($null -eq $p) { return }
        $t = $p.Sw.ElapsedMilliseconds
        $p.Rain.Update()
        $p.Popups = @($p.Popups | Where-Object { -not $_.Form.IsDisposed })

        # Desde el caos se van colocando ventanitas hasta llenar toda la pantalla
        if ($p.BsodAt -eq 0 -and $t -ge 8000) {
            if ($p.GridIdx -lt $p.Cells.Count) {
                if (($t - $p.LastPop) -ge 230) {
                    $cell = $p.Cells[$p.GridIdx]
                    $p.GridIdx++
                    $d = $p.PopDefs[$p.Rnd.Next($p.PopDefs.Count)]
                    try {
                        $p.Popups += (New-PrankPopup $p $d.T $d.B $d.Bar ($p.X0 + $cell.X) ($p.Y0 + $cell.Y))
                        if (($p.GridIdx % 4) -eq 1) { [System.Media.SystemSounds]::Exclamation.Play() }
                    } catch { }
                    $p.LastPop = $t
                }
            }
            elseif (($t - $p.LastPop) -ge 1500) {
                # Pantalla llena: salta el pantallazo azul
                $p.BsodAt = $t
                Close-PrankPopups $p
            }
            if ($p.BsodAt -eq 0 -and ($t - 8000) -ge 40000) { $p.BsodAt = $t; Close-PrankPopups $p }   # seguro anti-bloqueo
        }

        # Barras de progreso de las ventanitas
        foreach ($pp in $p.Popups) {
            if ($pp.Bar -and -not $pp.Form.IsDisposed) {
                $fr = [math]::Min(1.0, ($t - $pp.Born) / [double]$pp.Dur)
                $pp.Fill.Width = [int]($pp.Max * $fr)
            }
        }

        $p.Form.Invalidate()
        if ($p.BsodAt -gt 0 -and $t -ge ($p.BsodAt + 5000 + 6500)) { $p.Form.Close() }
    })

    $f.Add_Paint({
        param($s, $e)
        try {
            $p = $script:Pr
            if ($null -eq $p) { return }
            $g = $e.Graphics
            $t = $p.Sw.ElapsedMilliseconds
            $w = $p.W; $h = $p.H
            $ba = $p.BsodAt
            $phase = if ($ba -gt 0) { if ($t -lt ($ba + 5000)) { 4 } else { 5 } }
                     elseif ($t -lt 3000) { 1 } elseif ($t -lt 8000) { 2 } else { 3 }
            $g.Clear([System.Drawing.Color]::Black)
            $g.SmoothingMode = 'AntiAlias'
            $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

            # En el caos toda la pantalla tiembla
            if ($phase -eq 3) {
                $j = (Px 7)
                $g.TranslateTransform([single]($p.Rnd.Next(-$j, $j + 1)), [single]($p.Rnd.Next(-$j, $j + 1)))
            }
            if ($phase -le 3) { $p.Rain.Draw($g, $false) }

            if ($phase -eq 1) {
                # ---- FASE 1: ALERTA ----
                $on = ((([int][math]::Floor($t / 250)) % 2) -eq 0)
                if ($on) { $g.FillRectangle($p.BrFlash, 0, 0, $w, $h) }
                $g.DrawRectangle($p.PenRed, 4, 4, ($w - 8), ($h - 8))
                $g.FillRectangle($p.BrVeil, 0, [single]($h * 0.34), $w, [single]($h * 0.32))
                $r1 = New-Object System.Drawing.RectangleF(0, [single]($h * 0.36), $w, [single]($h * 0.16))
                $r2 = New-Object System.Drawing.RectangleF(0, [single]($h * 0.52), $w, [single]($h * 0.10))
                $brA = if ($on) { $p.BrRed } else { $p.BrWhite }
                $g.DrawString([string]"¡ESTÁS SIENDO HACKEADO!", $p.FBig, $brA, $r1, $p.Center)
                $g.DrawString([string]"ACCESO NO AUTORIZADO DETECTADO", $p.FMid, $p.BrRed, $r2, $p.Center)
            }
            elseif ($phase -eq 2) {
                # ---- FASE 2: TERMINAL FALSA + BARRA DE CARGA (5 s) ----
                $on = ((([int][math]::Floor($t / 200)) % 2) -eq 0)
                $bx = [single]($w * 0.12); $by = [single]($h * 0.10)
                $bw = [single]($w * 0.76); $bh = [single]($h * 0.80)
                $g.FillRectangle($p.BrPanel, $bx, $by, $bw, $bh)
                $g.DrawRectangle($p.PenGreen, $bx, $by, $bw, $bh)

                $tb = if ($on) { $p.BrRed } else { $p.BrGreen }
                $g.DrawString([string]"root@sombrio:~#  ACCESO REMOTO ACTIVO", $p.FSmall, $tb, [single]($bx + 20), [single]($by + 12))

                $lineH = $p.FTerm.Height + 6
                $y = $by + $p.FSmall.Height + 34
                $n = [int][math]::Floor([math]::Min(1.0, ($t - 3000) / 4200.0) * $p.Total)
                foreach ($ln in $p.Lines) {
                    if ($n -le 0) { break }
                    $take = [math]::Min($n, $ln.T.Length)
                    $txt = $ln.T.Substring(0, $take)
                    $n -= $take
                    if ($take -lt $ln.T.Length -and $on) { $txt += '█' }
                    $br = switch ($ln.C) { 'R' { $p.BrRed } 'Y' { $p.BrYellow } default { $p.BrGreen } }
                    $g.DrawString([string]$txt, $p.FTerm, $br, [single]($bx + 24), [single]$y)
                    $y += $lineH
                }

                $frac = [math]::Max(0.0, [math]::Min(1.0, ($t - 3000) / 4800.0))
                $pct = [int][math]::Floor($frac * 100)
                $barY = $by + $bh - (Px 78)
                $g.DrawString([string]("TRANSFERENCIA DE DATOS  $pct%"), $p.FSmall, $p.BrGreen, [single]($bx + 24), [single]$barY)
                $barW = $bw - 48
                $g.DrawRectangle($p.PenGreen, [single]($bx + 24), [single]($barY + $p.FSmall.Height + 8), [single]$barW, [single](Px 24))
                $g.FillRectangle($p.BrGreen, [single]($bx + 26), [single]($barY + $p.FSmall.Height + 10), [single](($barW - 4) * $frac), [single]((Px 24) - 4))
            }
            elseif ($phase -eq 3) {
                # ---- FASE 3: CAOS (las ventanitas van llenando la pantalla) ----
                $tc = $t - 8000
                $on = ((([int][math]::Floor($tc / 180)) % 2) -eq 0)
                if ($on) { $g.FillRectangle($p.BrFlash, -20, -20, ($w + 40), ($h + 40)) }
                if ($p.Rnd.Next(0, 9) -eq 0) { $g.FillRectangle($p.BrFlashW, -20, -20, ($w + 40), ($h + 40)) }
                $g.DrawRectangle($p.PenRed, 4, 4, ($w - 8), ($h - 8))
                for ($i = 0; $i -lt 4; $i++) {
                    $gy = $p.Rnd.Next(0, $h); $gh = $p.Rnd.Next((Px 6), (Px 40))
                    $gb = if (($i % 2) -eq 0) { $p.BrGlitch } else { $p.BrGlitchR }
                    $g.FillRectangle($gb, 0, $gy, $w, $gh)
                }
                $g.FillRectangle($p.BrVeil, 0, [single]($h * 0.38), $w, [single]($h * 0.24))
                $r1 = New-Object System.Drawing.RectangleF(0, [single]($h * 0.40), $w, [single]($h * 0.20))
                $brA = if ($on) { $p.BrRed } else { $p.BrWhite }
                $g.DrawString([string]"ACCESO TOTAL CONCEDIDO", $p.FMid, $brA, $r1, $p.Center)
            }
            elseif ($phase -eq 4) {
                # ---- FASE 4: PANTALLAZO AZUL FALSO (genérico, sin marcas) ----
                $tb4 = $t - $ba
                $g.Clear([System.Drawing.Color]::FromArgb(0, 96, 190))
                $mx = [single]($w * 0.08)
                $g.DrawString([string]":(", $p.FBsod, $p.BrWhite, $mx, [single]($h * 0.10))
                $g.DrawString([string]"Se ha producido un error crítico del sistema.`nSe están recopilando los datos del error...", $p.FMid, $p.BrWhite, $mx, [single]($h * 0.42))
                $pct4 = [int][math]::Min(100, [math]::Floor($tb4 / 4600.0 * 100))
                $g.DrawString([string]("$pct4% completado"), $p.FMid, $p.BrWhite, $mx, [single]($h * 0.58))
                $g.DrawString([string]"Código de detención: SOMBRIO_HACKED_BY_JAJA", $p.FTerm, $p.BrWhite, $mx, [single]($h * 0.76))
            }
            else {
                # ---- FASE 5: SOLO CALAVERA + "JSJS FUE BROMA" ----
                $tp = $t - ($ba + 5000)
                $a = [single][math]::Min(1.0, $tp / 600.0)
                $bmp = $p.Skull
                $dest = New-Object System.Drawing.Rectangle([int](($w - $bmp.Width) / 2), [int]($h * 0.04), $bmp.Width, $bmp.Height)
                $cm = New-Object System.Drawing.Imaging.ColorMatrix
                $cm.Matrix33 = $a
                $ia = New-Object System.Drawing.Imaging.ImageAttributes
                $ia.SetColorMatrix($cm)
                $g.DrawImage($bmp, $dest, 0, 0, $bmp.Width, $bmp.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
                $ia.Dispose()

                if ($tp -gt 600) {
                    $blink = ((([int][math]::Floor($tp / 350)) % 2) -eq 0)
                    $r1  = New-Object System.Drawing.RectangleF(0, [single]($h * 0.70), $w, [single]($h * 0.18))
                    $r1s = New-Object System.Drawing.RectangleF(4, [single]($h * 0.70 + 4), $w, [single]($h * 0.18))
                    $g.DrawString([string]"JSJS FUE BROMA", $p.FEnd, $p.BrDark, $r1s, $p.Center)
                    $g.DrawString([string]"JSJS FUE BROMA", $p.FEnd, $(if ($blink) { $p.BrGreen } else { $p.BrWhite }), $r1, $p.Center)
                }
            }
            $g.ResetTransform()
        } catch { }
    })

    try {
        [void]$f.ShowDialog($script:Form)
    } finally {
        $p = $script:Pr
        $script:Pr = $null
        try {
            $p.Timer.Stop(); $p.Timer.Dispose()
            Close-PrankPopups $p
            $p.Rain.Dispose(); $p.Skull.Dispose(); $p.Center.Dispose()
            foreach ($k in 'FBig', 'FMid', 'FTerm', 'FSmall', 'FEnd', 'FBsod', 'BrGreen', 'BrDark', 'BrRed', 'BrYellow', 'BrWhite', 'BrFlash', 'BrFlashW', 'BrGlitch', 'BrGlitchR', 'BrVeil', 'BrPanel', 'PenGreen', 'PenRed') { $p[$k].Dispose() }
        } catch { }
        $f.Dispose()
        Set-Status "Listo. Era solo una pantalla: no se tocó nada en tu PC."
    }
}

# ============================================================
# FIN DEL MÓDULO DE BROMA
# ============================================================

# ============================================================
# CONSTRUCCIÓN DE LA VENTANA
# ============================================================
function New-FlatButton([string]$Text, [int]$Width, [int]$Height = 30) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Width = (Px $Width)
    $b.Height = (Px $Height)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = $script:C.Border
    $b.FlatAppearance.MouseOverBackColor = $script:C.Hover
    $b.FlatAppearance.MouseDownBackColor = $script:C.Select
    $b.UseVisualStyleBackColor = $false
    $b.BackColor = $script:C.Panel2
    $b.ForeColor = $script:C.Text
    $b.Font = $script:FontBase
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

Initialize-Decompressor
$script:FontBase  = New-Object System.Drawing.Font('Segoe UI', [single]9.5, [System.Drawing.FontStyle]::Regular)
$script:FontBold  = New-Object System.Drawing.Font('Segoe UI', [single]9.5, [System.Drawing.FontStyle]::Bold)
$fontSmall        = New-Object System.Drawing.Font('Segoe UI', [single]8, [System.Drawing.FontStyle]::Bold)
$fontTitle        = New-Object System.Drawing.Font('Segoe UI', [single]16, [System.Drawing.FontStyle]::Bold)
$fontHeader       = New-Object System.Drawing.Font('Segoe UI', [single]10.5, [System.Drawing.FontStyle]::Bold)
$fontMono         = New-Object System.Drawing.Font('Consolas', [single]10, [System.Drawing.FontStyle]::Bold)
$fontArt          = New-Object System.Drawing.Font('Consolas', [single]6.5, [System.Drawing.FontStyle]::Regular)
$isAdminNow       = Test-Administrator

# --- Ventana principal ---
$script:Form = New-Object System.Windows.Forms.Form
$script:Form.Text = "EL SOMBRIO IF  ·  Forensic Scanner V80"
$script:Form.FormBorderStyle = 'Sizable'
$script:Form.StartPosition = 'CenterScreen'
$script:Form.ClientSize = New-Object System.Drawing.Size((Px 1320), (Px 800))
$script:Form.MinimumSize = New-Object System.Drawing.Size((Px 1180), (Px 700))
$script:Form.BackColor = $script:C.Bg
$script:Form.ForeColor = $script:C.Text
$script:Form.Font = $script:FontBase
$script:Form.KeyPreview = $true

# --- Panel derecho (cabecera + contenido + barra de estado) ---
$mainRight = New-Object System.Windows.Forms.Panel
$mainRight.Dock = 'Fill'
$mainRight.BackColor = $script:C.Bg

# Contenedor central (tabla, chips, filtros, portada)
$script:HostPanel = New-Object System.Windows.Forms.Panel
$script:HostPanel.Dock = 'Fill'
$script:HostPanel.BackColor = $script:C.Bg
$script:HostPanel.Padding = [System.Windows.Forms.Padding]::new((Px 16), (Px 6), (Px 16), (Px 6))

# Tabla de resultados (se añade primero: es el control que rellena)
$script:Grid = New-Object System.Windows.Forms.DataGridView
$grid = $script:Grid
$grid.Dock = 'Fill'
$grid.Visible = $false
$grid.BackgroundColor = $script:C.Panel
$grid.BorderStyle = 'None'
$grid.GridColor = $script:C.Border
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$grid.AutoSizeRowsMode = 'None'
$grid.DefaultCellStyle.BackColor = $script:C.Panel
$grid.DefaultCellStyle.ForeColor = $script:C.Text
$grid.DefaultCellStyle.SelectionBackColor = $script:C.Select
$grid.DefaultCellStyle.SelectionForeColor = $script:C.Text
$grid.DefaultCellStyle.Font = $script:FontBase
$grid.DefaultCellStyle.Padding = [System.Windows.Forms.Padding]::new((Px 6), 0, (Px 6), 0)
$grid.AlternatingRowsDefaultCellStyle.BackColor = $script:C.Row2
$grid.EnableHeadersVisualStyles = $false
$grid.ColumnHeadersDefaultCellStyle.BackColor = $script:C.Panel2
$grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:C.Accent
$grid.ColumnHeadersDefaultCellStyle.Font = $script:FontBold
$grid.ColumnHeadersDefaultCellStyle.Alignment = 'MiddleLeft'
$grid.ColumnHeadersBorderStyle = 'None'
$grid.ColumnHeadersHeight = (Px 34)
$grid.ColumnHeadersHeightSizeMode = 'DisableResizing'
$grid.RowTemplate.Height = (Px 30)
$grid.DefaultCellStyle.Padding = [System.Windows.Forms.Padding]::new((Px 10), (Px 3), (Px 10), (Px 3))
try {
    $pi = [System.Windows.Forms.DataGridView].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic')
    $pi.SetValue($grid, $true, $null)
} catch { }
foreach ($cdef in @(@('nivel', 'NIVEL', 100), @('tipo', 'TIPO', 190), @('elemento', 'ELEMENTO', 330), @('detalle', 'DETALLE', 0))) {
    $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col.Name = $cdef[0]
    $col.HeaderText = $cdef[1]
    if ($cdef[2] -gt 0) { $col.AutoSizeMode = 'None'; $col.Width = (Px $cdef[2]) }
    else { $col.AutoSizeMode = 'Fill'; $col.MinimumWidth = (Px 240) }
    [void]$grid.Columns.Add($col)
}

# Menú contextual (clic derecho)
$ctx = New-Object System.Windows.Forms.ContextMenuStrip
$ctx.BackColor = $script:C.Panel2
$ctx.ForeColor = $script:C.Text
foreach ($mi in @(@('Abrir ubicación', 'open'), @('Copiar ruta', 'path'), @('Copiar nombre', 'name'), @('Copiar fila completa', 'row'))) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $mi[0]
    $item.Tag = $mi[1]
    $item.Add_Click({ param($s, $e) Invoke-GridMenuAction ([string]$s.Tag) })
    [void]$ctx.Items.Add($item)
}
$grid.ContextMenuStrip = $ctx
$grid.Add_CellMouseDown({
    param($s, $e)
    if ($e.Button -eq 'Right' -and $e.RowIndex -ge 0) {
        $s.ClearSelection()
        $s.Rows[$e.RowIndex].Selected = $true
        try { $s.CurrentCell = $s.Rows[$e.RowIndex].Cells[2] } catch { }
    }
})
$grid.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { Open-SelectedGridItem } })

# Barra de filtros (buscador + nivel + contador)
$script:FilterBar = New-Object System.Windows.Forms.Panel
$script:FilterBar.Dock = 'Top'
$script:FilterBar.Height = (Px 44)
$script:FilterBar.BackColor = $script:C.Bg
$script:FilterBar.Visible = $false

$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = "BUSCAR"
$lblSearch.Font = $fontSmall
$lblSearch.ForeColor = $script:C.Muted
$lblSearch.AutoSize = $true
$lblSearch.Left = 0
$lblSearch.Top = (Px 14)

$script:TxtFilter = New-Object System.Windows.Forms.TextBox
$script:TxtFilter.Left = (Px 64)
$script:TxtFilter.Top = (Px 9)
$script:TxtFilter.Width = (Px 300)
$script:TxtFilter.BackColor = $script:C.Panel2
$script:TxtFilter.ForeColor = $script:C.Text
$script:TxtFilter.BorderStyle = 'FixedSingle'
$script:TxtFilter.Font = $script:FontBase
$script:TxtFilter.Add_TextChanged({
    if (-not $script:SuppressFilter) { $script:FilterText = $script:TxtFilter.Text; Update-FilterView }
})

$script:CmbLevel = New-Object System.Windows.Forms.ComboBox
$script:CmbLevel.Left = (Px (64 + 300 + 12))
$script:CmbLevel.Top = (Px 9)
$script:CmbLevel.Width = (Px 200)
$script:CmbLevel.DropDownStyle = 'DropDownList'
$script:CmbLevel.FlatStyle = 'Flat'
$script:CmbLevel.BackColor = $script:C.Panel2
$script:CmbLevel.ForeColor = $script:C.Text
$script:CmbLevel.Font = $script:FontBase
[void]$script:CmbLevel.Items.AddRange(@('Todos los niveles', 'Solo críticos', 'Críticos y alertas'))
$script:CmbLevel.SelectedIndex = 0
$script:CmbLevel.Add_SelectedIndexChanged({
    if (-not $script:SuppressFilter) {
        $script:FilterLevel = @('all', 'red', 'warn')[$script:CmbLevel.SelectedIndex]
        Update-FilterView
    }
})

$script:LblCount = New-Object System.Windows.Forms.Label
$script:LblCount.Dock = 'Right'
$script:LblCount.Width = (Px 480)
$script:LblCount.TextAlign = 'MiddleRight'
$script:LblCount.ForeColor = $script:C.Muted
$script:LblCount.Font = $script:FontBase
$script:LblCount.Text = ""

$script:FilterBar.Controls.Add($lblSearch)
$script:FilterBar.Controls.Add($script:TxtFilter)
$script:FilterBar.Controls.Add($script:CmbLevel)
$script:FilterBar.Controls.Add($script:LblCount)

# Categorías (chips)
$script:Chips = New-Object System.Windows.Forms.FlowLayoutPanel
$script:Chips.Dock = 'Top'
$script:Chips.AutoSize = $true
$script:Chips.AutoSizeMode = 'GrowAndShrink'
$script:Chips.WrapContents = $true
$script:Chips.BackColor = $script:C.Bg
$script:Chips.Padding = [System.Windows.Forms.Padding]::new(0, (Px 4), 0, (Px 2))
$script:Chips.Visible = $false
foreach ($def in $script:CatDefs) {
    $chip = New-Object System.Windows.Forms.Button
    $chip.Text = $def.Text
    $chip.Tag = $def.Key
    $chip.AutoSize = $true
    $chip.AutoSizeMode = 'GrowAndShrink'
    $chip.MinimumSize = New-Object System.Drawing.Size(0, (Px 32))
    $chip.Padding = [System.Windows.Forms.Padding]::new((Px 8), 0, (Px 8), 0)
    $chip.Margin = [System.Windows.Forms.Padding]::new(0, 0, (Px 6), (Px 6))
    $chip.FlatStyle = 'Flat'
    $chip.FlatAppearance.BorderSize = 0
    $chip.FlatAppearance.BorderColor = $script:C.Border
    $chip.FlatAppearance.MouseOverBackColor = $script:C.Hover
    $chip.UseVisualStyleBackColor = $false
    $chip.BackColor = $script:C.Panel2
    $chip.ForeColor = $script:C.Muted
    $chip.Font = $fontSmall
    $chip.Cursor = [System.Windows.Forms.Cursors]::Hand
    $chip.MinimumSize = New-Object System.Drawing.Size(0, (Px 36))
    $chip.Add_Paint({
        param($s, $e)
        try {
            if ([string]$s.Tag -eq $script:ActiveCat) {
                $ab = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, ($s.Height - (Px 3)), [math]::Max(2, $s.Width), (Px 3))), $script:C.Accent, $script:C.Pink, 0.0)
                $e.Graphics.FillRectangle($ab, 0, ($s.Height - (Px 3)), $s.Width, (Px 3))
                $ab.Dispose()
            }
        } catch { }
    })
    $chip.Add_Click({ param($s, $e) if (-not $script:Busy) { Show-Category ([string]$s.Tag) } })
    $script:CatButtons[$def.Key] = $chip
    $script:Chips.Controls.Add($chip)
}

# Portada limpia: titulo, boton principal y tarjetas informativas
function New-HomeCard([int]$X, [string]$Title, [string]$Body, $Tint) {
    $card = New-Object System.Windows.Forms.Panel
    $card.SetBounds((Px $X), (Px 262), (Px 256), (Px 176))
    $card.BackColor = $script:C.Panel2
    $card.Add_Paint({ param($s, $e)
        $pen = New-Object System.Drawing.Pen((Merge-Color $script:C.Accent $script:C.Panel2 0.35))
        $e.Graphics.DrawRectangle($pen, 0, 0, ($s.Width - 1), ($s.Height - 1))
        $pen.Dispose()
    })
    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Top'; $bar.Height = (Px 3); $bar.BackColor = $Tint
    $lt = New-Object System.Windows.Forms.Label
    $lt.Text = $Title; $lt.Font = $fontSmall; $lt.ForeColor = $Tint; $lt.BackColor = $script:C.Panel2
    $lt.SetBounds((Px 18), (Px 18), (Px 220), (Px 20))
    $lb = New-Object System.Windows.Forms.Label
    $lb.Text = $Body; $lb.Font = $script:FontBase; $lb.ForeColor = $script:C.Text; $lb.BackColor = $script:C.Panel2
    $lb.SetBounds((Px 18), (Px 48), (Px 226), (Px 120))
    $card.Controls.AddRange(@($bar, $lt, $lb))
    return $card
}

function New-PixelCat([int]$Scale, [bool]$EyesOpen) {
    $rows = @'
....KK............KK........
...KFFK..........KFFK.......
...KFPFK........KFPFK.......
..KFFPFFKKKKKKKKFFPFFK......
.KFFFFFFFFFFFFFFFFFFFF......
.KFFFFFFFFFFFFFFFFFFFF......
.KFFFYDYFFFFFFFFYDYFFF......
.KFFFYDYFFFFFFFFYDYFFF......
.KFFFFFFFFFPPFFFFFFFFF......
.KFFFFFFFFMFFMFFFFFFFF......
.KFFFFFFFFFMMFFFFFFFFF......
..KFFFFFFFFFFFFFFFFFFK......
...KKKKKKKKKKKKKKKKKK.......
....KFFFFFFFFFFFFFFK........
....KFFFFFHHHHFFFFFK.....KK.
...KFFFFFHHHHHHFFFFFK...KFFK
...KFFFFFHHHHHHFFFFFK...KFFK
..KFFFFFFHHHHHHFFFFFFK..KFFK
..KFFFFFFFHHHHFFFFFFFK..KFFK
..KFFFFFFFFFFFFFFFFFFK..KFFK
..KFFFFFFFFFFFFFFFFFFK..KFFK
..KFFFFFFFFKKFFFFFFFFK.KFFFK
..KFFFFFFFFKKFFFFFFFFK.KFFFK
..KFFFFFFFFKKFFFFFFFFKKFFFFK
..KKKKKKKKKKKKKKKKKKKKKKKKKK
'@ -split "`n"
    $cols = @{
        'K' = (Merge-Color $script:C.Text $script:C.Bg 0.10)
        'M' = (Merge-Color $script:C.Text $script:C.Bg 0.10)
        'F' = (Merge-Color $script:C.Text $script:C.Bg 0.22)
        'H' = (Merge-Color $script:C.Text $script:C.Bg 0.31)
        'P' = (Merge-Color $script:C.Pink $script:C.Bg 0.65)
        'Y' = (Merge-Color $script:C.Yellow $script:C.Bg 0.80)
        'D' = [System.Drawing.Color]::FromArgb(255, 8, 8, 10)
    }
    $w = 28 * $Scale; $h = 25 * $Scale
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = 'None'
        $g.PixelOffsetMode = 'Half'
        for ($y = 0; $y -lt $rows.Count; $y++) {
            $line = ([string]$rows[$y]).Trim()
            for ($x = 0; $x -lt $line.Length; $x++) {
                $ch = [string]$line[$x]
                if ($ch -eq '.') { continue }
                if (-not $EyesOpen -and ($ch -eq 'Y' -or $ch -eq 'D')) { $ch = if ($y -eq 6) { 'F' } else { 'K' } }
                $br = New-Object System.Drawing.SolidBrush($cols[$ch])
                $g.FillRectangle($br, ($x * $Scale), ($y * $Scale), $Scale, $Scale)
                $br.Dispose()
            }
        }
    } finally { $g.Dispose() }
    return ,$bmp
}

$script:CatOpen   = New-PixelCat (Px 8) $true
$script:CatClosed = New-PixelCat (Px 8) $false
$script:CatBlink  = $false
$script:CatTick   = 0

$script:HomeArt = New-Object System.Windows.Forms.Panel
$script:HomeArt.BackColor = [System.Drawing.Color]::Transparent
$script:HomeArt.Size = New-Object System.Drawing.Size((Px 800), (Px 450))
$script:HomeArt.Add_Paint({ param($s, $e)
    try {
        $g = $e.Graphics
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $rect = New-Object System.Drawing.Rectangle(0, (Px 24), (Px 420), (Px 70))
        $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $script:C.Accent, $script:C.Pink, 0.0)
        $g.DrawString("El Sombrio IF", $script:FontHero, $lg, 0, (Px 24))
        $lg.Dispose()
        $cb = if ($script:CatBlink) { $script:CatClosed } else { $script:CatOpen }
        $g.InterpolationMode = 'NearestNeighbor'
        $g.PixelOffsetMode = 'Half'
        $g.DrawImage($cb, ($s.Width - $cb.Width - (Px 14)), (Px 30), $cb.Width, $cb.Height)
    } catch { }
})

$lblEyebrow = New-Object System.Windows.Forms.Label
$lblEyebrow.Text = "//  PLATAFORMA DE ANÁLISIS FORENSE"
$lblEyebrow.Font = New-Object System.Drawing.Font('Consolas', [single]9.5, [System.Drawing.FontStyle]::Bold)
$lblEyebrow.ForeColor = $script:C.Accent
$lblEyebrow.AutoSize = $true
$lblEyebrow.BackColor = [System.Drawing.Color]::Transparent
$lblEyebrow.Location = New-Object System.Drawing.Point(0, 0)

$lblHero = New-Object System.Windows.Forms.Label
$lblHero.Text = "El Sombrio IF"
$lblHero.Font = New-Object System.Drawing.Font('Segoe UI Semibold', [single]34, [System.Drawing.FontStyle]::Regular)
$lblHero.ForeColor = $script:C.Text
$lblHero.Visible = $false
$script:FontHero = $lblHero.Font
$lblHero.AutoSize = $true
$lblHero.Location = New-Object System.Drawing.Point(0, (Px 24))

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Revisión forense para screenshare: mods, memoria, prefetch,`r`npapelera, macros y detección de archivos renombrados."
$lblSub.Font = New-Object System.Drawing.Font('Segoe UI', [single]11.5, [System.Drawing.FontStyle]::Regular)
$lblSub.ForeColor = $script:C.Muted
$lblSub.AutoSize = $true
$lblSub.BackColor = [System.Drawing.Color]::Transparent
$lblSub.Location = New-Object System.Drawing.Point(0, (Px 98))

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Iniciar auditoría global     F5"
$btnStart.Size = New-Object System.Drawing.Size((Px 300), (Px 46))
$btnStart.Location = New-Object System.Drawing.Point(0, (Px 176))
$btnStart.FlatStyle = 'Flat'
$btnStart.FlatAppearance.BorderSize = 0
$btnStart.UseVisualStyleBackColor = $false
$btnStart.BackColor = $script:C.Accent
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatAppearance.MouseOverBackColor = (Merge-Color ([System.Drawing.Color]::White) $script:C.Accent 0.15)
$btnStart.FlatAppearance.MouseDownBackColor = (Merge-Color ([System.Drawing.Color]::Black) $script:C.Accent 0.2)
$btnStart.Font = New-Object System.Drawing.Font('Segoe UI', [single]10.5, [System.Drawing.FontStyle]::Bold)
$btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnStart.TabStop = $false
$btnStart.Add_MouseEnter({ param($s, $e) $s.Invalidate() })
$btnStart.Add_MouseLeave({ param($s, $e) $s.Invalidate() })
$btnStart.Add_Paint({ param($s, $e)
    try {
        $g = $e.Graphics
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $hover = $s.ClientRectangle.Contains($s.PointToClient([System.Windows.Forms.Cursor]::Position))
        $k = if ($hover) { 0.95 } else { 0.7 }
        $rect = New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)
        $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (Merge-Color $script:C.Accent $script:C.Bg ($k * 0.55)), (Merge-Color $script:C.Pink $script:C.Bg ($k * 0.8)), 0.0)
        $g.FillRectangle($lg, $rect)
        $lg.Dispose()
        $pen = New-Object System.Drawing.Pen($script:C.Accent, [single]2)
        $g.DrawRectangle($pen, 1, 1, ($s.Width - 3), ($s.Height - 3))
        $pen.Dispose()
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        $g.DrawString("▶   INICIAR AUDITORÍA GLOBAL      F5", $s.Font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)), $sf)
        $sf.Dispose()
    } catch { }
})
$btnStart.Add_Click({ Invoke-NavAction 'global' })

$adminLine = if ($isAdminNow) { "●  Administrador" } else { "●  Sin permisos de admin" }
$card1 = New-HomeCard 0   "QUÉ REVISA"  "Memoria y procesos`r`nPrefetch y papelera`r`nMods por versión de Minecraft`r`nMacros y autoclickers`r`nAnti-bypass y disco profundo" $script:C.Accent
$card2 = New-HomeCard 272 "ATAJOS"      "F5              Auditoría global`r`nCtrl+F        Buscar en la tabla`r`nCtrl+E        Exportar a CSV`r`nEsc             Limpiar filtro`r`nClic der.    Más acciones" $script:C.Green
$card3 = New-HomeCard 544 "SESIÓN"      "$adminLine`r`nTema:  $($script:ThemeName)`r`nVersión:  V80`r`nReporte: Escritorio (.txt)" $(if ($isAdminNow) { $script:C.Yellow } else { $script:C.Red })

$script:HomeArt.Controls.AddRange(@($lblEyebrow, $lblHero, $lblSub, $btnStart, $card1, $card2, $card3))
$script:CatTimer = New-Object System.Windows.Forms.Timer
$script:CatTimer.Interval = 220
$script:CatTimer.Add_Tick({
    try {
        $script:CatTick++
        $nb = (($script:CatTick % 16) -eq 0)
        if ($nb -ne $script:CatBlink) {
            $script:CatBlink = $nb
            if ($script:HomeArt -and $script:HomeArt.Visible) { $script:HomeArt.Invalidate() }
        }
    } catch { }
})
$script:CatTimer.Start()

# Orden de apilado: el control que rellena va primero; el último "Top" queda arriba del todo
$script:HostPanel.Controls.Add($grid)
$script:HostPanel.Controls.Add($script:FilterBar)
$script:HostPanel.Controls.Add($script:Chips)
$script:HostPanel.Controls.Add($script:HomeArt)
try {
    $script:HostPanel.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($script:HostPanel, $true, $null)
} catch { }
$script:HostPanel.Add_Paint({ param($s, $e)
    try {
        $g = $e.Graphics
        $w = $s.ClientSize.Width; $h = $s.ClientSize.Height
        if ($w -lt 10 -or $h -lt 10) { return }
        $g.SmoothingMode = 'AntiAlias'
        # resplandor suave
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse([int]($w * 0.45), [int](-$h * 0.35), [int]($w * 0.8), [int]($h * 1.1))
        $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
        $pg.CenterColor = [System.Drawing.Color]::FromArgb(20, $script:C.Accent.R, $script:C.Accent.G, $script:C.Accent.B)
        $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $script:C.Accent.R, $script:C.Accent.G, $script:C.Accent.B))
        $g.FillPath($pg, $path)
        $pg.Dispose(); $path.Dispose()
        $path2 = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path2.AddEllipse([int](-$w * 0.2), [int]($h * 0.45), [int]($w * 0.7), [int]($h * 0.9))
        $pg2 = New-Object System.Drawing.Drawing2D.PathGradientBrush($path2)
        $pg2.CenterColor = [System.Drawing.Color]::FromArgb(16, $script:C.Pink.R, $script:C.Pink.G, $script:C.Pink.B)
        $pg2.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $script:C.Pink.R, $script:C.Pink.G, $script:C.Pink.B))
        $g.FillPath($pg2, $path2)
        $pg2.Dispose(); $path2.Dispose()
        # cuadricula
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(16, $script:C.Accent.R, $script:C.Accent.G, $script:C.Accent.B))
        $step = (Px 44)
        for ($x = 0; $x -lt $w; $x += $step) { $g.DrawLine($pen, $x, 0, $x, $h) }
        for ($y = 0; $y -lt $h; $y += $step) { $g.DrawLine($pen, 0, $y, $w, $y) }
        $pen.Dispose()
    } catch { }
})
$script:HostPanel.Add_Resize({ Move-HomeArt; $script:HostPanel.Invalidate() })

# --- Cabecera (título de la vista + botones) ---
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = (Px 64)
$header.BackColor = $script:C.Panel
$header.Padding = [System.Windows.Forms.Padding]::new((Px 24), 0, (Px 20), 0)
$header.Padding = [System.Windows.Forms.Padding]::new((Px 20), 0, (Px 16), 0)

$header.Add_Paint({ param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:C.Border)
    $lgb = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, ($s.Height - 2), [math]::Max(2, $s.Width), 2)), $script:C.Accent, $script:C.Bg, 0.0)
    $e.Graphics.FillRectangle($lgb, 0, ($s.Height - 2), $s.Width, 2)
    $lgb.Dispose()
    $pen.Dispose()
})

$script:LblView = New-Object System.Windows.Forms.Label
$script:LblView.Dock = 'Fill'
$script:LblView.TextAlign = 'MiddleLeft'
$script:LblView.Font = New-Object System.Drawing.Font('Segoe UI Semibold', [single]12.5, [System.Drawing.FontStyle]::Regular)
$script:LblView.ForeColor = $script:C.Text
$script:LblView.Text = "CONSOLA CENTRAL DE OPERACIONES FORENSES"

$script:BtnOpenSelected = New-FlatButton "ABRIR UBICACIÓN" 150 32
$script:BtnOpenSelected.Dock = 'Right'
$script:BtnOpenSelected.Visible = $false
$script:BtnOpenSelected.Add_Click({ Open-SelectedGridItem })

$script:BtnExport = New-FlatButton "EXPORTAR CSV" 130 32
$script:BtnExport.Dock = 'Right'
$script:BtnExport.Visible = $false
$script:BtnExport.Add_Click({ Export-GridView })

$header.Controls.Add($script:LblView)
$header.Controls.Add($script:BtnOpenSelected)
$header.Controls.Add($script:BtnExport)

$lblPill = New-Object System.Windows.Forms.Label
$lblPill.Dock = 'Right'
$lblPill.Width = (Px 150)
$lblPill.TextAlign = 'MiddleRight'
$lblPill.Font = $fontSmall
if ($isAdminNow) { $lblPill.Text = "●  ADMINISTRADOR"; $lblPill.ForeColor = $script:C.Green }
else             { $lblPill.Text = "●  SIN PERMISOS ADMIN"; $lblPill.ForeColor = $script:C.Yellow }
$header.Controls.Add($lblPill)

# El botón EXPORTAR solo se ve cuando el panel de resultados está visible
$script:Chips.Add_VisibleChanged({ if ($script:BtnExport) { $script:BtnExport.Visible = $script:Chips.Visible } })

# --- Barra de estado inferior (estado + botones + progreso + detalle) ---
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Dock = 'Bottom'
$statusPanel.Height = (Px 100)
$statusPanel.BackColor = $script:C.Panel

$row3 = New-Object System.Windows.Forms.Panel
$row3.Dock = 'Fill'
$row3.Padding = [System.Windows.Forms.Padding]::new((Px 20), 0, (Px 16), 0)
$script:LblDetail = New-Object System.Windows.Forms.Label
$script:LblDetail.Dock = 'Fill'
$script:LblDetail.TextAlign = 'MiddleLeft'
$script:LblDetail.ForeColor = $script:C.Muted
$script:LblDetail.Font = $script:FontBase
$row3.Controls.Add($script:LblDetail)

$row2 = New-Object System.Windows.Forms.Panel
$row2.Dock = 'Top'
$row2.Height = (Px 24)
$barHolder = New-Object System.Windows.Forms.Panel
$barHolder.Dock = 'Fill'
$barHolder.Padding = [System.Windows.Forms.Padding]::new((Px 20), (Px 8), (Px 8), (Px 8))
$script:BarTrack = New-Object System.Windows.Forms.Panel
$script:BarTrack.Dock = 'Fill'
$script:BarTrack.BackColor = $script:C.Panel2
$script:BarFill = New-Object System.Windows.Forms.Panel
$script:BarFill.Dock = 'Left'
$script:BarFill.Width = 0
$script:BarFill.BackColor = $script:C.Accent
$script:BarFill.Add_Paint({ param($s, $e)
    try {
        if ($s.Width -gt 2 -and $s.Height -gt 1) {
            $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)), $script:C.Accent, $script:C.Pink, 0.0)
            $e.Graphics.FillRectangle($lg, 0, 0, $s.Width, $s.Height)
            $lg.Dispose()
        }
    } catch { }
})
$script:BarTrack.Controls.Add($script:BarFill)
$barHolder.Controls.Add($script:BarTrack)
$script:LblPct = New-Object System.Windows.Forms.Label
$script:LblPct.Dock = 'Right'
$script:LblPct.Width = (Px 70)
$script:LblPct.TextAlign = 'MiddleCenter'
$script:LblPct.Font = $script:FontBold
$script:LblPct.ForeColor = $script:C.Text
$script:LblPct.Text = "0%"
$row2.Controls.Add($barHolder)
$row2.Controls.Add($script:LblPct)

$row1 = New-Object System.Windows.Forms.Panel
$row1.Dock = 'Top'
$row1.Height = (Px 38)
$row1.Padding = [System.Windows.Forms.Padding]::new((Px 20), (Px 4), (Px 16), (Px 2))
$script:LblStatus = New-Object System.Windows.Forms.Label
$script:LblStatus.Dock = 'Fill'
$script:LblStatus.TextAlign = 'MiddleLeft'
$script:LblStatus.Font = $script:FontBold
$script:LblStatus.ForeColor = $script:C.Text
$script:LblStatus.Text = if ($isAdminNow) { "Listo. Presiona F5 para iniciar la auditoría global." } else { "Listo (sin permisos de administrador: algunos módulos quedarán incompletos). F5 inicia la auditoría." }
$script:BtnCancel = New-FlatButton "CANCELAR" 110 28
$script:BtnCancel.Dock = 'Right'
$script:BtnCancel.Visible = $false
$script:BtnCancel.ForeColor = $script:C.Red
$script:BtnCancel.Add_Click({ $script:CancelRequested = $true; Set-Status "Cancelando... (termina el archivo en curso)" })
$script:BtnReport = New-FlatButton "ABRIR REPORTE" 140 28
$script:BtnReport.Dock = 'Right'
$script:BtnReport.Visible = $false
$script:BtnReport.Add_Click({
    try { if ($script:LastReport -and (Test-Path -LiteralPath $script:LastReport)) { Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,"' + $script:LastReport + '"') } } catch { }
})
$row1.Controls.Add($script:LblStatus)
$row1.Controls.Add($script:BtnCancel)
$row1.Controls.Add($script:BtnReport)

$statusPanel.Add_Paint({ param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:C.Border)
    $e.Graphics.DrawLine($pen, 0, 0, $s.Width, 0)
    $pen.Dispose()
})
$statusPanel.Controls.Add($row3)
$statusPanel.Controls.Add($row2)
$statusPanel.Controls.Add($row1)

$mainRight.Controls.Add($script:HostPanel)
$mainRight.Controls.Add($statusPanel)
$mainRight.Controls.Add($header)

# --- Menú lateral ---
$navPanel = New-Object System.Windows.Forms.Panel
$navPanel.Dock = 'Left'
$navPanel.Width = (Px 280)
$navPanel.BackColor = $script:C.Panel

$navTitle = New-Object System.Windows.Forms.Panel
$navTitle.Dock = 'Top'
$navTitle.Height = (Px 80)
$lblNavT = New-Object System.Windows.Forms.Label
$lblNavT.Text = "EL SOMBRIO IF"
$lblNavT.Font = New-Object System.Drawing.Font('Segoe UI Semibold', [single]13, [System.Drawing.FontStyle]::Regular)
$lblNavT.ForeColor = $script:C.Text
$lblNavT.AutoSize = $true
$lblNavT.Location = New-Object System.Drawing.Point((Px 66), (Px 16))
$lblNavS = New-Object System.Windows.Forms.Label
$lblNavS.Text = "FORENSIC SCANNER  ·  V80"
$lblNavS.Font = $fontSmall
$lblNavS.ForeColor = $script:C.Muted
$lblNavS.AutoSize = $true
$lblNavS.Location = New-Object System.Drawing.Point((Px 68), (Px 44))
$logo = New-Object System.Windows.Forms.Label
$logo.SetBounds((Px 20), (Px 20), (Px 38), (Px 38))
$logo.BackColor = $script:C.Accent
$logo.ForeColor = [System.Drawing.Color]::White
$logo.Text = "S"
$logo.TextAlign = 'MiddleCenter'
$logo.Font = New-Object System.Drawing.Font('Segoe UI', [single]15, [System.Drawing.FontStyle]::Bold)
$logo.Text = ""
$logo.Add_Paint({ param($s, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = 'AntiAlias'
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)), $script:C.Accent, $script:C.Pink, 45.0)
        $g.FillRectangle($lg, 0, 0, $s.Width, $s.Height)
        $lg.Dispose()
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        $g.DrawString("S", $s.Font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)), $sf)
        $sf.Dispose()
    } catch { }
})
$navTitle.Controls.Add($logo)
$navTitle.Controls.Add($lblNavT)
$navTitle.Controls.Add($lblNavS)

$navFooter = New-Object System.Windows.Forms.Label
$navFooter.Dock = 'Bottom'
$navFooter.Height = (Px 38)
$navFooter.TextAlign = 'MiddleLeft'
$navFooter.Padding = [System.Windows.Forms.Padding]::new((Px 20), 0, 0, 0)
$navFooter.Font = $fontSmall
if ($isAdminNow) { $navFooter.Text = "●  ADMINISTRADOR"; $navFooter.ForeColor = $script:C.Green }
else             { $navFooter.Text = "●  SIN PERMISOS DE ADMIN"; $navFooter.ForeColor = $script:C.Yellow }

$navFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$navFlow.Dock = 'Fill'
$navFlow.FlowDirection = 'TopDown'
$navFlow.WrapContents = $false
$navFlow.AutoScroll = $true
$navFlow.Padding = [System.Windows.Forms.Padding]::new((Px 12), (Px 4), (Px 8), 0)
$navFlow.BackColor = $script:C.Panel

$script:Tip = New-Object System.Windows.Forms.ToolTip
$navFlowR = New-Object System.Windows.Forms.FlowLayoutPanel
$navFlowR.Dock = 'Right'
$navFlowR.AutoSize = $true
$navFlowR.AutoSizeMode = 'GrowAndShrink'
$navFlowR.FlowDirection = 'LeftToRight'
$navFlowR.WrapContents = $false
$navFlowR.Padding = [System.Windows.Forms.Padding]::new(0, (Px 12), (Px 10), 0)
$navFlowR.BackColor = $script:C.Panel

function Add-NavSection([string]$Text) {
    $sep = New-Object System.Windows.Forms.Panel
    $sep.Width = (Px 1)
    $sep.Height = (Px 22)
    $sep.BackColor = $script:C.Border
    $sep.Margin = [System.Windows.Forms.Padding]::new((Px 8), (Px 9), (Px 8), 0)
    $navFlow.Controls.Add($sep)
}

$script:NavMeta = @{}
$script:FontIcon = $null
try { $script:FontIcon = New-Object System.Drawing.Font('Segoe MDL2 Assets', [single]11, [System.Drawing.FontStyle]::Regular) } catch { }

function Add-NavButton([string]$Id, [string]$Icon, [string]$Text, $Fore = $null, [string]$Tip = "", [switch]$Right) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = ""
    $b.Tag = $Id
    $script:NavMeta[$Id] = @{ Icon = $Icon; Text = $Text }
    if ($Text -eq "") { $b.Width = (Px 42) }
    else { $b.Width = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $script:FontBase).Width + (Px 50) }
    $b.Height = (Px 40)
    $b.Margin = [System.Windows.Forms.Padding]::new(0, 0, (Px 2), 0)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor = $script:C.Panel
    $b.FlatAppearance.MouseDownBackColor = $script:C.Select
    $b.UseVisualStyleBackColor = $false
    $b.TabStop = $false
    $b.BackColor = $script:C.Panel
    $b.ForeColor = if ($null -ne $Fore) { $Fore } else { $script:C.Text }
    $b.Font = $script:FontBase
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($Tip) { $script:Tip.SetToolTip($b, $Tip) }
    $b.Add_Click({ param($s, $e) Invoke-NavAction ([string]$s.Tag) })
    $b.Add_MouseEnter({ param($s, $e) $s.Invalidate() })
    $b.Add_MouseLeave({ param($s, $e) $s.Invalidate() })
    $b.Add_Paint({
        param($s, $e)
        try {
            $g = $e.Graphics
            $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
            $meta   = $script:NavMeta[[string]$s.Tag]
            $active = ([string]$s.Tag -eq $script:NavActive)
            $hover  = $s.ClientRectangle.Contains($s.PointToClient([System.Windows.Forms.Cursor]::Position))
            if ($s.Enabled -and ($active -or $hover)) {
                $fb = New-Object System.Drawing.SolidBrush((Merge-Color $script:C.Accent $script:C.Panel $(if ($active) { 0.16 } else { 0.08 })))
                $g.FillRectangle($fb, 0, 0, $s.Width, $s.Height)
                $fb.Dispose()
                $ub = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, ($s.Height - (Px 3)), [math]::Max(2, $s.Width), (Px 3))), $script:C.Accent, $script:C.Pink, 0.0)
                $g.FillRectangle($ub, 0, ($s.Height - (Px $(if ($active) { 3 } else { 2 }))), $s.Width, (Px 3))
                $ub.Dispose()
            }
            $fc = if ($s.Enabled) { $s.ForeColor } else { $script:C.Muted }
            $br = New-Object System.Drawing.SolidBrush($fc)
            $sf = New-Object System.Drawing.StringFormat
            $sf.LineAlignment = 'Center'
            $sf.Alignment = 'Center'
            if ([string]$meta.Text -eq "") {
                if ($script:FontIcon) { $g.DrawString([string]$meta.Icon, $script:FontIcon, $br, (New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)), $sf) }
            } else {
                if ($script:FontIcon) { $g.DrawString([string]$meta.Icon, $script:FontIcon, $br, (New-Object System.Drawing.RectangleF((Px 6), 0, (Px 28), $s.Height)), $sf) }
                $sf.Alignment = 'Near'
                $g.DrawString([string]$meta.Text, $script:FontBase, $br, (New-Object System.Drawing.RectangleF((Px 36), 0, ($s.Width - (Px 36)), $s.Height)), $sf)
            }
            $br.Dispose(); $sf.Dispose()
        } catch { }
    })
    $script:NavButtons.Add($b)
    if ($Right) { $navFlowR.Controls.Add($b) } else { $navFlow.Controls.Add($b) }
}

function Ic([int]$Code) { return [string][char]$Code }

Add-NavButton 'global'      (Ic 0xE768) "Auditoría  (F5)" $script:C.Accent
Add-NavButton 'live'        (Ic 0xE8A9) "Resultados"
Add-NavButton 'registry'    (Ic 0xE8A5) "Registro"
Add-NavSection ""
Add-NavButton 'tools'       (Ic 0xE713) "Herramientas  ▾"
Add-NavButton 'manual'      (Ic 0xE838) "Revisión manual"
Add-NavButton 'theme'       (Ic 0xE790) "" -Tip ("Cambiar tema (" + $script:ThemeName + ")") -Right
Add-NavButton 'prank'       (Ic 0xE7B3) "" $script:C.Yellow -Tip "Modo broma (Hackeo)" -Right
Add-NavButton 'panic'       (Ic 0xE711) "" $script:C.Red -Tip "Cerrar ya (cancelar todo)" -Right
Add-NavButton 'exit'        (Ic 0xE7E8) "" $script:C.Muted -Tip "Salir" -Right

function Show-ToolsDropdown {
    $m = New-Object System.Windows.Forms.ContextMenuStrip
    $m.BackColor = $script:C.Panel2
    $m.ForeColor = $script:C.Text
    $m.ShowImageMargin = $false
    foreach ($d in @(@('Doomsday Detector', 'doomsday'), @('System Informer', 'sysinformer'), @('JournalTrace', 'journal'), @('Lilith Services', 'lilith'))) {
        $mi = New-Object System.Windows.Forms.ToolStripMenuItem
        $mi.Text = "   " + $d[0] + "   "
        $mi.Tag = $d[1]
        $mi.Add_Click({ param($s, $e) Invoke-NavAction ([string]$s.Tag) })
        [void]$m.Items.Add($mi)
    }
    $btn = @($script:NavButtons | Where-Object { [string]$_.Tag -eq 'tools' })[0]
    if ($btn) { $m.Show($btn, (New-Object System.Drawing.Point(0, $btn.Height))) }
}

$navPanel.Add_Paint({ param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:C.Border)
    $e.Graphics.DrawLine($pen, ($s.Width - 1), 0, ($s.Width - 1), $s.Height)
    $pen.Dispose()
})
$navPanel.Controls.Add($navFlow)
$navPanel.Controls.Add($navFooter)
$navPanel.Controls.Add($navTitle)
$navEdge = New-Object System.Windows.Forms.Panel
$navEdge.Dock = 'Right'
$navEdge.Width = (Px 2)
$navEdge.BackColor = $script:C.Border
$navEdge.Add_Paint({ param($s, $e)
    try {
        if ($s.Height -gt 2) {
            $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)), $script:C.Accent, $script:C.Bg, 90.0)
            $e.Graphics.FillRectangle($lg, 0, 0, $s.Width, $s.Height)
            $lg.Dispose()
        }
    } catch { }
})
$navPanel.Controls.Add($navEdge)

$script:Form.Controls.Add($mainRight)
$navFlow.Dock = 'Fill'
$navFlow.FlowDirection = 'LeftToRight'
$navFlow.WrapContents = $false
$navFlow.AutoScroll = $false
$navFlow.Padding = [System.Windows.Forms.Padding]::new((Px 6), (Px 12), 0, 0)
$navTitle.Dock = 'Left'
$navTitle.Width = (Px 236)
$topBar = New-Object System.Windows.Forms.Panel
$topBar.Dock = 'Top'
$topBar.Height = (Px 64)
$topBar.BackColor = $script:C.Panel
$topBar.Controls.Add($navFlow)
$topBar.Controls.Add($navFlowR)
$topBar.Controls.Add($navTitle)
$topBar.Add_Paint({ param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:C.Border)
    $e.Graphics.DrawLine($pen, 0, ($s.Height - 1), $s.Width, ($s.Height - 1))
    $pen.Dispose()
})
$script:Form.Controls.Add($topBar)

# --- Atajos de teclado ---
$script:Form.Add_KeyDown({
    param($s, $e)
    try {
        if ($e.KeyCode -eq 'F5') {
            if (-not $script:Busy) { Start-GlobalScan }
            $e.Handled = $true
        } elseif ($e.Control -and $e.KeyCode -eq 'F') {
            if ($script:FilterBar.Visible) { [void]$script:TxtFilter.Focus(); $script:TxtFilter.SelectAll() }
            $e.Handled = $true
        } elseif ($e.Control -and $e.KeyCode -eq 'E') {
            if ($script:Grid.Visible) { Export-GridView }
            $e.Handled = $true
        } elseif ($e.KeyCode -eq 'Escape') {
            if ($script:FilterBar.Visible -and (($script:FilterText) -or $script:FilterLevel -ne 'all')) {
                Clear-Filter
                Show-Category $script:ActiveCat
                $e.Handled = $true
            }
        }
    } catch { }
})

# --- Cierre seguro: si hay un análisis en curso, lo cancela y cierra al terminar ---
$script:Form.Add_FormClosing({
    param($s, $e)
    if ($script:Busy) {
        $e.Cancel = $true
        $script:CancelRequested = $true
        $script:CloseAfter = $true
        Set-Status "Cerrando: se está terminando el archivo en curso..."
    }
})
$script:Form.Add_FormClosed({
    try { if ($script:HiddenConsole -ne [IntPtr]::Zero) { [void][Sombrio.WinApi]::ShowWindow($script:HiddenConsole, 5) } } catch { }
})
$script:Form.Add_HandleCreated({ Set-DarkTitleBar $script:Form })
$script:Form.Add_Shown({ Move-HomeArt })

# ============================================================
# SPLASH SCREEN (pantalla de carga estética)
# ============================================================
try {
    $splash = New-Object System.Windows.Forms.Form
    $splash.FormBorderStyle = 'None'
    $splash.StartPosition = 'CenterScreen'
    $splash.ClientSize = New-Object System.Drawing.Size((Px 460), (Px 240))
    $splash.BackColor = $script:C.Panel
    $splash.TopMost = $true
    $splash.ShowInTaskbar = $false
    $splash.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen($script:C.Border)
        $e.Graphics.DrawRectangle($pen, 0, 0, ($s.Width - 1), ($s.Height - 1))
        $pen.Dispose()
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $s.Width, (Px 3))), $script:C.Accent, $script:C.Pink, 0.0)
        $e.Graphics.FillRectangle($br, 0, 0, $s.Width, (Px 3))
        $br.Dispose()
    })

    $lblSplashTitle = New-Object System.Windows.Forms.Label
    $lblSplashTitle.Text = "EL SOMBRIO IF"
    $lblSplashTitle.Font = $fontTitle
    $lblSplashTitle.ForeColor = $script:C.Text
    $lblSplashTitle.AutoSize = $false
    $lblSplashTitle.TextAlign = 'MiddleCenter'
    $lblSplashTitle.SetBounds(0, (Px 54), (Px 460), (Px 40))
    $splash.Controls.Add($lblSplashTitle)

    $lblSplashSub = New-Object System.Windows.Forms.Label
    $lblSplashSub.Text = "FORENSIC SCANNER  ·  V80"
    $lblSplashSub.Font = $fontSmall
    $lblSplashSub.ForeColor = $script:C.Accent
    $lblSplashSub.AutoSize = $false
    $lblSplashSub.TextAlign = 'MiddleCenter'
    $lblSplashSub.SetBounds(0, (Px 96), (Px 460), (Px 22))
    $splash.Controls.Add($lblSplashSub)

    $lblSplashStatus = New-Object System.Windows.Forms.Label
    $lblSplashStatus.Text = "Iniciando..."
    $lblSplashStatus.Font = $script:FontBase
    $lblSplashStatus.ForeColor = $script:C.Muted
    $lblSplashStatus.AutoSize = $false
    $lblSplashStatus.TextAlign = 'MiddleCenter'
    $lblSplashStatus.SetBounds(0, (Px 160), (Px 460), (Px 24))
    $splash.Controls.Add($lblSplashStatus)

    $splashBar = New-Object System.Windows.Forms.Panel
    $splashBar.BackColor = $script:C.Panel2
    $splashBar.SetBounds((Px 70), (Px 196), (Px 320), (Px 4))
    $splash.Controls.Add($splashBar)

    $splashFill = New-Object System.Windows.Forms.Panel
    $splashFill.BackColor = $script:C.Accent
    $splashFill.SetBounds(0, 0, 0, (Px 4))
    $splashBar.Controls.Add($splashFill)

    $splashMsgs = @('Cargando módulos...', 'Preparando reglas de detección...', 'Construyendo la interfaz...', 'Listo')
    $splash.Show()
    for ($i = 0; $i -le 100; $i += 4) {
        $splashFill.Width = [int]($splashBar.Width * $i / 100)
        $lblSplashStatus.Text = $splashMsgs[[math]::Min(3, [int]($i / 26))]
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }
    Start-Sleep -Milliseconds 150
    $splash.Close()
    $splash.Dispose()
} catch { }

# ============================================================
# ARRANQUE
# ============================================================
Show-Home
[System.Windows.Forms.Application]::Run($script:Form)
