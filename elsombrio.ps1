#Requires -Version 5.1

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V76) - EDICIÓN APP (GUI)
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
$script:SelfUrl         = "https://raw.githubusercontent.com/jgonzalo17/Doomsday-Detector/main/Sombrio_V76_GUI.ps1"
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
                Start-Process -FilePath $psExe -ArgumentList $argLine -Verb RunAs -WindowStyle Hidden -ErrorAction Stop
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
# PALETA DE COLORES (V76 - ROJO / NEGRO / VERDE)
# ------------------------------------------------------------
$script:C = @{
    Bg      = [System.Drawing.Color]::FromArgb(8, 4, 6)
    Panel   = [System.Drawing.Color]::FromArgb(16, 8, 10)
    Panel2  = [System.Drawing.Color]::FromArgb(28, 12, 14)
    Row2    = [System.Drawing.Color]::FromArgb(20, 10, 12)
    Border  = [System.Drawing.Color]::FromArgb(140, 40, 46)
    Hover   = [System.Drawing.Color]::FromArgb(70, 20, 24)
    Select  = [System.Drawing.Color]::FromArgb(95, 26, 30)
    Accent  = [System.Drawing.Color]::FromArgb(255, 84, 92)
    Pink    = [System.Drawing.Color]::FromArgb(255, 84, 92)   # ahora es rojo
    Blue    = [System.Drawing.Color]::FromArgb(80, 220, 140)  # ahora es verde claro
    DBlue   = [System.Drawing.Color]::FromArgb(45, 150, 95)
    Text    = [System.Drawing.Color]::FromArgb(245, 235, 235)
    Muted   = [System.Drawing.Color]::FromArgb(190, 140, 145)
    Red     = [System.Drawing.Color]::FromArgb(255, 70, 84)
    RedDark = [System.Drawing.Color]::FromArgb(150, 30, 40)
    Green   = [System.Drawing.Color]::FromArgb(80, 255, 140)
    Yellow  = [System.Drawing.Color]::FromArgb(255, 200, 90)
    TealDim = [System.Drawing.Color]::FromArgb(140, 200, 170)
}

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
    if ($FileName -and $script:RxMcVersion.IsMatch($FileName)) {
        return (($script:RxMcVersion.Match($FileName).Value) -replace '_', '.')
    }
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $parent = Split-Path -Path $Path -Parent -ErrorAction SilentlyContinue
        if ($parent -and $script:RxMcVersion.IsMatch($parent)) {
            return (($script:RxMcVersion.Match($parent).Value) -replace '_', '.')
        }
        # Abrir el .jar solo un número limitado de veces para no frenar el escaneo
        if ($script:JarVersionProbes -lt 400 -and (Test-Path -LiteralPath $Path)) {
            try {
                $len = (Get-Item -LiteralPath $Path -ErrorAction Stop).Length
                if ($len -lt 80MB) {
                    $script:JarVersionProbes++
                    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
                    try {
                        foreach ($metaName in @('fabric.mod.json', 'quilt.mod.json', 'neoforge.mods.toml', 'META-INF/mods.toml', 'mcmod.info')) {
                            $entry = $zip.GetEntry($metaName)
                            if (-not $entry) { continue }
                            $sr = New-Object System.IO.StreamReader($entry.Open())
                            try { $txt = $sr.ReadToEnd() } finally { $sr.Dispose() }
                            if ($txt -match '"minecraft"\s*:\s*"[^"]*?(1[._]\d{1,2}([._]\d+)?)') {
                                return (("1." + $Matches[1]) + $(if ($Matches[2]) { ($Matches[2] -replace '_','.') } else { '' }))
                            }
                            if ($txt -match 'versionRange\s*=\s*"?\[?~?>=<\s]*1[._](\d{1,2})([._]\d+)?') {
                                return (("1." + $Matches[1]) + $(if ($Matches[2]) { ($Matches[2] -replace '_','.') } else { '' }))
                            }
                            if ($txt -match 'acceptedMinecraftVersions\s*=\s*"?\[?1[._](\d{1,2})([._]\d+)?') {
                                return (("1." + $Matches[1]) + $(if ($Matches[2]) { ($Matches[2] -replace '_','.') } else { '' }))
                            }
                        }
                    } finally { $zip.Dispose() }
                }
            } catch { }
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
    foreach ($it in @($ModItems)) {
        $path = ""
        if ([string]$it -match '\|\s*Ruta:\s*(.+?)\s*$') { $path = $Matches[1].Trim() }
        $name = if ($path) { [IO.Path]::GetFileName($path) } else { "" }
        $ver  = Get-JarMcVersion -Path $path -FileName $name
        if (-not $groups.Contains($ver)) { $groups[$ver] = [System.Collections.Generic.List[string]]::new() }
        $groups[$ver].Add([string]$it)
    }
    $sortedKeys = @($groups.Keys | Sort-Object -Descending {
        if ($_ -eq 'Desconocida') { [version]'0.0.0' } else { try { [version]$_ } catch { [version]'0.0.1' } }
    })
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($vk in $sortedKeys) {
        $result.Add("====== MINECRAFT $vk ======")
        foreach ($m in (@($groups[$vk]) | Sort-Object { if ($_ -match 'ILEGAL') { 0 } else { 1 } })) {
            $result.Add($m)
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
    if ($Text -match 'ILEGAL|MALICIOSO|AUTOCLICK|AUTOCICK|HACK\b|PELIGRO|CRITICO|MACRO|RENOMBRADO|EXTENSIÓN FALSA|ADS SOSPECHOSO|VENTANA CHEAT|AUTOARRANQUE|SPOOF') { return "Red" }
    if ($script:RxJavaNames.IsMatch($Text) -or $Text -match '\[JAVA\]') { return "Green" }
    if ($Text -match 'APROBADO|NORMAL|RUNNING|OK|\[MOD') { return "Green" }
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

    $detail = [string]$row.Cells[2].Value
    $path = ""
    if ($detail -match 'Ruta original:\s*(.*?)\s*\|\s*Eliminado:') {
        $path = $Matches[1].Trim()
    } elseif ($detail -match 'Ruta:\s*(.*?)(?:\s*\|\s*Eliminado:|$)') {
        $path = $Matches[1].Trim()
    }
    if ([string]::IsNullOrWhiteSpace($path)) {
        Show-Info "Esta fila no contiene una ruta de archivo abrible." "RUTA"
        return
    }
    Open-SelectedPath -Path $path
}

# ============================================================
# PROGRESO / ESTADO
# ============================================================
function Set-Status([string]$Text) {
    $script:LblStatus.Text = $Text
    Invoke-UiPump
}

function Set-Progress([int]$Pct) {
    $Pct = [math]::Max(0, [math]::Min(100, $Pct))
    $script:ProgressPct = $Pct
    $script:LblPct.Text = "$Pct%"
    $script:BarFill.Width = [int]($script:BarTrack.ClientSize.Width * $Pct / 100)
}

function Set-Phase([int]$Step, [int]$Total, [string]$Text) {
    Set-Status $Text
    Set-Progress ([math]::Round((($Step - 1) / $Total) * 100))
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
    $ts = "{0:hh\:mm\:ss}" -f $elapsed
    $script:LblDetail.Text = ("{0:N0} archivos  |  {1:N0} arch/s  |  Rojos: {2}  |  {3}   >   {4}" -f $Scanned, $speed, $Hits, $ts, $CurrentFile)
    Set-Progress $Percent
    Invoke-UiPump
}

function Start-ScanSession([string]$Text) {
    $script:Busy = $true
    $script:CancelRequested = $false
    foreach ($b in $script:NavButtons) {
        if ($b.Tag -notin @('panic', 'exit')) { $b.Enabled = $false }
    }
    $script:BtnCancel.Visible = $true
    $script:BtnReport.Visible = $false
    $script:BtnOpenSelected.Visible = $false
    $script:LblDetail.Text = ""
    Set-Progress 0
    Set-Status $Text
}

function Stop-ScanSession {
    $script:Busy = $false
    foreach ($b in $script:NavButtons) { $b.Enabled = $true }
    $script:BtnCancel.Visible = $false
    if ($script:LastReport -and (Test-Path -LiteralPath $script:LastReport)) { $script:BtnReport.Visible = $true }
    $script:BtnOpenSelected.Visible = $true
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
    @{ Key = "Disco";      Text = "DISCO PROFUNDO" }
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
        $btn.ForeColor = if ($hasRed) { $script:C.Red } else { $script:C.Text }
        $btn.BackColor = if ($active) { $script:C.Select } else { $script:C.Panel2 }
        $btn.FlatAppearance.BorderColor = if ($active) { $script:C.Green } elseif ($hasRed) { $script:C.RedDark } else { $script:C.Border }
    }
}

function Show-Category([string]$Key) {
    $script:ActiveCat = $Key
    $items = @(Get-CatItems $Key)
    $g = $script:Grid
    $g.SuspendLayout()
    $g.Rows.Clear()

    if ($items.Count -eq 0) {
        $i = $g.Rows.Add("", "Sin hallazgos registrados.", "---")
        $g.Rows[$i].DefaultCellStyle.ForeColor = $script:C.Green
    } else {
        foreach ($it in $items) {
            $p = Split-ReportItem ([string]$it)
            $i = $g.Rows.Add($p.Tag, $p.Name, $p.Detail)
            $row = $g.Rows[$i]
            if ($Key -eq "Papelera" -and $script:RecycleMeta.ContainsKey([string]$it)) {
                $row.Tag = $script:RecycleMeta[[string]$it]
            }
            if ($p.Header) {
                # V75: encabezados de versión de Minecraft en magenta, el resto en teal
                $row.DefaultCellStyle.ForeColor = if ($p.Name -match 'MINECRAFT') { $script:C.Green } else { $script:C.TealDim }
                $row.DefaultCellStyle.Font = $script:FontBold
            } elseif ($Key -eq 'Maliciosos') {
                $row.DefaultCellStyle.ForeColor = $script:C.Red
            } else {
                $row.DefaultCellStyle.ForeColor = ConvertTo-UiColor (Get-ItemColor ([string]$it))
            }
        }
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
    $script:HomeArt.Visible  = $true
    $script:LblView.Text  = "CONSOLA CENTRAL DE OPERACIONES FORENSES"
    Move-HomeArt
}

function Show-Results {
    if ($script:BtnOpenSelected) { $script:BtnOpenSelected.Visible = $true }
    $script:HomeArt.Visible  = $false
    $script:Grid.Visible  = $true
    $script:Chips.Visible = $true
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
# REPORTE FORENSE (Escritorio)
# ============================================================
function Save-Report {
    param($Sections)
    $path = Join-Path ([Environment]::GetFolderPath("Desktop")) "Reporte_Sombrio_V76.txt"
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("===============================================================")
    [void]$sb.AppendLine(" REPORTE FORENSE - EL SOMBRIO IF V76")
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
                foreach ($sd in $di.GetDirectories()) {
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
                # .jar de cualquier carpeta del disco = posible mod (la carpeta .minecraft\mods se audita aparte)
                $isJar = ($null -ne $Mods -and $f.Extension -eq '.jar' -and -not $full.StartsWith($script:DefaultModsPath, [StringComparison]::OrdinalIgnoreCase))
                if ($isJar) { $script:DiskModCount++ }
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
                        $Mods.Add("[MOD ILEGAL] $($f.Name) | Ruta: $full")
                        $Maliciosos.Add("[MOD ILEGAL] $($f.Name) | Ruta: $full")
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
    Start-ScanSession "Iniciando auditoría global..."
    try {
        $memoria     = [System.Collections.Generic.List[string]]::new()
        $prefetchHoy = [System.Collections.Generic.List[string]]::new()
        $maliciosos  = [System.Collections.Generic.List[string]]::new()
        $mods        = [System.Collections.Generic.List[string]]::new()
        $macros      = [System.Collections.Generic.List[string]]::new()
        $servicios   = [System.Collections.Generic.List[string]]::new()
        $disco       = [System.Collections.Generic.List[string]]::new()
        $statsBox    = [System.Collections.Generic.List[string]]::new()

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
                        } elseif ($script:RxHacks.IsMatch($mod.Name) -or $mod.Length -lt 15KB) {
                            $mods.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                            $maliciosos.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                        } else {
                            $mods.Add("[MOD APROBADO] $($mod.Name) | Ruta: $($mod.FullName)")
                        }
                    }
                }
            } catch { }
        }

        # 5 - Macros (V75: procesos + software instalado + startup)
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 5 7 "5/7  Verificando Macros, Autoclickers y software de periféricos..."
                foreach ($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
                    $macros.Add("[PROCESO MALICIOSO] $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
                    $maliciosos.Add("[EN MEMORIA] $($proc.Name).exe | PID: $($proc.Id)")
                }
                $uninstallKeys = @(
                    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
                foreach ($app in (Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $script:RxMacroCritical.IsMatch($_.DisplayName) })) {
                    $loc = if ($app.InstallLocation) { $app.InstallLocation } else { "Registro de Windows" }
                    $macros.Add("[SOFTWARE MACRO INSTALADO] $($app.DisplayName) | Ruta: $loc")
                    $maliciosos.Add("[SOFTWARE MACRO] $($app.DisplayName) | Ruta: $loc")
                }
                foreach ($kp in @(
                    @{ Path = "$env:USERPROFILE\AppData\Local\LGHUB\settings.db"; Name = "Logitech G HUB" },
                    @{ Path = "$env:APPDATA\AutoHotkey"; Name = "AutoHotkey" }
                )) {
                    if (Test-Path $kp.Path) {
                        $macros.Add("[SOFTWARE MACRO INSTALADO] $($kp.Name) | Ruta: $($kp.Path)")
                        $maliciosos.Add("[SOFTWARE MACRO] $($kp.Name) | Ruta: $($kp.Path)")
                    }
                }
                try {
                    $startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
                    if (Test-Path $startup) {
                        foreach ($f in (Get-ChildItem -Path $startup -Recurse -File -Include *.exe,*.ahk,*.au3,*.vbs,*.bat,*.ps1 -ErrorAction SilentlyContinue)) {
                            if ($script:RxMacroCritical.IsMatch($f.Name)) {
                                $macros.Add("[ARCHIVO MACRO] $($f.Name) | Ruta: $($f.FullName)")
                                $maliciosos.Add("[ARCHIVO MACRO] $($f.Name) | Ruta: $($f.FullName)")
                            }
                        }
                    }
                } catch { }
                Add-ToLog $script:LogMacros $macros
            } catch { }
        }

        # 6 - Servicios
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 6 7 "6/7  Evaluando Servicios de Windows..."
                foreach ($service in @("pcasvc", "bam", "sysmain")) {
                    $output = @(& sc.exe query $service 2>&1) -join "`n"
                    if ($output -match 'STOPPED') {
                        $servicios.Add("[PELIGRO] SERVICIO APAGADO: $service | Estado: STOPPED")
                    } else {
                        $servicios.Add("[SERVICIO OK] $service | Estado: RUNNING")
                    }
                }
                Add-ToLog $script:LogServicios $servicios
            } catch { }
        }

        # 7 - Disco
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 7 7 "7/7  Escaneo profundo de discos (omitiendo Windows)..."
                Invoke-DiskScan -Disco $disco -Maliciosos $maliciosos -Mods $mods -StartTime $scanStart -BasePct 86 -SpanPct 14
                Add-ToLog $script:LogDisco $disco
            } catch { }
        }

        # V75 - Mods separados por versión de Minecraft (ilegales primero dentro de cada grupo)
        $modsGrouped = [System.Collections.Generic.List[string]](Group-ModsByVersion $mods)
        $verCount = @($modsGrouped | Where-Object { $_ -match '^=+\s*MINECRAFT' }).Count
        Add-ToLog $script:LogMods $modsGrouped
        $cMods += $script:DiskModCount

        $statsBox.Add("====== ELEMENTOS PROCESADOS ======")
        $statsBox.Add("Procesos activos en Memoria RAM | Total: $cRam")
        $statsBox.Add("Archivos en Prefetch evaluados | Total: $cPref")
        $statsBox.Add("Archivos en Papelera de Reciclaje | Total: $cPap")
        $statsBox.Add("Mods analizados (.minecraft + todo el disco) | Total: $cMods")
        $statsBox.Add("Versiones de Minecraft detectadas | Total: $verCount")
        $statsBox.Add("Firmas de contenido anti-bypass revisadas | Total: $script:ContentProbes")
        $statsBox.Add("Servicios críticos de Windows | Total: $cSvc")
        $statsBox.Add("Archivos de disco escaneados | Total: $script:ScanCount")
        $statsBox.Add("====== RESULTADO DE AMENAZAS ======")
        $statsBox.Add("Hallazgos Maliciosos Confirmados (ROJOS) | Total: $($maliciosos.Count)")

        try {
            Set-Status "Generando reporte forense..."
            $script:LastReport = Save-Report ([ordered]@{
                "ESTADÍSTICAS"           = $statsBox
                "MEMORIA / PROCESOS"     = $memoria
                "PREFETCH DE HOY"        = $prefetchHoy
                "PAPELERA DE RECICLAJE" = $papeleraData
                "MALICIOSOS"             = $maliciosos
                "MODS (POR VERSIÓN)"     = $modsGrouped
                "MACROS / AUTOCLICKERS"  = $macros
                "SERVICIOS"              = $servicios
                "DISCO PROFUNDO"         = $disco
            })
        } catch { $script:LastReport = $null }

        $focus = if ($maliciosos.Count -gt 0) { 'Maliciosos' } else { 'Stats' }
        Publish-Results -Data @{
            Stats = $statsBox; Memoria = $memoria; Prefetch = $prefetchHoy; Papelera = $papeleraData; Maliciosos = $maliciosos
            Mods = $modsGrouped; Macros = $macros; Servicios = $servicios; Disco = $disco
        } -Focus $focus

        Set-Progress 100
        $elapsed = (Get-Date) - $scanStart
        $adminNote = if (Test-Administrator) { "" } else { "  (sin administrador: Prefetch y servicios pueden estar limitados)" }
        if ($script:CancelRequested) {
            Set-Status "Escaneo cancelado por el usuario. Se muestran resultados parciales."
        } else {
            Set-Status ("Escaneo completado  ·  {0:N0} archivos  ·  {1} hallazgos maliciosos  ·  {2:hh\:mm\:ss}{3}" -f $script:ScanCount, $maliciosos.Count, $elapsed, $adminNote)
        }
    } finally {
        Stop-ScanSession
    }
}

