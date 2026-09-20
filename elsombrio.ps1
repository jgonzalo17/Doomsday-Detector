#Requires -Version 5.1

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V74) - EDICIÓN APP (GUI)
#   - Se abre como una aplicación de Windows (sin consola visible).
#   - Menú lateral con los mismos módulos 00-10.
#   - Resultados en tablas por categoría (Memoria, Prefetch, Maliciosos, ...).
#   - Barra de progreso real, monitor en vivo y botón Cancelar.
#   - Registro de sesión (opción 09) separado por categorías.
# ============================================================

$script:AutoElevate     = $true   # $true = pedir permisos de Administrador (UAC) al abrir
$script:JournalTraceUrl = ""      # Pon aquí el enlace de JournalTrace si quieres que el botón lo abra
$script:IsChild         = ($args -contains "--sombrio-child")

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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'Sombrio.Win').Type) {
    try {
        Add-Type -Namespace Sombrio -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
    } catch { }
}
try { [void][Sombrio.Win]::SetProcessDPIAware() } catch { }
[System.Windows.Forms.Application]::EnableVisualStyles()

# Si no se pudo relanzar (por ejemplo, ejecutado con irm | iex), se oculta la consola actual.
$script:HiddenConsole = [IntPtr]::Zero
if (-not $script:IsChild) {
    try {
        $hwnd = [Sombrio.Win]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) { [void][Sombrio.Win]::ShowWindow($hwnd, 0); $script:HiddenConsole = $hwnd }
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
$script:CatButtons      = @{}
$script:NavButtons      = [System.Collections.Generic.List[object]]::new()

# ------------------------------------------------------------
# MEMORIA DE SESIÓN INDEPENDIENTE (Para la Opción 09)
# ------------------------------------------------------------
$script:LogMods      = [System.Collections.Generic.List[string]]::new()
$script:LogPrefetch  = [System.Collections.Generic.List[string]]::new()
$script:LogMemoria   = [System.Collections.Generic.List[string]]::new()
$script:LogMacros    = [System.Collections.Generic.List[string]]::new()
$script:LogServicios = [System.Collections.Generic.List[string]]::new()
$script:LogDisco     = [System.Collections.Generic.List[string]]::new()

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
# PALETA DE COLORES
# ------------------------------------------------------------
$script:C = @{
    Bg      = [System.Drawing.Color]::FromArgb(9, 13, 24)
    Panel   = [System.Drawing.Color]::FromArgb(14, 21, 38)
    Panel2  = [System.Drawing.Color]::FromArgb(21, 32, 57)
    Row2    = [System.Drawing.Color]::FromArgb(17, 26, 46)
    Border  = [System.Drawing.Color]::FromArgb(34, 56, 100)
    Hover   = [System.Drawing.Color]::FromArgb(30, 50, 92)
    Select  = [System.Drawing.Color]::FromArgb(32, 64, 118)
    Accent  = [System.Drawing.Color]::FromArgb(0, 210, 255)
    Blue    = [System.Drawing.Color]::FromArgb(64, 122, 255)
    DBlue   = [System.Drawing.Color]::FromArgb(44, 84, 196)
    Text    = [System.Drawing.Color]::FromArgb(200, 224, 255)
    Muted   = [System.Drawing.Color]::FromArgb(112, 136, 176)
    Red     = [System.Drawing.Color]::FromArgb(255, 95, 95)
    RedDark = [System.Drawing.Color]::FromArgb(120, 34, 44)
    Green   = [System.Drawing.Color]::FromArgb(90, 225, 140)
    Yellow  = [System.Drawing.Color]::FromArgb(255, 214, 90)
    TealDim = [System.Drawing.Color]::FromArgb(90, 170, 190)
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

$script:MacroAutoclickCritical = @(
    "autoclicker", "auto-clicker", "auto_click", "autoclick", "clickbot", "click-bot",
    "gsautoclick", "gs auto clicker", "opautoclick", "op auto clicker",
    "jitbit", "murgee", "tinytask", "freeautoclicker", "free auto clicker",
    "automouseclick", "auto mouse click", "mouserecorder", "robomouse",
    "macrorecorder", "macro-recorder", "macro_recorder", "macro creator",
    "pulover", "pulovers macro",
    "autohotkey", "ahk_", "\.ahk", "autoit", "\.au3",
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

$script:WindowsServices = @("dps", "appinfo", "pcasvc", "eventlog", "sysmain", "dusmsvc", "bam")

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
        if (compressed[0] != 0x4D || compressed[1] != 0x41 || compressed[2] != 0x4D) return null;
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
    if ($Text -match 'TE VAS BAN|ILEGAL|MALICIOSO|AUTOCLICK|AUTOCICK|HACK\b|PELIGRO|CRITICO') { return "Red" }
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
    $script:LblDetail.Text = ""
    Set-Progress 0
    Set-Status $Text
}

function Stop-ScanSession {
    $script:Busy = $false
    foreach ($b in $script:NavButtons) { $b.Enabled = $true }
    $script:BtnCancel.Visible = $false
    if ($script:LastReport -and (Test-Path -LiteralPath $script:LastReport)) { $script:BtnReport.Visible = $true }
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
        $btn.FlatAppearance.BorderColor = if ($active) { $script:C.Accent } elseif ($hasRed) { $script:C.RedDark } else { $script:C.Border }
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
            if ($p.Header) {
                $row.DefaultCellStyle.ForeColor = $script:C.TealDim
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
    $script:Grid.Visible  = $false
    $script:Chips.Visible = $false
    $script:HomeArt.Visible  = $true
    $script:LblView.Text  = "CONSOLA CENTRAL DE OPERACIONES FORENSES"
    Move-HomeArt
}

function Show-Results {
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
    $path = Join-Path ([Environment]::GetFolderPath("Desktop")) "Reporte_Sombrio_V74.txt"
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("===============================================================")
    [void]$sb.AppendLine(" REPORTE FORENSE - EL SOMBRIO IF V74")
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
    param($Disco, $Maliciosos, [datetime]$StartTime, [int]$BasePct, [int]$SpanPct)

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
                if ($script:RxHacks.IsMatch($f.Name) -or $script:RxMacroCritical.IsMatch($f.Name)) {
                    $script:DeepHits++
                    $Disco.Add("[ARCHIVO ILEGAL - TE VAS BAN] $($f.Name) | Ruta: $full")
                    $Maliciosos.Add("[EN DISCO] $($f.Name) | Ruta: $full")
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
                Set-Phase 3 7 "3/7  Volcando Papelera de Reciclaje..."
                $shell    = New-Object -ComObject Shell.Application
                $papelera = $shell.NameSpace(10)
                if ($papelera) {
                    $cPap = $papelera.Items().Count
                    foreach ($item in $papelera.Items()) {
                        if ($script:RxHacks.IsMatch($item.Name)) {
                            $maliciosos.Add("[PAPELERA HACK - TE VAS BAN] $($item.Name) | Ruta: $($item.Path)")
                        }
                    }
                }
            } catch { }
        }

        # 4 - Mods
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 4 7 "4/7  Auditando .minecraft/mods..."
                if (Test-Path $script:DefaultModsPath) {
                    $localMods = @(Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip","*.dll" -ErrorAction SilentlyContinue)
                    $cMods = $localMods.Count
                    foreach ($mod in $localMods) {
                        if ($script:RxHacks.IsMatch($mod.Name) -or $mod.Length -lt 15KB) {
                            $mods.Add("[MOD ILEGAL - TE VAS BAN] $($mod.Name) | Ruta: $($mod.FullName)")
                            $maliciosos.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                        } else {
                            $mods.Add("[MOD APROBADO] $($mod.Name) | Ruta: OK")
                        }
                    }
                }
                Add-ToLog $script:LogMods $mods
            } catch { }
        }

        # 5 - Macros
        if (-not $script:CancelRequested) {
            try {
                Set-Phase 5 7 "5/7  Verificando Macros y Periféricos..."
                foreach ($kp in @(
                    @{ Path = "$env:USERPROFILE\AppData\Local\LGHUB\settings.db"; Name = "Logitech G HUB" },
                    @{ Path = "$env:APPDATA\AutoHotkey"; Name = "AutoHotkey" }
                )) {
                    if (Test-Path $kp.Path) {
                        $macros.Add("[SOFTWARE MACRO INSTALADO] $($kp.Name) | Ruta: $($kp.Path)")
                        $maliciosos.Add("[SOFTWARE MACRO] $($kp.Name) | Ruta: $($kp.Path)")
                    }
                }
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
                Invoke-DiskScan -Disco $disco -Maliciosos $maliciosos -StartTime $scanStart -BasePct 86 -SpanPct 14
                Add-ToLog $script:LogDisco $disco
            } catch { }
        }

        $statsBox.Add("====== ELEMENTOS PROCESADOS ======")
        $statsBox.Add("Procesos activos en Memoria RAM | Total: $cRam")
        $statsBox.Add("Archivos en Prefetch evaluados | Total: $cPref")
        $statsBox.Add("Archivos en Papelera de Reciclaje | Total: $cPap")
        $statsBox.Add("Mods locales analizados (.minecraft) | Total: $cMods")
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
                "MALICIOSOS"             = $maliciosos
                "MODS (.MINECRAFT)"      = $mods
                "MACROS / AUTOCLICKERS"  = $macros
                "SERVICIOS"              = $servicios
                "DISCO PROFUNDO"         = $disco
            })
        } catch { $script:LastReport = $null }

        $focus = if ($maliciosos.Count -gt 0) { 'Maliciosos' } else { 'Stats' }
        Publish-Results -Data @{
            Stats = $statsBox; Memoria = $memoria; Prefetch = $prefetchHoy; Maliciosos = $maliciosos
            Mods = $mods; Macros = $macros; Servicios = $servicios; Disco = $disco
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
    Start-ScanSession "Auditando mods..."
    try {
        $mods = [System.Collections.Generic.List[string]]::new()
        if (Test-Path $script:DefaultModsPath) {
            $files = @(Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip" -ErrorAction SilentlyContinue)
            $n = 0
            foreach ($mod in $files) {
                $n++
                if ($script:RxHacks.IsMatch($mod.Name)) {
                    $mods.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                } else {
                    $mods.Add("[MOD APROBADO] $($mod.Name) | Ruta: OK")
                }
                if (($n % 10) -eq 0) { Set-Progress ([math]::Round(($n / $files.Count) * 100)) }
            }
        }
        Add-ToLog $script:LogMods $mods
        Publish-Results -Data @{ Mods = $mods } -Focus 'Mods'
        Set-Progress 100
        Set-Status ("Auditoría de mods completada  ·  {0} archivos revisados" -f $mods.Count)
    } finally { Stop-ScanSession }
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

function Start-MacroAutoclickScan {
    Start-ScanSession "Buscando macros y autoclickers en memoria..."
    try {
        $macros = [System.Collections.Generic.List[string]]::new()
        foreach ($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
            $macros.Add("[PROCESO MALICIOSO] $($proc.Name).exe | PID: $($proc.Id)")
        }
        Add-ToLog $script:LogMacros $macros
        Publish-Results -Data @{ Macros = $macros } -Focus 'Macros'
        Set-Progress 100
        Set-Status ("Búsqueda de macros completada  ·  {0} hallazgos" -f $macros.Count)
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
# OPCIÓN 03: DOOMSDAY DETECTOR (se abre en una ventana de PowerShell aparte)
# ------------------------------------------------------------
function Start-SafeRemote {
    param([string]$Url, [string]$Title)
    $ans = [System.Windows.Forms.MessageBox]::Show(
        "Se descargará y ejecutará un script remoto en una ventana de PowerShell aparte:`n`n$Url`n`n¿Continuar?",
        $Title, 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }
    $cmd = "& ([ScriptBlock]::Create((Invoke-RestMethod -Uri '$Url' -UseBasicParsing -TimeoutSec 15)))"
    $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
    Start-Process -FilePath "powershell.exe" -WindowStyle Normal `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -EncodedCommand $enc"
    Set-Status "$Title abierto en una ventana aparte."
}

# ------------------------------------------------------------
# OPCIÓN 07: UTILIDADES Y MANTENIMIENTO
# ------------------------------------------------------------
function Start-SysMaintenance {
    $script:CatData = @{}
    $script:RegData = @{}
    $script:ViewMode = 'live'
    $script:ActiveCat = 'Stats'
    $script:LastReport = $null
    $script:BtnReport.Visible = $false
    Set-Progress 0
    $script:LblDetail.Text = ""
    Show-Home

    $ans = [System.Windows.Forms.MessageBox]::Show(
        "Vista limpiada.`n`n¿Borrar también el registro acumulado de la sesión (opción 09)?",
        "MANTENIMIENTO", 'YesNo', 'Question')
    if ($ans -eq 'Yes') {
        foreach ($l in @($script:LogMods, $script:LogPrefetch, $script:LogMemoria, $script:LogMacros, $script:LogServicios, $script:LogDisco)) { $l.Clear() }
        Set-Status "Vista y registro de sesión limpiados."
    } else {
        Set-Status "Vista limpiada. El registro de sesión se conserva."
    }
}

# ------------------------------------------------------------
# OPCIÓN 08: HUB DE HERRAMIENTAS EXTERNAS
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
    $lbl.Text = "Selecciona una herramienta:"
    $lbl.Location = New-Object System.Drawing.Point(24, 18)
    $lbl.AutoSize = $true
    $lbl.ForeColor = $script:C.Accent
    $dlg.Controls.Add($lbl)

    $b1 = New-Object System.Windows.Forms.Button
    $b1.Text = "System Informer"
    $b1.SetBounds(24, 55, 332, 40)
    Set-FlatButtonStyle $b1 $script:C.Panel2 $script:C.Text $script:C.Border
    $b1.Add_Click({ Start-Process "https://sourceforge.net/projects/systeminformer/" })
    $dlg.Controls.Add($b1)

    $b2 = New-Object System.Windows.Forms.Button
    $b2.Text = "JournalTrace"
    $b2.SetBounds(24, 105, 332, 40)
    Set-FlatButtonStyle $b2 $script:C.Panel2 $script:C.Text $script:C.Border
    $b2.Add_Click({
        if ($script:JournalTraceUrl) { Start-Process $script:JournalTraceUrl }
        else { Show-Info "No hay enlace configurado para JournalTrace.`nEdítalo en la variable `$script:JournalTraceUrl al inicio del script." "JournalTrace" }
    })
    $dlg.Controls.Add($b2)

    $b3 = New-Object System.Windows.Forms.Button
    $b3.Text = "Cerrar"
    $b3.SetBounds(24, 158, 332, 34)
    Set-FlatButtonStyle $b3 $script:C.Bg $script:C.Muted $script:C.Border
    $b3.DialogResult = 'Cancel'
    $dlg.Controls.Add($b3)
    $dlg.CancelButton = $b3

    [void]$dlg.ShowDialog($script:Form)
    $dlg.Dispose()
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
            'doomsday' { Start-SafeRemote -Url "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1" -Title "DOOMSDAY DETECTOR" }
            'prefetch' { Start-TraceScan }
            'macros'   { Start-MacroAutoclickScan }
            'services' { Start-ServicesAudit }
            'utils'    { Start-SysMaintenance }
            'hubs'     { Start-Hubs }
            'registry' { Start-ShowRegistry }
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
    $f.Text = "EL SOMBRIO IF - FORENSIC SCANNER V74 [EDICION PRO]"
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
    $banner.ForeColor = $C.Blue
    $banner.Text = $script:BannerText.TrimEnd()
    $header.Controls.Add($banner)

    $sub = New-Object System.Windows.Forms.Label
    $sub.AutoSize = $true
    $sub.Location = New-Object System.Drawing.Point(26, 102)
    $sub.Font = New-Object System.Drawing.Font("Consolas", 9)
    $sub.ForeColor = $C.Accent
    $sub.Text = "[ ENTERPRISE FORENSIC FRAMEWORK - SECURE RUNTIME ]"
    $header.Controls.Add($sub)

    $adm = New-Object System.Windows.Forms.Label
    $adm.Dock = 'Right'; $adm.Width = 470
    $adm.TextAlign = 'MiddleRight'
    $adm.Padding = New-Object System.Windows.Forms.Padding(0, 0, 24, 0)
    $adm.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    if (Test-Administrator) {
        $adm.ForeColor = $C.Green
        $adm.Text = "ESTADO: PRIVILEGIOS DE ADMINISTRADOR ACTIVOS`nFORENSIC SCANNER V74  ·  EDICIÓN PRO"
    } else {
        $adm.ForeColor = $C.Yellow
        $adm.Text = "AVISO: EJECUTE COMO ADMINISTRADOR PARA MÁXIMA EFECTIVIDAD`nFORENSIC SCANNER V74  ·  EDICIÓN PRO"
    }
    $header.Controls.Add($adm)

    $line = New-Object System.Windows.Forms.Panel
    $line.Dock = 'Bottom'; $line.Height = 2; $line.BackColor = $C.Accent
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

    # ----- Menú lateral -----
    $side = New-Object System.Windows.Forms.FlowLayoutPanel
    $side.Dock = 'Fill'; $side.FlowDirection = 'TopDown'; $side.WrapContents = $false
    $side.AutoScroll = $true; $side.BackColor = $C.Panel; $side.Margin = $zeroPad
    $side.Padding = New-Object System.Windows.Forms.Padding(12, 14, 8, 8)

    $sideTitle = New-Object System.Windows.Forms.Label
    $sideTitle.Text = "MÓDULOS OPERATIVOS"
    $sideTitle.AutoSize = $false; $sideTitle.Size = New-Object System.Drawing.Size(268, 26)
    $sideTitle.ForeColor = $C.Muted
    $sideTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $side.Controls.Add($sideTitle)

    $navDefs = @(
        @('01', 'Escaneo Global Optimizado',      'global'),
        @('02', 'Auditoría de Mods e Instancias', 'mods'),
        @('03', 'Doomsday Detector (Nube)',       'doomsday'),
        @('04', 'Análisis de Prefetch (solo)',    'prefetch'),
        @('05', 'Búsqueda de Macros & Autoclick', 'macros'),
        @('06', 'Auditoría de Servicios Windows', 'services'),
        @('07', 'Utilidades y Mantenimiento',     'utils'),
        @('08', 'Hub de Herramientas Externas',   'hubs'),
        @('09', 'Registro de Análisis (Memoria)', 'registry'),
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
        else                   { Set-FlatButtonStyle $b $C.Panel2 $C.Text $C.Border }
        $b.Add_Click({ param($s, $e) Invoke-Action ([string]$s.Tag) })
        $side.Controls.Add($b)
        $script:NavButtons.Add($b)
    }
    $body.Controls.Add($side, 0, 0)

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
    $g.ColumnHeadersDefaultCellStyle.ForeColor = $C.Accent
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
    $hostPanel.Controls.Add($g)

    # Arte de inicio (la chica original)
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
        $col = if ($i -ge 12 -and $i -le 24) { $C.DBlue } elseif ($i -gt 24 -and $i -le 48) { $C.Blue } else { $C.Accent }
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
    $script:LblPct.ForeColor = $C.Accent
    $script:LblPct.Text = "0%"
    $st.Controls.Add($script:LblPct, 1, 0)

    $track = New-Object System.Windows.Forms.Panel
    $track.Dock = 'Fill'; $track.BackColor = $C.Panel2
    $track.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.Dock = 'Left'; $fill.Width = 0; $fill.BackColor = $C.Accent
    $track.Controls.Add($fill)
    $script:BarTrack = $track; $script:BarFill = $fill
    $track.Add_Resize({ Set-Progress $script:ProgressPct })
    $st.Controls.Add($track, 0, 1)
    $st.SetColumnSpan($track, 2)

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
    $st.Controls.Add($btnPanel, 1, 2)

    $root.Controls.Add($st, 0, 2)

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
        try { [void][Sombrio.Win]::ShowWindow($script:HiddenConsole, 5) } catch { }
    }
}
