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
# ============================================================

$script:AutoElevate     = $true   # $true = pedir permisos de Administrador (UAC) al abrir
$script:DoomsdayRepo     = "https://github.com/jgonzalo17/Doomsday-Detector.git"
$script:DoomsdayScript   = "elsombrio.ps1"   # nombre exacto del detector dentro del repo
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
$script:NavButtons      = [System.Collections.Generic.List[object]]::new()
$script:JarVersionProbes = 0           # límite de aperturas de .jar para detectar versión
$script:ContentProbes   = 0           # V76 - límite de lecturas de contenido/metadatos
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
}
$script:ThemeFile = Join-Path $env:APPDATA 'ElSombrio\theme.txt'
$script:ThemeName = 'Slate'
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
    if (-not [string]::IsNullOrWhiteSpace($Path) -and $script:JarVersionProbes -lt 600 -and (Test-Path -LiteralPath $Path)) {
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
    if ($script:ContentProbes -ge 600) { return $null }
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
    if ($Text -match 'ILEGAL|MALICIOSO|AUTOCLICK|AUTOCICK|HACK\b|PELIGRO|CRITICO|MACRO|RENOMBRADO|EXTENSIÓN FALSA|ADS SOSPECHOSO|VENTANA CHEAT|AUTOARRANQUE|SPOOF|ELIMINADO SOSPECHOSO') { return "Red" }
    if ($Text -match 'SOSPECHOSO') { return "Yellow" }
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
    @{ Key = "Memoria";    Text = "MEMORIA" },
    @{ Key = "Prefetch";   Text = "PREFETCH" },
    @{ Key = "Papelera";   Text = "PAPELERA" },
    @{ Key = "Maliciosos"; Text = "MALICIOSOS" },
    @{ Key = "Mods";       Text = "MODS" },
    @{ Key = "Macros";     Text = "MACROS" },
    @{ Key = "Servicios";  Text = "SERVICIOS" },
    @{ Key = "Disco";      Text = "DISCO PROFUNDO" },
    @{ Key = "Historial";  Text = "HISTORIAL" }
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
    Sh... (Tiempo restante: 85 KB)