function Start-UnifiedModScan {
    Start-ScanSession "Buscando mods en todo el disco..."
    try {
        $mods  = [System.Collections.Generic.List[string]]::new()
        $disco = [System.Collections.Generic.List[string]]::new()
        $mal   = [System.Collections.Generic.List[string]]::new()
        $script:ScanCount = 0
        $script:DeepHits  = 0
        $script:DiskModCount = 0
        $script:JarVersionProbes = 0
        $script:ContentProbes   = 0
        $scanStart = Get-Date

        # 1) Carpeta .minecraft\mods (jar, zip)
        if (Test-Path $script:DefaultModsPath) {
            $files = @(Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip" -ErrorAction SilentlyContinue)
            foreach ($mod in $files) {
                $innerMod = Test-JarContentSuspicious -Path $mod.FullName
                if ($innerMod) {
                    $mods.Add("[MOD ILEGAL RENOMBRADO] $($mod.Name) | Ruta: $($mod.FullName) | Contenido: $innerMod")
                } elseif ($script:RxHacks.IsMatch($mod.Name)) {
                    $mods.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                } else {
                    $mods.Add("[MOD APROBADO] $($mod.Name) | Ruta: $($mod.FullName)")
                }
            }
        }

        # 2) Todos los .jar del resto de discos (Launchers, instancias, Descargas, otras unidades...)
        Invoke-DiskScan -Disco $disco -Maliciosos $mal -Mods $mods -StartTime $scanStart -BasePct 0 -SpanPct 100

        # V75 - separar por versión
        $sorted = [System.Collections.Generic.List[string]](Group-ModsByVersion $mods)
        $verCount = @($sorted | Where-Object { $_ -match '^=+\s*MINECRAFT' }).Count
        Add-ToLog $script:LogMods $sorted
        Publish-Results -Data @{ Mods = $sorted } -Focus 'Mods'
        Set-Progress 100
        $ilegales = @($sorted | Where-Object { $_ -match 'ILEGAL' }).Count
        if ($script:CancelRequested) {
            Set-Status ("Búsqueda cancelada  ·  {0} mods encontrados hasta ahora  ·  {1} ilegales" -f $sorted.Count, $ilegales)
        } else {
            Set-Status ("Auditoría de mods completada  ·  {0} mods en {1} versiones  ·  {2} ilegales  ·  {3:N0} archivos revisados" -f (@($sorted | Where-Object { $_ -notmatch '======' })).Count, $verCount, $ilegales, $script:ScanCount)
        }
    } finally { Stop-ScanSession }
}

function Start-RecycleBinScan {
    Start-ScanSession "Analizando Papelera de Reciclaje..."
    try {
        $papeleraData = [System.Collections.Generic.List[string]]::new()
        $mal = [System.Collections.Generic.List[string]]::new()
        $script:RecycleMeta = @{}

        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)

        if ($papelera) {
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
                    $mal.Add("[PAPELERA HACK] $name | Ruta original: $originalPath | Eliminado: $deletedText")
                }
            }
        }

        Add-ToLog $script:LogPapelera $papeleraData
        Publish-Results -Data @{ Papelera = $papeleraData; Maliciosos = $mal } -Focus 'Papelera'
        Set-Progress 100
        Set-Status ("Papelera analizada  ·  {0} elementos  ·  selecciona un archivo y pulsa ABRIR SELECCIONADO o haz doble clic" -f $papeleraData.Count)
    } catch {
        Set-Status ("Error al analizar la Papelera: " + $_.Exception.Message)
    } finally {
        Stop-ScanSession
    }
}

