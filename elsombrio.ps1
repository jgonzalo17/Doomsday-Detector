#Requires -Version 5.1

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V75) - EDICIÓN APP (GUI)
#   V75 - Novedades:
#     [11] LILITH SERVICES (lilith-ps) integrado en el menú.
#     MODS separados por versión de Minecraft (detectada del nombre,
#          de la carpeta y del interior del .jar: fabric.mod.json,
#          mods.toml, mcmod.info, quilt.mod.json).
#     Detección de MACROS mejorada: procesos, software instalado
#          (registro), tareas programadas, servicios, archivos en
#          carpetas del usuario y carpeta de Inicio.
#     Interfaz renovada: paleta violeta/magenta (cyberpunk),
#          barra de progreso con borde y relleno magenta,
#          barras de acento laterales y nuevos colores de tabla.
# ============================================================

$script:AutoElevate     = $true   # $true = pedir permisos de Administrador (UAC) al abrir
$script:DoomsdayRepo     = "https://github.com/jgonzalo17/Doomsday-Detector.git"
$script:DoomsdayScript   = "elsombrio.ps1"   # nombre exacto del detector dentro del repo
$script:SystemInformerUrl = "https://sourceforge.net/projects/systeminformer/files/latest/download"
$script:JournalTraceUrl   = "https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe"
$script:LilithServicesUrl = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1"
# URL raw de ESTE script en tu GitHub (para poder abrirlo con un solo comando y pedir UAC).
# Cambia el nombre del archivo si lo subes con otro nombre.
$script:SelfUrl         = "https://raw.githubusercontent.com/jgonzalo17/Doomsday-Detector/main/Sombrio_V75_GUI.ps1"
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
# PALETA DE COLORES (V75 - CYBERPUNK VIOLETA / MAGENTA)
# ------------------------------------------------------------
$script:C = @{
    Bg      = [System.Drawing.Color]::FromArgb(12, 8, 20)
    Panel   = [System.Drawing.Color]::FromArgb(18, 12, 32)
    Panel2  = [System.Drawing.Color]::FromArgb(26, 17, 46)
    Row2    = [System.Drawing.Color]::FromArgb(21, 14, 38)
    Border  = [System.Drawing.Color]::FromArgb(66, 44, 118)
    Hover   = [System.Drawing.Color]::FromArgb(48, 30, 88)
    Select  = [System.Drawing.Color]::FromArgb(62, 38, 112)
    Accent  = [System.Drawing.Color]::FromArgb(197, 122, 255)
    Pink    = [System.Drawing.Color]::FromArgb(255, 79, 205)
    Blue    = [System.Drawing.Color]::FromArgb(102, 140, 255)
    DBlue   = [System.Drawing.Color]::FromArgb(72, 94, 210)
    Text    = [System.Drawing.Color]::FromArgb(228, 220, 248)
    Muted   = [System.Drawing.Color]::FromArgb(156, 136, 200)
    Red     = [System.Drawing.Color]::FromArgb(255, 96, 112)
    RedDark = [System.Drawing.Color]::FromArgb(128, 34, 52)
    Green   = [System.Drawing.Color]::FromArgb(100, 238, 164)
    Yellow  = [System.Drawing.Color]::FromArgb(255, 214, 110)
    TealDim = [System.Drawing.Color]::FromArgb(122, 202, 224)
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
    if ($Text -match 'ILEGAL|MALICIOSO|AUTOCLICK|AUTOCICK|HACK\b|PELIGRO|CRITICO|MACRO') { return "Red" }
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
        $btn.FlatAppearance.BorderColor = if ($active) { $script:C.Pink } elseif ($hasRed) { $script:C.RedDark } else { $script:C.Border }
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
                $row.DefaultCellStyle.ForeColor = if ($p.Name -match 'MINECRAFT') { $script:C.Pink } else { $script:C.TealDim }
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
    $path = Join-Path ([Environment]::GetFolderPath("Desktop")) "Reporte_Sombrio_V75.txt"
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("===============================================================")
    [void]$sb.AppendLine(" REPORTE FORENSE - EL SOMBRIO IF V75")
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
                # .jar de cualquier carpeta del disco = posible mod (la carpeta .minecraft\mods se audita aparte)
                $isJar = ($null -ne $Mods -and $f.Extension -eq '.jar' -and -not $full.StartsWith($script:DefaultModsPath, [StringComparison]::OrdinalIgnoreCase))
                if ($isJar) { $script:DiskModCount++ }
                $hit  = ($script:RxHacks.IsMatch($f.Name) -or $script:RxMacroCritical.IsMatch($f.Name))
                $tiny = ($isJar -and $f.Length -lt 15KB -and $full -match 'mods|minecraft')
                if ($hit -or $tiny) {
                    $script:DeepHits++
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
                        if ($script:RxHacks.IsMatch($mod.Name) -or $mod.Length -lt 15KB) {
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
                Set-Phase 7 7 "7/7  Escaneo prof... (Tiempo restante: 47 KB)