function Start-TraceScan {
    Start-ScanSession "Analizando Prefetch..."
    try {
        $todo = [System.Collections.Generic.List[string]]::new()
        $hoy = (Get-Date).Date
        $pfFiles = @(Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue |
                   Where-Object { $_.LastWriteTime.Date -ge $hoy } | Sort-Object LastWriteTime -Descending)
        foreach ($item in $pfFiles) {
            if ($script:RxHacks.IsMatch($item.Name)) {
                $todo.Add("[PREFETCH MALICIOSO] $($item.Name) | Hora: $($item.LastWriteTime)")
            } else {
                $todo.Add("[PREFETCH NORMAL] $($item.Name) | Hora: $($item.LastWriteTime)")
            }
        }
        Add-ToLog $script:LogPrefetch $todo
        Publish-Results -Data @{ Prefetch = $todo } -Focus 'Prefetch'
        Set-Progress 100
        $note = if ((-not (Test-Administrator)) -and $todo.Count -eq 0) { "  (ejecuta como administrador para leer Prefetch)" } else { "" }
        Set-Status ("Prefetch de hoy analizado  ·  {0} entradas{1}" -f $todo.Count, $note)
    } finally { Stop-ScanSession }
}

# ------------------------------------------------------------
# V75 - Búsqueda de MACROS mejorada:
#   1) Procesos activos
#   2) Software instalado (registro de desinstalación)
#   3) Tareas programadas sospechosas
#   4) Servicios con nombres sospechosos
#   5) Archivos en Escritorio, Descargas y carpeta de Inicio
# ------------------------------------------------------------
function Start-MacroAutoclickScan {
    Start-ScanSession "Buscando macros, autoclickers y software de periféricos..."
    try {
        $macros = [System.Collections.Generic.List[string]]::new()
        $mal    = [System.Collections.Generic.List[string]]::new()

        # 1) Procesos activos
        foreach ($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
            $macros.Add("[PROCESO MALICIOSO] $($proc.Name).exe | PID: $($proc.Id)")
            $mal.Add("[EN MEMORIA] $($proc.Name).exe | PID: $($proc.Id)")
        }

        # 2) Software instalado (registro HKCU/HKLM, incluido WOW6432Node)
        try {
            $uninstallKeys = @(
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
            foreach ($app in (Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $script:RxMacroCritical.IsMatch($_.DisplayName) })) {
                $loc = if ($app.InstallLocation) { $app.InstallLocation } elseif ($app.UninstallString) { $app.UninstallString } else { "Registro de Windows" }
                $macros.Add("[SOFTWARE MACRO INSTALADO] $($app.DisplayName) | Ruta: $loc")
                $mal.Add("[SOFTWARE MACRO] $($app.DisplayName) | Ruta: $loc")
            }
        } catch { }

        # 3) Tareas programadas sospechosas
        try {
            foreach ($task in (Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.Actions })) {
                foreach ($act in $task.Actions) {
                    $target = (([string]$act.Execute) + " " + ([string]$act.Arguments)).Trim()
                    if ($target -and $script:RxMacroCritical.IsMatch($target)) {
                        $macros.Add("[TAREA PROGRAMADA SOSPECHOSA] $($task.TaskPath)$($task.TaskName) | Ruta: $target")
                        $mal.Add("[TAREA PROGRAMADA] $($task.TaskPath)$($task.TaskName) | Ruta: $target")
                        break
                    }
                }
            }
        } catch { }

        # 4) Servicios con nombres sospechosos
        try {
            foreach ($srv in (Get-Service -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch(($_.Name + " " + $_.DisplayName)) })) {
                $macros.Add("[SERVICIO MACRO] $($srv.Name) ($($srv.DisplayName)) | Estado: $($srv.Status)")
                $mal.Add("[SERVICIO MACRO] $($srv.Name) | Estado: $($srv.Status)")
            }
        } catch { }

        # 5) Archivos en carpetas de usuario y carpeta de Inicio
        try {
            $roots = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup") | Where-Object { Test-Path $_ }
            foreach ($root in $roots) {
                foreach ($f in (Get-ChildItem -Path $root -Recurse -Depth 3 -File -Include *.exe,*.ahk,*.au3,*.vbs,*.bat,*.ps1,*.cmd -ErrorAction SilentlyContinue)) {
                    if ($script:RxMacroCritical.IsMatch($f.Name)) {
                        $macros.Add("[ARCHIVO MACRO] $($f.Name) | Ruta: $($f.FullName)")
                        $mal.Add("[ARCHIVO MACRO] $($f.Name) | Ruta: $($f.FullName)")
                    }
                    # V76 - Autoclicker renombrado (metadatos PE internos)
                    if ($f.Extension -eq '.exe') {
                        $peHit = Test-PeSuspicious -Path $f.FullName
                        if ($peHit) {
                            $macros.Add("[AUTOCLICKER RENOMBRADO] $($f.Name) | Ruta: $($f.FullName) | Nombre interno: $peHit")
                            $mal.Add("[AUTOCLICKER RENOMBRADO] $($f.Name) | Ruta: $($f.FullName) | Nombre interno: $peHit")
                        }
                    }
                }
            }
        } catch { }

        # V76 - Autoarranque: claves Run / RunOnce (HKCU y HKLM, 32/64 bits)
        try {
            $runKeys = @(
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
                'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce')
            foreach ($rk in $runKeys) {
                $key = Get-Item -Path $rk -ErrorAction SilentlyContinue
                if (-not $key) { continue }
                foreach ($val in $key.GetValueNames()) {
                    $data = [string]$key.GetValue($val)
                    if ($data -and $script:RxMacroCritical.IsMatch("$val $data")) {
                        $macros.Add("[AUTOARRANQUE] $val | Ruta: $rk -> $data")
                        $mal.Add("[AUTOARRANQUE] $val | Ruta: $rk -> $data")
                    }
                }
            }
        } catch { }

        Add-ToLog $script:LogMacros $macros
        Publish-Results -Data @{ Macros = $macros; Maliciosos = $mal } -Focus 'Macros'
        Set-Progress 100
        Set-Status ("Búsqueda de macros completada  ·  {0} hallazgos (procesos, software instalado, tareas, servicios y archivos)" -f $macros.Count)
    } finally { Stop-ScanSession }
}

function Start-ServicesAudit {
    Start-ScanSession "Auditando servicios de Windows..."
    try {
        $servicios = [System.Collections.Generic.List[string]]::new()
        foreach ($srvName in $script:WindowsServices) {
            $srv = Get-Service -Name $srvName -ErrorAction SilentlyContinue
            if ($srv) {
                $servicios.Add("$($srv.Name) ($($srv.DisplayName)) | Estado: $($srv.Status)")
            }
        }
        Add-ToLog $script:LogServicios $servicios
        Publish-Results -Data @{ Servicios = $servicios } -Focus 'Servicios'
        Set-Progress 100
        Set-Status ("Auditoría de servicios completada  ·  {0} servicios" -f $servicios.Count)
    } finally { Stop-ScanSession }
}

# ------------------------------------------------------------
# OPCIÓN 03: DOOMSDAY DETECTOR (repositorio de GitHub -> se abre en tu PowerShell)
# ------------------------------------------------------------
function Select-ScriptFile {
    param([string[]]$Names)
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "DOOMSDAY DETECTOR - ELEGIR SCRIPT"
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $dlg.ClientSize = New-Object System.Drawing.Size(520, 330)
    $dlg.BackColor = $script:C.Bg
    $dlg.ForeColor = $script:C.Text
    $dlg.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "El repositorio tiene varios scripts. Elige cuál ejecutar:"
    $lbl.Location = New-Object System.Drawing.Point(20, 16)
    $lbl.AutoSize = $true
    $lbl.ForeColor = $script:C.Accent
    $dlg.Controls.Add($lbl)

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.SetBounds(20, 46, 480, 216)
    $lb.BackColor = $script:C.Panel
    $lb.ForeColor = $script:C.Text
    $lb.BorderStyle = 'FixedSingle'
    $lb.Font = New-Object System.Drawing.Font("Consolas", 10)
    foreach ($n in $Names) { [void]$lb.Items.Add($n) }
    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }
    $dlg.Controls.Add($lb)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "EJECUTAR"
    $ok.SetBounds(20, 278, 236, 36)
    Set-FlatButtonStyle $ok $script:C.Panel2 $script:C.Accent $script:C.Border
    $ok.DialogResult = 'OK'
    $dlg.Controls.Add($ok)
    $dlg.AcceptButton = $ok

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "CANCELAR"
    $cancel.SetBounds(264, 278, 236, 36)
    Set-FlatButtonStyle $cancel $script:C.Bg $script:C.Muted $script:C.Border
    $cancel.DialogResult = 'Cancel'
    $dlg.Controls.Add($cancel)
    $dlg.CancelButton = $cancel

    $result = $null
    if ($dlg.ShowDialog($script:Form) -eq 'OK' -and $lb.SelectedItem) { $result = [string]$lb.SelectedItem }
    $dlg.Dispose()
    return $result
}

function Start-Doomsday {
    $title = "DOOMSDAY DETECTOR"
    $rawUrl = "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1"

    $ans = [System.Windows.Forms.MessageBox]::Show(
        "Se ejecutará directamente Doomsday Detector desde:`n`n$rawUrl`n`nSe abrirá una nueva ventana de PowerShell y se ejecutará el detector.`n`n¿Continuar?",
        $title, 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }

    try {
        $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $psExe)) { $psExe = 'powershell.exe' }

        # Windows PowerShell 5.1 no admite &&. Usamos ; y ejecutamos exactamente
        # el mismo flujo: Bypass -> Invoke-RestMethod -> Invoke-Expression.
        $command = "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; Invoke-Expression (Invoke-RestMethod '$rawUrl')"

        $proc = Start-Process -FilePath $psExe `
            -ArgumentList @(
                '-NoLogo',
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-NoExit',
                '-Command', $command
            ) `
            -WindowStyle Normal `
            -PassThru `
            -ErrorAction Stop

        Set-Status ("Doomsday Detector iniciado  ·  PID {0}" -f $proc.Id)
    }
    catch {
        Set-Status "No se pudo iniciar Doomsday Detector."
        Show-Info "No se pudo abrir PowerShell para ejecutar el detector.`n`nURL:`n$rawUrl`n`nError:`n$($_.Exception.Message)" $title
    }
}

# ------------------------------------------------------------
# V75 - OPCIÓN 11: LILITH SERVICES (lilith-ps)
# ------------------------------------------------------------
function Start-LilithServices {
    $title = "LILITH SERVICES"
    $rawUrl = $script:LilithServicesUrl

    $ans = [System.Windows.Forms.MessageBox]::Show(
        "Se ejecutará Lilith Services desde:`n`n$rawUrl`n`nSe abrirá una nueva ventana de PowerShell con Bypass de política y se ejecutará el script.`n`n¿Continuar?",
        $title, 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }

    try {
        $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $psExe)) { $psExe = 'powershell.exe' }

        # NOTA: el operador '&&' NO existe en Windows PowerShell 5.1.
        # Se usa ';' que encadena los comandos con la misma semántica.
        $command = "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; Invoke-Expression (Invoke-RestMethod '$rawUrl')"

        $proc = Start-Process -FilePath $psExe `
            -ArgumentList @(
                '-NoLogo',
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-NoExit',
                '-Command', $command
            ) `
            -WindowStyle Normal `
            -PassThru `
            -ErrorAction Stop

        Set-Status ("Lilith Services iniciado  ·  PID {0}" -f $proc.Id)
    }
    catch {
        Set-Status "No se pudo iniciar Lilith Services."
        Show-Info "No se pudo abrir PowerShell para ejecutar Lilith Services.`n`nURL:`n$rawUrl`n`nError:`n$($_.Exception.Message)" $title
    }
}

# ------------------------------------------------------------
# OPCIÓN 08: HUB DE HERRAMIENTAS EXTERNAS (descarga y ejecuta con un clic)
# ------------------------------------------------------------
function Set-FlatButtonStyle {
    param($Btn, $Back, $Fore, $Border)
    $Btn.FlatStyle = 'Flat'
    $Btn.FlatAppearance.BorderSize = 1
    $Btn.FlatAppearance.BorderColor = $Border
    $Btn.FlatAppearance.MouseOverBackColor = $script:C.Hover
    $Btn.FlatAppearance.MouseDownBackColor = $script:C.Select
    $Btn.BackColor = $Back
    $Btn.ForeColor = $Fore
    $Btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Btn.UseVisualStyleBackColor = $false
}

function Get-ExternalTool {
    param([string]$Name, [string]$Url)

    $exe = $null
    Start-ScanSession "Descargando $Name..."
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
        $oldPref = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'

        $dir = Join-Path $env:TEMP ("Sombrio_Tools\" + ($Name -replace '\W', ''))
        [void](New-Item -ItemType Directory -Path $dir -Force)
        $tmp = Join-Path $dir "descarga.tmp"
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }

        Set-Progress 15
        try {
            Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -UserAgent "Wget/1.21" -TimeoutSec 180 -ErrorAction Stop
        } catch {
            Set-Status "No se pudo descargar $Name."
            Show-Info "No se pudo descargar $Name.`n`n$($_.Exception.Message)" $Name
            return
        } finally { $ProgressPreference = $oldPref }

        Set-Progress 60
        # Detectar el tipo real por los primeros bytes (MZ = exe, PK = zip)
        $magic = [byte[]]::new(2)
        $fs = [System.IO.File]::OpenRead($tmp)
        try { [void]$fs.Read($magic, 0, 2) } finally { $fs.Dispose() }

        if ($magic[0] -eq 0x4D -and $magic[1] -eq 0x5A) {
            $exe = Join-Path $dir (($Name -replace '\W', '') + ".exe")
            Move-Item -LiteralPath $tmp -Destination $exe -Force
        }
        elseif ($magic[0] -eq 0x50 -and $magic[1] -eq 0x4B) {
            Set-Status "Extrayendo $Name..."
            $zip = Join-Path $dir "tool.zip"
            Move-Item -LiteralPath $tmp -Destination $zip -Force
            $x = Join-Path $dir "extraido"
            Expand-Archive -Path $zip -DestinationPath $x -Force
            $cands = @(Get-ChildItem -Path $x -Recurse -Filter "*.exe" -File)
            $exe = ($cands | Where-Object { $_.FullName -match 'amd64|x64' -and $_.Name -match 'SystemInformer' } | Select-Object -First 1).FullName
            if (-not $exe) { $exe = ($cands | Select-Object -First 1).FullName }
        }

        if (-not $exe) {
            Set-Status "El archivo descargado de $Name no es ejecutable."
            Show-Info "Lo descargado no parece un .exe ni un .zip válido.`nSe abrirá la página en el navegador como alternativa." $Name
            Start-Process $Url
            return
        }
        Set-Progress 100
    } finally {
        Stop-ScanSession
    }

    if ($exe) {
        try {
            Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
            Set-Status ("{0} descargado y ejecutado  ·  {1}" -f $Name, $exe)
        } catch {
            Set-Status "No se pudo ejecutar $Name."
            Show-Info "Se descargó en:`n$exe`n`npero no se pudo ejecutar:`n$($_.Exception.Message)" $Name
        }
    }
}

function Start-Hubs {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "HERRAMIENTAS EXTERNAS"
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $dlg.ClientSize = New-Object System.Drawing.Size(380, 210)
    $dlg.BackColor = $script:C.Bg
    $dlg.ForeColor = $script:C.Text
    $dlg.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Selecciona una herramienta (se descarga y ejecuta):"
    $lbl.Location = New-Object System.Drawing.Point(24, 18)
    $lbl.AutoSize = $true
    $lbl.ForeColor = $script:C.Accent
    $dlg.Controls.Add($lbl)

    $b1 = New-Object System.Windows.Forms.Button
    $b1.Text = "System Informer  (descargar y ejecutar)"
    $b1.SetBounds(24, 55, 332, 40)
    Set-FlatButtonStyle $b1 $script:C.Panel2 $script:C.Text $script:C.Border
    $b1.Add_Click({ param($s, $e) $s.FindForm().Tag = 'si'; $s.FindForm().Close() })
    $dlg.Controls.Add($b1)

    $b2 = New-Object System.Windows.Forms.Button
    $b2.Text = "JournalTrace  (descargar y ejecutar)"
    $b2.SetBounds(24, 105, 332, 40)
    Set-FlatButtonStyle $b2 $script:C.Panel2 $script:C.Text $script:C.Border
    $b2.Add_Click({ param($s, $e) $s.FindForm().Tag = 'jt'; $s.FindForm().Close() })
    $dlg.Controls.Add($b2)

    $b3 = New-Object System.Windows.Forms.Button
    $b3.Text = "Cerrar"
    $b3.SetBounds(24, 158, 332, 34)
    Set-FlatButtonStyle $b3 $script:C.Bg $script:C.Muted $script:C.Border
    $b3.DialogResult = 'Cancel'
    $dlg.Controls.Add($b3)
    $dlg.CancelButton = $b3

    [void]$dlg.ShowDialog($script:Form)
    $choice = [string]$dlg.Tag
    $dlg.Dispose()

    switch ($choice) {
        'si' { Get-ExternalTool -Name "System Informer" -Url $script:SystemInformerUrl }
        'jt' { Get-ExternalTool -Name "JournalTrace"    -Url $script:JournalTraceUrl }
    }
}

# ------------------------------------------------------------
# OPCIÓN 09: REGISTRO DE ANÁLISIS (MEMORIA ACUMULADA DE SESIÓN)
# ------------------------------------------------------------
function Start-ShowRegistry {
    $mal = [System.Collections.Generic.List[string]]::new()
    foreach ($l in @($script:LogMods, $script:LogPrefetch, $script:LogMemoria, $script:LogServicios, $script:LogDisco)) {
        foreach ($it in $l) { if ((Get-ItemColor $it) -eq 'Red' -and -not $mal.Contains($it)) { $mal.Add($it) } }
    }
    foreach ($it in $script:LogMacros) { if (-not $mal.Contains($it)) { $mal.Add($it) } }

    $stats = @(
        "====== REGISTRO ACUMULADO DE LA SESIÓN ======",
        "Mods registrados | Total: $($script:LogMods.Count)",
        "Prefetch registrado | Total: $($script:LogPrefetch.Count)",
        "Memoria y procesos | Total: $($script:LogMemoria.Count)",
        "Macros y autoclickers | Total: $($script:LogMacros.Count)",
        "Servicios Windows | Total: $($script:LogServicios.Count)",
        "Disco profundo | Total: $($script:LogDisco.Count)",
        "Papelera | Total: $($script:LogPapelera.Count)",
        "====== RESULTADO DE AMENAZAS ======",
        "Hallazgos maliciosos en el registro (ROJOS) | Total: $($mal.Count)"
    )

    $script:RegData = @{
        Stats      = $stats
        Memoria    = @($script:LogMemoria)
        Prefetch   = @($script:LogPrefetch)
        Maliciosos = @($mal)
        Mods       = @($script:LogMods)
        Macros     = @($script:LogMacros)
        Servicios  = @($script:LogServicios)
        Disco      = @($script:LogDisco)
        Papelera   = @($script:LogPapelera)
    }
    $script:ViewMode  = 'registry'
    $script:ActiveCat = 'Stats'
    Show-Results
    Set-Status "Mostrando el registro acumulado de la sesión (cuadros independientes por categoría)."
}

# ============================================================
# ACCIONES DEL MENÚ
# ============================================================
function Invoke-Action([string]$Tag) {
    if ($script:Busy -and $Tag -notin @('panic', 'exit')) { return }
    try {
        switch ($Tag) {
            'global'   { Start-GlobalScan }
            'mods'     { Start-UnifiedModScan }
            'doomsday' { Start-Doomsday }
            'prefetch' { Start-TraceScan }
            'papelera' { Start-RecycleBinScan }
            'macros'   { Start-MacroAutoclickScan }
            'services' { Start-ServicesAudit }
            'hubs'     { Start-Hubs }
            'registry' { Start-ShowRegistry }
            'lilith'   { Start-LilithServices }
            'exit'     { $script:Form.Close() }
            'panic'    { [Environment]::Exit(0) }
        }
    } catch {
        Set-Status ("Error: " + $_.Exception.Message)
    }
}

# ============================================================
# CONSTRUCCIÓN DE LA VENTANA
# ============================================================
function New-MainForm {
    $C = $script:C
    $zeroPad = [System.Windows.Forms.Padding]::Empty

    $script:FontBold = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)

    # ---------- Formulario ----------
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "EL SOMBRIO IF - FORENSIC SCANNER V76 [EDICIÓN PRO]"
    $f.StartPosition = 'CenterScreen'
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $f.Size = New-Object System.Drawing.Size([math]::Min(1360, $wa.Width - 40), [math]::Min(860, $wa.Height - 40))
    $f.MinimumSize = New-Object System.Drawing.Size([math]::Min(1100, $f.Width), [math]::Min(700, $f.Height))
    $f.BackColor = $C.Bg
    $f.ForeColor = $C.Text
    $f.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $f.AutoScaleMode = 'Dpi'
    $script:Form = $f

    # ---------- Estructura principal ----------
    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = 'Fill'; $root.ColumnCount = 1; $root.RowCount = 3
    $root.Margin = $zeroPad; $root.Padding = $zeroPad; $root.BackColor = $C.Bg
    [void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 128)))
    [void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
    [void]$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 104)))
    $f.Controls.Add($root)

    # ---------- Cabecera ----------
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Fill'; $header.BackColor = $C.Panel; $header.Margin = $zeroPad

    $banner = New-Object System.Windows.Forms.Label
    $banner.AutoSize = $true
    $banner.Location = New-Object System.Drawing.Point(24, 8)
    $banner.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $banner.ForeColor = $C.Red
    $banner.Text = $script:BannerText.TrimEnd()
    $header.Controls.Add($banner)

    $sub = New-Object System.Windows.Forms.Label
    $sub.AutoSize = $true
    $sub.Location = New-Object System.Drawing.Point(26, 102)
    $sub.Font = New-Object System.Drawing.Font("Consolas", 9)
    $sub.ForeColor = $C.Accent
    $sub.Text = "[ ENTERPRISE FORENSIC FRAMEWORK V76 - SECURE RUNTIME ]"
    $header.Controls.Add($sub)

    $adm = New-Object System.Windows.Forms.Label
    $adm.Dock = 'Right'; $adm.Width = 470
    $adm.TextAlign = 'MiddleRight'
    $adm.Padding = New-Object System.Windows.Forms.Padding(0, 0, 24, 0)
    $adm.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    if (Test-Administrator) {
        $adm.ForeColor = $C.Green
        $adm.Text = "ESTADO: PRIVILEGIOS DE ADMINISTRADOR ACTIVOS`nFORENSIC SCANNER V76  ·  EDICIÓN PRO"
    } else {
        $adm.ForeColor = $C.Yellow
        $adm.Text = "AVISO: EJECUTE COMO ADMINISTRADOR PARA MÁXIMA EFECTIVIDAD`nFORENSIC SCANNER V76  ·  EDICIÓN PRO"
    }
    $header.Controls.Add($adm)

    $line = New-Object System.Windows.Forms.Panel
    $line.Dock = 'Bottom'; $line.Height = 2; $line.BackColor = $C.Green
    $header.Controls.Add($line)
    $root.Controls.Add($header, 0, 0)

    # ---------- Cuerpo: menú lateral + contenido ----------
    $body = New-Object System.Windows.Forms.TableLayoutPanel
    $body.Dock = 'Fill'; $body.ColumnCount = 2; $body.RowCount = 1
    $body.Margin = $zeroPad; $body.Padding = $zeroPad; $body.BackColor = $C.Bg
    [void]$body.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 300)))
    [void]$body.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$body.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
    $root.Controls.Add($body, 0, 1)

    # ----- Menú lateral (con franja magenta a la izquierda) -----
    $sideWrap = New-Object System.Windows.Forms.Panel
    $sideWrap.Dock = 'Fill'; $sideWrap.BackColor = $C.Panel; $sideWrap.Margin = $zeroPad

    $side = New-Object System.Windows.Forms.FlowLayoutPanel
    $side.Dock = 'Fill'; $side.FlowDirection = 'TopDown'; $side.WrapContents = $false
    $side.AutoScroll = $true; $side.BackColor = $C.Panel; $side.Margin = $zeroPad
    $side.Padding = New-Object System.Windows.Forms.Padding(12, 14, 8, 8)

    $sideStrip = New-Object System.Windows.Forms.Panel
    $sideStrip.Dock = 'Left'; $sideStrip.Width = 3; $sideStrip.BackColor = $C.Pink

    $sideTitle = New-Object System.Windows.Forms.Label
    $sideTitle.Text = "MÓDULOS OPERATIVOS"
    $sideTitle.AutoSize = $false; $sideTitle.Size = New-Object System.Drawing.Size(268, 26)
    $sideTitle.ForeColor = $C.Muted
    $sideTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $side.Controls.Add($sideTitle)

    $navDefs = @(
        @('01', 'Escaneo Global Optimizado',      'global'),
        @('02', 'Auditoría de Mods e Instancias', 'mods'),
        @('03', 'Doomsday Detector',               'doomsday'),
        @('07', 'Papelera de Reciclaje',          'papelera'),
        @('04', 'Análisis de Prefetch (solo)',    'prefetch'),
        @('05', 'Búsqueda de Macros & Autoclick', 'macros'),
        @('06', 'Auditoría de Servicios Windows', 'services'),
        @('08', 'Hub de Herramientas Externas',   'hubs'),
        @('09', 'Registro de Análisis (Memoria)', 'registry'),
        @('11', 'Lilith Services (lilith-ps)',    'lilith'),
        @('10', 'Salir del Framework',            'exit'),
        @('00', 'EXIT SILENCIOSO (PANIC BUTTON)', 'panic')
    )
    foreach ($d in $navDefs) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = ("  [ {0} ]   {1}" -f $d[0], $d[1])
        $b.Tag = $d[2]
        $b.Size = New-Object System.Drawing.Size(268, 42)
        $b.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 3)
        $b.TextAlign = 'MiddleLeft'
        $b.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
        if ($d[2] -eq 'panic') { Set-FlatButtonStyle $b $C.Bg $C.Red $C.RedDark }
        elseif ($d[2] -eq 'lilith') { Set-FlatButtonStyle $b $C.Panel2 $C.Green $C.Border }
        else                   { Set-FlatButtonStyle $b $C.Panel2 $C.Text $C.Border }
        $b.Add_Click({ param($s, $e) Invoke-Action ([string]$s.Tag) })
        $side.Controls.Add($b)
        $script:NavButtons.Add($b)
    }
    # El último control agregado se acopla primero: la franja queda en el borde izquierdo exterior
    $sideWrap.Controls.Add($side)
    $sideWrap.Controls.Add($sideStrip)
    $body.Controls.Add($sideWrap, 0, 0)

    # ----- Contenido -----
    $content = New-Object System.Windows.Forms.TableLayoutPanel
    $content.Dock = 'Fill'; $content.ColumnCount = 1; $content.RowCount = 3
    $content.Margin = $zeroPad; $content.BackColor = $C.Bg
    $content.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 8)
    [void]$content.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$content.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 32)))
    [void]$content.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
    [void]$content.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))

    $script:LblView = New-Object System.Windows.Forms.Label
    $script:LblView.Dock = 'Fill'; $script:LblView.TextAlign = 'MiddleLeft'
    $script:LblView.ForeColor = $C.Accent
    $script:LblView.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
    $script:LblView.Text = "CONSOLA CENTRAL DE OPERACIONES FORENSES"
    $content.Controls.Add($script:LblView, 0, 0)

    # Chips de categorías
    $chips = New-Object System.Windows.Forms.FlowLayoutPanel
    $chips.Dock = 'Fill'; $chips.AutoSize = $true; $chips.AutoSizeMode = 'GrowAndShrink'
    $chips.WrapContents = $true; $chips.Margin = $zeroPad; $chips.Visible = $false
    $chips.BackColor = $C.Bg
    foreach ($def in $script:CatDefs) {
        $cb = New-Object System.Windows.Forms.Button
        $cb.Text = $def.Text
        $cb.Tag = $def.Key
        $cb.AutoSize = $true; $cb.AutoSizeMode = 'GrowAndShrink'
        $cb.Padding = New-Object System.Windows.Forms.Padding(8, 2, 8, 2)
        $cb.Margin = New-Object System.Windows.Forms.Padding(0, 2, 8, 8)
        $cb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
        Set-FlatButtonStyle $cb $C.Panel2 $C.Text $C.Border
        $cb.Add_Click({ param($s, $e) Show-Category ([string]$s.Tag) })
        $chips.Controls.Add($cb)
        $script:CatButtons[$def.Key] = $cb
    }
    $script:Chips = $chips
    $content.Controls.Add($chips, 0, 1)

    # Panel que aloja la tabla y el arte de inicio
    $hostPanel = New-Object System.Windows.Forms.Panel
    $hostPanel.Dock = 'Fill'; $hostPanel.BackColor = $C.Panel; $hostPanel.Margin = $zeroPad
    $hostPanel.AutoScroll = $true
    $script:HostPanel = $hostPanel

    # Tabla de resultados
    $g = New-Object System.Windows.Forms.DataGridView
    $g.Dock = 'Fill'; $g.Visible = $false
    $g.ReadOnly = $true
    $g.AllowUserToAddRows = $false; $g.AllowUserToDeleteRows = $false; $g.AllowUserToResizeRows = $false
    $g.RowHeadersVisible = $false
    $g.BackgroundColor = $C.Panel; $g.GridColor = $C.Border; $g.BorderStyle = 'None'
    $g.CellBorderStyle = 'SingleHorizontal'
    $g.SelectionMode = 'FullRowSelect'
    $g.EnableHeadersVisualStyles = $false
    $g.ColumnHeadersBorderStyle = 'None'
    $g.ColumnHeadersHeightSizeMode = 'DisableResizing'
    $g.ColumnHeadersHeight = 36
    $g.ColumnHeadersDefaultCellStyle.BackColor = $C.Panel2
    $g.ColumnHeadersDefaultCellStyle.ForeColor = $C.Green
    $g.ColumnHeadersDefaultCellStyle.SelectionBackColor = $C.Panel2
    $g.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
    $g.ColumnHeadersDefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    $g.DefaultCellStyle.BackColor = $C.Panel
    $g.DefaultCellStyle.ForeColor = $C.Text
    $g.DefaultCellStyle.SelectionBackColor = $C.Select
    $g.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $g.DefaultCellStyle.Font = New-Object System.Drawing.Font("Consolas", 10)
    $g.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    $g.AlternatingRowsDefaultCellStyle.BackColor = $C.Row2
    $g.AlternatingRowsDefaultCellStyle.SelectionBackColor = $C.Select
    $g.RowTemplate.Height = 28
    $g.AutoSizeColumnsMode = 'Fill'
    [void]$g.Columns.Add("tipo", "TIPO")
    [void]$g.Columns.Add("elemento", "ELEMENTO")
    [void]$g.Columns.Add("detalle", "DETALLE")
    $g.Columns[0].FillWeight = 22
    $g.Columns[1].FillWeight = 36
    $g.Columns[2].FillWeight = 42
    try {
        $dbProp = [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic')
        $dbProp.SetValue($g, $true, $null)
    } catch { }
    $script:Grid = $g
    $g.Add_CellDoubleClick({
        param($s, $e)
        if ($e.RowIndex -ge 0) { Open-SelectedGridItem }
    })
    $hostPanel.Controls.Add($g)

    # Arte de inicio (la chica original, recoloreada a la paleta V76)
    $lines = @($script:sideGirl)
    $nonEmpty = $lines | Where-Object { $_.Trim().Length -gt 0 }
    $minIndent = ($nonEmpty | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
    $artFont = New-Object System.Drawing.Font("Consolas", 7)
    $rtb = New-Object System.Windows.Forms.RichTextBox
    $rtb.BorderStyle = 'None'
    $rtb.ScrollBars = 'None'; $rtb.WordWrap = $false; $rtb.Font = $artFont
    $rtb.Cursor = [System.Windows.Forms.Cursors]::Default
    $rtb.TabStop = $false
    $maxLen = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        $ln = $ln.Substring([math]::Min($minIndent, $ln.Length)).TrimEnd()
        if ($ln.Length -gt $maxLen) { $maxLen = $ln.Length }
        $col = if     ($i -le 11) { $C.Accent }
               elseif ($i -le 24) { $C.Green }
               elseif ($i -le 40) { $C.Blue }
               else               { $C.DBlue }
        $rtb.SelectionStart = $rtb.TextLength; $rtb.SelectionLength = 0
        $rtb.SelectionColor = $col
        $rtb.SelectedText = $ln + "`n"
    }
    $rtb.SelectionStart = $rtb.TextLength; $rtb.SelectionLength = 0
    $rtb.SelectionColor = $C.Green
    $rtb.SelectedText = "`n[OK] SISTEMA LISTO PARA OPERAR."
    $rtb.ReadOnly = $true
    $rtb.BackColor = $C.Panel
    $flags = [System.Windows.Forms.TextFormatFlags]::NoPadding
    $big = New-Object System.Drawing.Size(4000, 200)
    $mw = [System.Windows.Forms.TextRenderer]::MeasureText(("W" * [math]::Max(1, $maxLen)), $artFont, $big, $flags)
    $mh = [System.Windows.Forms.TextRenderer]::MeasureText("W", $artFont, $big, $flags)
    $rtb.Size = New-Object System.Drawing.Size(([int]($mw.Width + 40)), ([int]($mh.Height * ($lines.Count + 2) * 1.2 + 24)))
    $script:HomeArt = $rtb
    $hostPanel.Controls.Add($rtb)
    $hostPanel.Add_Resize({ Move-HomeArt })

    $content.Controls.Add($hostPanel, 0, 2)
    $body.Controls.Add($content, 1, 0)

    # ---------- Barra inferior: estado, progreso y monitor en vivo ----------
    $statusWrap = New-Object System.Windows.Forms.Panel
    $statusWrap.Dock = 'Fill'; $statusWrap.BackColor = $C.Panel; $statusWrap.Margin = $zeroPad

    $topStrip = New-Object System.Windows.Forms.Panel
    $topStrip.Dock = 'Top'; $topStrip.Height = 2; $topStrip.BackColor = $C.Green

    $st = New-Object System.Windows.Forms.TableLayoutPanel
    $st.Dock = 'Fill'; $st.ColumnCount = 2; $st.RowCount = 3
    $st.Margin = $zeroPad; $st.BackColor = $C.Panel
    $st.Padding = New-Object System.Windows.Forms.Padding(20, 8, 20, 8)
    [void]$st.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$st.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 300)))
    [void]$st.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 28)))
    [void]$st.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 22)))
    [void]$st.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 30)))

    $script:LblStatus = New-Object System.Windows.Forms.Label
    $script:LblStatus.Dock = 'Fill'; $script:LblStatus.TextAlign = 'MiddleLeft'
    $script:LblStatus.AutoEllipsis = $true
    $script:LblStatus.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    $script:LblStatus.ForeColor = $C.Text
    $script:LblStatus.Text = "Sistema listo. Selecciona un módulo del panel izquierdo."
    $st.Controls.Add($script:LblStatus, 0, 0)

    $script:LblPct = New-Object System.Windows.Forms.Label
    $script:LblPct.Dock = 'Fill'; $script:LblPct.TextAlign = 'MiddleRight'
    $script:LblPct.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
    $script:LblPct.ForeColor = $C.Green
    $script:LblPct.Text = "0%"
    $st.Controls.Add($script:LblPct, 1, 0)

    # V75 - Barra de progreso con borde de acento y relleno magenta
    $trackBack = New-Object System.Windows.Forms.Panel
    $trackBack.Dock = 'Fill'; $trackBack.BackColor = $C.Border
    $trackBack.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    $track = New-Object System.Windows.Forms.Panel
    $track.Dock = 'Fill'; $track.BackColor = $C.Panel2
    $track.Margin = New-Object System.Windows.Forms.Padding(1)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.Dock = 'Left'; $fill.Width = 0; $fill.BackColor = $C.Green
    $track.Controls.Add($fill)
    $trackBack.Controls.Add($track)
    $script:BarTrack = $trackBack; $script:BarFill = $fill
    $trackBack.Add_Resize({ Set-Progress $script:ProgressPct })
    $st.Controls.Add($trackBack, 0, 1)
    $st.SetColumnSpan($trackBack, 2)

    $script:LblDetail = New-Object System.Windows.Forms.Label
    $script:LblDetail.Dock = 'Fill'; $script:LblDetail.TextAlign = 'MiddleLeft'
    $script:LblDetail.AutoEllipsis = $true
    $script:LblDetail.Font = New-Object System.Drawing.Font("Consolas", 9)
    $script:LblDetail.ForeColor = $C.Muted
    $st.Controls.Add($script:LblDetail, 0, 2)

    $btnPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $btnPanel.Dock = 'Fill'; $btnPanel.FlowDirection = 'RightToLeft'; $btnPanel.WrapContents = $false
    $btnPanel.Margin = $zeroPad; $btnPanel.BackColor = $C.Panel

    $script:BtnCancel = New-Object System.Windows.Forms.Button
    $script:BtnCancel.Text = "CANCELAR ESCANEO"
    $script:BtnCancel.Size = New-Object System.Drawing.Size(170, 26)
    $script:BtnCancel.Margin = $zeroPad
    $script:BtnCancel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
    $script:BtnCancel.Visible = $false
    Set-FlatButtonStyle $script:BtnCancel $C.Bg $C.Red $C.RedDark
    $script:BtnCancel.Add_Click({ $script:CancelRequested = $true; Set-Status "Cancelando..." })
    $btnPanel.Controls.Add($script:BtnCancel)

    $script:BtnReport = New-Object System.Windows.Forms.Button
    $script:BtnReport.Text = "ABRIR REPORTE"
    $script:BtnReport.Size = New-Object System.Drawing.Size(170, 26)
    $script:BtnReport.Margin = $zeroPad
    $script:BtnReport.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
    $script:BtnReport.Visible = $false
    Set-FlatButtonStyle $script:BtnReport $C.Panel2 $C.Accent $C.Border
    $script:BtnReport.Add_Click({
        try { if ($script:LastReport) { Start-Process -FilePath $script:LastReport } } catch { Show-Info "No se pudo abrir el reporte." }
    })
    $btnPanel.Controls.Add($script:BtnReport)

    # Abrir el archivo/ruta de la fila seleccionada con confirmación.
    $script:BtnOpenSelected = New-Object System.Windows.Forms.Button
    $script:BtnOpenSelected.Text = "ABRIR SELECCIONADO"
    $script:BtnOpenSelected.Size = New-Object System.Drawing.Size(190, 26)
    $script:BtnOpenSelected.Margin = $zeroPad
    $script:BtnOpenSelected.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
    $script:BtnOpenSelected.Visible = $false
    Set-FlatButtonStyle $script:BtnOpenSelected $C.Panel2 $C.Green $C.Border
    $script:BtnOpenSelected.Add_Click({ Open-SelectedGridItem })
    $btnPanel.Controls.Add($script:BtnOpenSelected)

    $st.Controls.Add($btnPanel, 1, 2)

    # El último control agregado se acopla primero: la franja magenta queda arriba del todo
    $statusWrap.Controls.Add($st)
    $statusWrap.Controls.Add($topStrip)

    $root.Controls.Add($statusWrap, 0, 2)

    # ---------- Eventos de la ventana ----------
    $f.Add_FormClosing({
        param($s, $e)
        if ($script:Busy) {
            $e.Cancel = $true
            $script:CancelRequested = $true
            $script:CloseAfter = $true
            Set-Status "Cancelando escaneo y cerrando..."
        }
    })
    $f.Add_Shown({
        Show-Home
        Invoke-UiPump
        Initialize-Decompressor
    })
}

# ============================================================
# ARRANQUE
# ============================================================
try {
    New-MainForm
    [System.Windows.Forms.Application]::Run($script:Form)
} catch {
    [void][System.Windows.Forms.MessageBox]::Show(
        ("Error inesperado:`n`n" + $_.Exception.Message + "`n`n" + $_.ScriptStackTrace),
        "EL SOMBRIO IF", 'OK', 'Error')
} finally {
    if ($script:HiddenConsole -ne [IntPtr]::Zero) {
        try { [void][Sombrio.WinApi]::ShowWindow($script:HiddenConsole, 5) } catch { }
    }
}
