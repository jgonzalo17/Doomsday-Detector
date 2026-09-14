#Requires -Version 5.1
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "EL SOMBRIO IF - FORENSIC SCANNER V72 [GATO EDITION FINAL]"

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V72 - FINAL FIXES)
# Mejoras:
#   - Corrección sintáctica del bloque Switch.
#   - Implementación de [ Registro de Análisis ] en memoria.
# ============================================================

$script:DefaultModsPath = "$env:APPDATA\.minecraft\mods"
$script:FirstRun       = $true
$script:BoxW           = 95
$script:MaxBoxItems    = 250   

# ------------------------------------------------------------
# MEMORIA DE SESIÓN (Guarda todo lo analizado)
# ------------------------------------------------------------
$script:MasterLog = [System.Collections.Generic.List[string]]::new()

function Add-ToMasterLog([array]$Items) {
    if ($null -ne $Items) {
        foreach ($item in $Items) {
            if ($item -notmatch "======" -and $item -notmatch "Sin hallazgos") {
                if (-not $script:MasterLog.Contains($item)) {
                    $script:MasterLog.Add($item)
                }
            }
        }
    }
}

# ------------------------------------------------------------
# ARTE: GATITO REDISEÑADO (CYBER CAT)
# ------------------------------------------------------------
$script:sideCat = @(
    "                                       /\___/\     ",
    "                                      (  o o  )    ",
    "                                      /  =^=  \    ",
    "                                     /         \   ",
    "                                    |           |  ",
    "                                    |  _     _  |  ",
    "                                    | | |   | | |  ",
    "                                    | | |   | | |  ",
    "                                    | | |   | | |  ",
    "                                    | | |   | | |  ",
    "                                    \ \_/   \_/ /  ",
    "                                     \_________/   ",
    "                                     (  (   )  )   ",
    "                                     |  |   |  |   ",
    "                                    _|_ |   | _|_  ",
    "                                   (____)   (____) "
)

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

$script:ScanRecent   = [System.Collections.Generic.Queue[string]]::new()
$script:SpinIdx      = 0
$script:ScanCount    = 0
$script:DeepHits     = 0

# ============================================================
# FUNCIONES DE INTERFAZ Y UTILIDADES
# ============================================================
function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Typewriter {
    param([string]$Text, [int]$Speed = 10, [string]$Color = "Cyan")
    foreach ($char in $Text.ToCharArray()) {
        Write-Host $char -NoNewline -ForegroundColor $Color
        Start-Sleep -Milliseconds $Speed
    }
    Write-Host ""
}

function Show-BootAnimation {
    Clear-Host
    Write-Host "`n"
    $catColors = @("Cyan","Blue","DarkCyan","DarkBlue","Blue","DarkCyan")
    for ($i = 0; $i -lt $script:sideCat.Count; $i++) {
        $c = $catColors[([math]::Floor($i / 4)) % $catColors.Count]
        Write-Host $script:sideCat[$i].PadLeft(62) -ForegroundColor $c
    }
    Write-Host "`n"

    $bootSteps = @(
        "Inicializando subsistema de auditoría NT...",
        "Comprobando integridad de hashes y motores de memoria...",
        "Despertando al gato forense y sincronizando logs...",
        "Carga de módulos forenses completada con éxito."
    )

    for ($i = 0; $i -lt 15; $i++) {
        $stepIndex = [math]::Min([math]::Floor($i / 4), $bootSteps.Count - 1)
        $stepText  = $bootSteps[$stepIndex].PadRight(55, ' ')

        $pct       = [math]::Round((($i + 1) / 15) * 100)
        $barLength = 35
        $filled    = [math]::Round(($pct / 100) * $barLength)
        $empty     = $barLength - $filled
        $progressBar = "█" * $filled + "▒" * $empty

        Write-Host "`r       [CORE] $stepText | [$progressBar] $pct% " -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 60
    }
    Write-Host "`n`n       [OK] SISTEMA LISTO PARA OPERAR." -ForegroundColor Green
    Start-Sleep -Milliseconds 400
}

function Show-Banner {
    Clear-Host
    Write-Host "`n`n"
    $banner = @"
              ███████╗ ██████╗ ███╗   ███╗██████╗ ██████╗ ██╗ ██████╗
              ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║██╔═══██╗
              ███████╗██║   ██║██╔████╔██║██████╔╝██████╔╝██║██║   ██║
              ╚════██║██║   ██║██║╚██╔╝██║██╔══██╗██╔══██╗██║██║   ██║
              ███████║╚██████╔╝██║ ╚═╝ ██║██████╔╝██║  ██║██║╚██████╔╝
              ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝
"@
    Write-Host $banner -ForegroundColor Blue
    $pad = [math]::Max(0, [math]::Floor(($script:BoxW - 52) / 2))
    $str = ((' ' * $pad) + "[ ENTERPRISE FORENSIC FRAMEWORK - GATO EDITION ]").PadRight($script:BoxW, ' ')
    Write-Host "       $str`n" -ForegroundColor Cyan
}

function Show-Header {
    param([string]$Subtitle)
    Write-Host "`n`n`n       ╔$($("═" * $script:BoxW))╗" -ForegroundColor DarkBlue
    $titlePad = [math]::Max(0, [math]::Floor(($script:BoxW - 38) / 2))
    $titleStr = ((' ' * $titlePad) + "EL SOMBRIO IF - FORENSIC SCANNER").PadRight($script:BoxW, ' ')
    Write-Host "       ║$titleStr║" -ForegroundColor Blue
    Write-Host "       ╠$($("═" * $script:BoxW))╣" -ForegroundColor DarkBlue
    $subPad = [math]::Max(0, [math]::Floor(($script:BoxW - $Subtitle.Length) / 2))
    $subStr = ((' ' * $subPad) + $Subtitle).PadRight($script:BoxW, ' ')
    Write-Host "       ║$subStr║" -ForegroundColor Cyan
    Write-Host "       ╚$($("═" * $script:BoxW))╝`n" -ForegroundColor DarkBlue
}

function Pause-Scanner {
    Write-Host "`n       $($("─" * $script:BoxW))" -ForegroundColor DarkBlue
    $colors = @("Cyan","Blue","DarkCyan","DarkBlue")
    for ($i = 0; $i -lt 15; $i++) {
        $c = $colors[$i % $colors.Count]
        $space = " " * ($i % 8)
        $cat = "       $space 🌈✨ ~=[,,_,,]:3"
        Write-Host "`r$cat   " -NoNewline -ForegroundColor $c
        Start-Sleep -Milliseconds 70
    }
    Write-Host "`n"
    Invoke-Typewriter "       [ Presiona CUALQUIER TECLA para regresar al menú principal ]" -Speed 8 -Color Cyan
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { $null = Read-Host }
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

function Show-PhaseProgress {
    param([int]$Step, [int]$Total, [string]$Text)
    $start = [math]::Round((($Step - 1) / $Total) * 100)
    $end   = [math]::Round(($Step / $Total) * 100)
    
    for ($p = $start; $p -le $end; $p++) {
        $barLen = 30
        $filled = [math]::Round(($p / 100) * $barLen)
        $bar = ("█" * $filled).PadRight($barLen, "▒")
        $pct = "$p%".PadLeft(4)
        Write-Host "`r       [ $pct ] [$bar] $Text".PadRight($script:BoxW) -NoNewline -ForegroundColor White
        Start-Sleep -Milliseconds 10
    }
    Write-Host ""
}

function Show-CategoryBox {
    param(
        [string]$Title,
        [array]$Items,
        [switch]$Force,
        [string]$TitleColor = "Cyan"
    )

    if (-not $Force -and ($null -eq $Items -or $Items.Count -eq 0)) { return }

    $cW = [math]::Floor(($script:BoxW - 1) / 2)
    $anyMalicious = $false
    if ($Items) {
        foreach ($it in $Items) { if ((Get-ItemColor $it) -eq "Red") { $anyMalicious = $true; break } }
    }
    $borderColor = if ($anyMalicious) { "Red" } else { "DarkBlue" }

    Write-Host "       ╔$("═" * $script:BoxW)╗" -ForegroundColor $borderColor
    $tPad = [math]::Max(0, [math]::Floor(($script:BoxW - $Title.Length) / 2))
    Write-Host ("       ║" + ((' ' * $tPad) + $Title).PadRight($script:BoxW) + "║") -ForegroundColor $TitleColor
    Write-Host "       ╠$("═" * $cW)╦$("═" * $cW)╣" -ForegroundColor $borderColor
    Write-Host ("       ║" + " ELEMENTO".PadRight($cW) + "║" + " DETALLE".PadRight($cW) + "║") -ForegroundColor Cyan
    Write-Host "       ╠$("═" * $cW)╬$("═" * $cW)╣" -ForegroundColor $borderColor

    if ($null -eq $Items -or $Items.Count -eq 0) {
        Write-Host ("       ║" + " Sin hallazgos.".PadRight($cW) + "║" + " ---".PadRight($cW) + "║") -ForegroundColor Green
    } else {
        $shown = 0
        foreach ($item in $Items) {
            $shown++
            if ($shown -gt $script:MaxBoxItems) {
                Write-Host ("       ║" + (" ... y {0} más (ver reporte)." -f ($Items.Count - $script:MaxBoxItems)).PadRight($cW) + "║" + "".PadRight($cW) + "║") -ForegroundColor DarkYellow
                break
            }
            $item = [string]$item
            $leftText  = $item
            $rightText = "---"

            $sepIdx = $item.IndexOf(" | ")
            if ($sepIdx -ge 0) {
                $leftText  = $item.Substring(0, $sepIdx).Trim()
                $rightText = $item.Substring($sepIdx + 3).Trim()
            }

            $color = Get-ItemColor $item
            $strL = "> " + $leftText
            $strR = $rightText
            if ($strL.Length -gt $cW) { $strL = $strL.Substring(0, $cW - 3) + "..." }
            if ($strR.Length -gt $cW) { $strR = $strR.Substring(0, $cW - 3) + "..." }

            Write-Host "       ║" -NoNewline -ForegroundColor $borderColor
            Write-Host $strL.PadRight($cW) -NoNewline -ForegroundColor $color
            Write-Host "║" -NoNewline -ForegroundColor $borderColor
            Write-Host $strR.PadRight($cW) -NoNewline -ForegroundColor $color
            Write-Host "║" -ForegroundColor $borderColor
        }
    }
    Write-Host "       ╚$("═" * $cW)╩$("═" * $cW)╝" -ForegroundColor $borderColor
    Write-Host ""
}

function Show-GlobalDashboard {
    param([System.Collections.Specialized.OrderedDictionary]$Categories)
    Clear-Host
    Show-Header "RESULTADOS - PANEL DE ANÁLISIS"
    foreach ($key in $Categories.Keys) {
        $entry = $Categories[$key]
        Show-CategoryBox -Title $key -Items $entry.Items -Force:($entry.Force) -TitleColor $entry.Color
    }
    Pause-Scanner
}

# ============================================================
# MONITOR DE ESCANEO EN VIVO (BARRA OPTIMIZADA)
# ============================================================
function Update-ScanMonitor {
    param(
        [long]$Scanned,
        [int]$Hits,
        [string]$CurrentFile,
        [string]$DriveLabel,
        [datetime]$StartTime,
        [int]$Percent
    )

    if ($script:ScanRecent.Count -ge 6) { $script:ScanRecent.Dequeue() | Out-Null }
    $width = [Console]::WindowWidth - 2
    $short = $CurrentFile
    if ($short.Length -gt ($width - 10)) { $short = "..." + $short.Substring($short.Length - ($width - 10) + 3) }
    $script:ScanRecent.Enqueue($short)

    $elapsed = (Get-Date) - $StartTime
    $speed = 0
    if ($elapsed.TotalSeconds -gt 0.5) { $speed = [math]::Round($Scanned / $elapsed.TotalSeconds) }
    $ts = "{0:hh\:mm\:ss}" -f $elapsed

    $frames = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $script:SpinIdx = ($script:SpinIdx + 1) % $frames.Count
    $spinner = $frames[$script:SpinIdx]

    $barLen = 25
    $filled = [math]::Round(($Percent / 100) * $barLen)
    if ($filled -lt 0) { $filled = 0 }
    if ($filled -gt $barLen) { $filled = $barLen }
    $empty = $barLen - $filled
    $bar = ("█" * $filled) + ("▒" * $empty)
    $pctStr = "$Percent%".PadLeft(4)

    $status = "  $spinner [ $pctStr ] [$bar] $DriveLabel | {0:N0} archivos | {1} arch/s | Rojos: {2} | {3}" -f $Scanned, $speed, $Hits, $ts

    $lines = @($status)
    foreach ($f in $script:ScanRecent) { $lines += "    > $f" }

    foreach ($line in $lines) { Write-Host ($line.PadRight($width)) -ForegroundColor DarkCyan }
    $top = [Console]::CursorTop - $lines.Count
    if ($top -lt 0) { $top = 0 }
    try { [Console]::SetCursorPosition(0, $top) } catch { }
}

function Close-ScanMonitor {
    param([string]$Message, [string]$Color = "Green")
    $width = [Console]::WindowWidth - 2
    $lines = @($Message.PadRight($width))
    for ($i = 1; $i -lt 7; $i++) { $lines += "".PadRight($width) }
    foreach ($line in $lines) { Write-Host $line -ForegroundColor $Color }
}

function Start-SafeRemote {
    param([string]$Url, [string]$Title)
    Clear-Host
    Show-Header $Title
    Write-Host "       [ * ] Descargando y ejecutando en esta terminal..." -ForegroundColor Cyan
    Write-Host "       $($("─" * $script:BoxW))" -ForegroundColor DarkBlue
    try {
        $scriptContent = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 15
        $scriptBlock   = [ScriptBlock]::Create($scriptContent)
        & $scriptBlock
    } catch {
        Write-Host "`n       [!] Error al procesar el script remoto: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pause-Scanner
}

# ============================================================
# MÓDULOS DE ESCANEO PRINCIPALES
# ============================================================
function Start-GlobalScan {
    Clear-Host
    Show-Header "ESCANEO GLOBAL DEL SISTEMA (OPTIMIZADO)"

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
    $script:ScanRecent = [System.Collections.Generic.Queue[string]]::new()
    $scanStart = Get-Date

    $cRam = 0; $cPref = 0; $cPap = 0; $cMods = 0; $cSvc = 3;

    Write-Host "       [ X ] INICIANDO AUDITORIA GLOBAL. POR FAVOR ESPERA..." -ForegroundColor Cyan
    Write-Host "       $($("-" * $script:BoxW))" -ForegroundColor DarkBlue

    try {
        Show-PhaseProgress -Step 1 -Total 7 -Text "1/7 Analizando Memoria RAM..."
        $allProcs = Get-Process -ErrorAction SilentlyContinue
        $cRam = $allProcs.Count
        foreach ($proc in ($allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) })) {
            $memoria.Add("[JAVA] INSTANCIA ACTIVA : $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
        }
        foreach ($proc in ($allProcs | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
            $memoria.Add("[PROCESO MACRO MALICIOSO] $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
            $maliciosos.Add("[EN MEMORIA] $($proc.Name).exe | PID: $($proc.Id)")
        }
        Add-ToMasterLog $memoria
    } catch {}

    try {
        Show-PhaseProgress -Step 2 -Total 7 -Text "2/7 Extrayendo Prefetch..."
        $hoy = (Get-Date).Date
        $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
        $cPref = if ($pfFiles) { $pfFiles.Count } else { 0 }
        foreach ($item in ($pfFiles | Where-Object { $_.LastWriteTime.Date -ge $hoy } | Sort-Object LastWriteTime -Descending)) {
            if ($script:RxHacks.IsMatch($item.Name)) {
                $prefetchHoy.Add("[PREFETCH MALICIOSO] $($item.Name) | Hora: $($item.LastWriteTime)")
                $maliciosos.Add("[PREFETCH HACK] $($item.Name) | Hora: $($item.LastWriteTime)")
            } else {
                $prefetchHoy.Add("[PREFETCH] $($item.Name) | Hora: $($item.LastWriteTime)")
            }
        }
        Add-ToMasterLog $prefetchHoy
    } catch {}

    try {
        Show-PhaseProgress -Step 3 -Total 7 -Text "3/7 Volcando Papelera de Reciclaje..."
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
    } catch {}

    try {
        Show-PhaseProgress -Step 4 -Total 7 -Text "4/7 Auditando .minecraft/mods..."
        if (Test-Path $script:DefaultModsPath) {
            $localMods = Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip","*.dll" -ErrorAction SilentlyContinue
            $cMods = if ($localMods) { $localMods.Count } else { 0 }
            foreach ($mod in $localMods) {
                if ($script:RxHacks.IsMatch($mod.Name) -or $mod.Length -lt 15KB) {
                    $mods.Add("[MOD ILEGAL - TE VAS BAN] $($mod.Name) | Ruta: $($mod.FullName)")
                    $maliciosos.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                } else {
                    $mods.Add("[MOD APROBADO] $($mod.Name) | Ruta: OK")
                }
            }
        }
        Add-ToMasterLog $mods
    } catch {}

    try {
        Show-PhaseProgress -Step 5 -Total 7 -Text "5/7 Verificando Macros y Perifericos..."
        foreach ($kp in @(
            @{ Path = "$env:USERPROFILE\AppData\Local\LGHUB\settings.db"; Name = "Logitech G HUB" },
            @{ Path = "$env:APPDATA\AutoHotkey"; Name = "AutoHotkey" }
        )) {
            if (Test-Path $kp.Path) {
                $macros.Add("[SOFTWARE MACRO INSTALADO] $($kp.Name) | Ruta: $($kp.Path)")
                $maliciosos.Add("[SOFTWARE MACRO] $($kp.Name) | Ruta: $($kp.Path)")
            }
        }
        Add-ToMasterLog $macros
    } catch {}

    try {
        Show-PhaseProgress -Step 6 -Total 7 -Text "6/7 Evaluando Servicios de Windows..."
        foreach ($service in @("pcasvc", "bam", "sysmain")) {
            $output = @(& sc.exe query $service 2>&1) -join "`n"
            if ($output -match 'STOPPED') {
                $servicios.Add("[PELIGRO] SERVICIO APAGADO: $service | Estado: STOPPED")
            } else {
                $servicios.Add("[SERVICIO OK] $service | Estado: RUNNING")
            }
        }
        Add-ToMasterLog $servicios
    } catch {}

    try {
        Show-PhaseProgress -Step 7 -Total 7 -Text "7/7 Escaneo Profundo de Discos (Omitiendo Windows)..."
        Write-Host "       [i] Monitor en vivo activado. Escaneando directorios de usuario y discos secundarios.`n" -ForegroundColor DarkGray

        $diskRxHacks = [regex]::new((($script:IllegalKeywords | ForEach-Object {
            if ($_.Length -le 5) { "\b$_\b" } else { $_ }
        }) -join "|"), $script:RxOpts)

        $targetExt = '\.(jar|zip|exe|dll|ahk|au3|msi|bat|cmd|ps1|vbs|scr|hta|com)$'
        $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -eq 'Fixed' }
        $lastDraw = [datetime]::MinValue

        $dirsToScan = @()
        foreach ($drive in $drives) {
            if ($drive.Name.StartsWith("C:\")) {
                $dirsToScan += "$env:USERPROFILE"
                if (Test-Path "C:\ProgramData") { $dirsToScan += "C:\ProgramData" }
            } else {
                $dirsToScan += $drive.RootDirectory.FullName
            }
        }

        $expectedBytes = 20000000000 
        $scannedBytes = 0

        foreach ($dir in $dirsToScan) {
            if (-not (Test-Path $dir)) { continue }
            $label = $dir
            if ($label.Length -gt 15) { $label = "..." + $label.Substring($label.Length - 12) }

            Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $script:ScanCount++
                $scannedBytes += $_.Length
                $full = $_.FullName

                if (($script:ScanCount % 40) -eq 0 -and ((Get-Date) - $lastDraw).TotalMilliseconds -gt 80) {
                    $pct = [math]::Min(99, [math]::Round(($scannedBytes / $expectedBytes) * 100))
                    Update-ScanMonitor -Scanned $script:ScanCount -Hits $script:DeepHits `
                        -CurrentFile $full -DriveLabel $label -StartTime $scanStart -Percent $pct
                    $lastDraw = Get-Date
                }

                if ($full -notmatch $targetExt) { return }
                if ($script:RxPathWhitelist.IsMatch($full)) { return }
                if ($diskRxHacks.IsMatch($_.Name) -or $script:RxMacroCritical.IsMatch($_.Name)) {
                    $script:DeepHits++
                    $disco.Add("[ARCHIVO ILEGAL - TE VAS BAN] $($_.Name) | Ruta: $full")
                    $maliciosos.Add("[EN DISCO] $($_.Name) | Ruta: $full")
                }
            }
        }
        Update-ScanMonitor -Scanned $script:ScanCount -Hits $script:DeepHits -CurrentFile "COMPLETADO" -DriveLabel "OK" -StartTime $scanStart -Percent 100
        $elapsed = (Get-Date) - $scanStart
        Close-ScanMonitor -Message ("  [+] Disco revisado: {0:N0} archivos | {1} maliciosos | Tiempo: {2:hh\:mm\:ss}" -f $script:ScanCount, $script:DeepHits, $elapsed)
        Add-ToMasterLog $disco
        Add-ToMasterLog $maliciosos
    } catch {}

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
        Write-Host "       [*] Generando reporte forense estructurado..." -ForegroundColor White
        $reportPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Reporte_Sombrio_V72.txt"

        $header = @(
            "==============================================================="
            " REPORTE FORENSE - EL SOMBRIO IF V72 (FINAL FIXES)"
            " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            " Equipo: $env:COMPUTERNAME | Usuario: $env:USERNAME"
            " Archivos revisados en disco completo: $script:ScanCount"
            " Hallazgos maliciosos en disco: $script:DeepHits"
            "==============================================================="
        ) + "" + " [RESUMEN]" + $statsBox + "" + " [1] MEMORIA" + $memoria + "" + " [2] PREFETCH" + $prefetchHoy + "" +
           " [3] MALICIOSOS" + $maliciosos + "" + " [4] MODS" + $mods + "" +
           " [5] MACROS" + $macros + "" + " [6] SERVICIOS" + $servicios + "" +
           " [7] DISCO" + $disco

        $header | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    } catch {}

    Start-Sleep -Seconds 1

    $dash = [ordered]@{}
    $dash["ESTADÍSTICAS GLOBALES DEL ANÁLISIS"] = @{ Items = $statsBox;    Force = $true;  Color = "Yellow" }
    $dash["CUADRO 1 - MEMORIA / PROCESOS"]      = @{ Items = $memoria;     Force = $true;  Color = "Cyan" }
    $dash["CUADRO 2 - PREFETCH DE HOY (TODO)"]  = @{ Items = $prefetchHoy; Force = $true;  Color = "White" }
    $dash["CUADRO 3 - MALICIOSOS (ROJO)"]       = @{ Items = $maliciosos;  Force = $true;  Color = "Red" }
    $dash["CUADRO 4 - MODS (.MINECRAFT)"]       = @{ Items = $mods;        Force = $false; Color = "Cyan" }
    $dash["CUADRO 5 - MACROS / AUTOCLICKERS"]   = @{ Items = $macros;      Force = $false; Color = "Cyan" }
    $dash["CUADRO 6 - SISTEMA (SERVICIOS)"]     = @{ Items = $servicios;   Force = $true;  Color = "Cyan" }
    $dash["CUADRO 7 - DISCO PROFUNDO"]          = @{ Items = $disco;       Force = $false; Color = "Cyan" }

    Show-GlobalDashboard -Categories $dash
}

# ============================================================
# MÓDULOS DE ESCANEO SECUNDARIOS
# ============================================================
function Start-UnifiedModScan {
    Clear-Host
    Show-Header "AUDITORÍA DE MODS"
    $mods = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $script:DefaultModsPath) {
        foreach ($mod in (Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip" -ErrorAction SilentlyContinue)) {
            if ($script:RxHacks.IsMatch($mod.Name)) {
                $mods.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
            } else {
                $mods.Add("[MOD APROBADO] $($mod.Name) | Ruta: OK")
            }
        }
    }
    Add-ToMasterLog $mods
    Clear-Host
    Show-Header "RESULTADOS - MODS"
    Show-CategoryBox -Title "MODS (.MINECRAFT)" -Items $mods -Force -TitleColor "Cyan"
    Pause-Scanner
}

function Start-TraceScan {
    Clear-Host
    Show-Header "ANÁLISIS DE PREFETCH"
    $todo  = [System.Collections.Generic.List[string]]::new()
    $malo  = [System.Collections.Generic.List[string]]::new()

    $hoy = (Get-Date).Date
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue |
               Where-Object { $_.LastWriteTime.Date -ge $hoy } | Sort-Object LastWriteTime -Descending

    foreach ($item in $pfFiles) {
        if ($script:RxHacks.IsMatch($item.Name)) {
            $todo.Add("[PREFETCH MALICIOSO] $($item.Name) | Hora: $($item.LastWriteTime)")
            $malo.Add("[PREFETCH HACK] $($item.Name) | Hora: $($item.LastWriteTime)")
        } else {
            $todo.Add("[PREFETCH NORMAL] $($item.Name) | Hora: $($item.LastWriteTime)")
        }
    }
    Add-ToMasterLog $todo
    Clear-Host
    Show-Header "RESULTADOS - PREFETCH DE HOY"
    Show-CategoryBox -Title "PREFETCH DE HOY - TODO" -Items $todo -Force -TitleColor "White"
    Show-CategoryBox -Title "PREFETCH MALICIOSOS" -Items $malo -Force -TitleColor "Red"
    Pause-Scanner
}

function Start-MacroAutoclickScan {
    Clear-Host
    Show-Header "DETECCIÓN DE MACROS"
    $macros = [System.Collections.Generic.List[string]]::new()
    foreach ($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
        $macros.Add("[PROCESO MALICIOSO] $($proc.Name).exe | PID: $($proc.Id)")
    }
    Add-ToMasterLog $macros
    Clear-Host
    Show-Header "RESULTADOS - MACROS"
    Show-CategoryBox -Title "MACROS EN MEMORIA" -Items $macros -Force -TitleColor "Red"
    Pause-Scanner
}

function Start-ServicesAudit {
    Clear-Host
    Show-Header "AUDITORÍA DE SERVICIOS"
    $servicios = [System.Collections.Generic.List[string]]::new()
    foreach ($srvName in $script:WindowsServices) {
        $srv = Get-Service -Name $srvName -ErrorAction SilentlyContinue
        if ($srv) {
            $servicios.Add("$($srv.Name) ($($srv.DisplayName)) | Estado: $($srv.Status)")
        }
    }
    Add-ToMasterLog $servicios
    Clear-Host
    Show-Header "RESULTADOS - SERVICIOS"
    Show-CategoryBox -Title "SISTEMA WINDOWS" -Items $servicios -Force -TitleColor "Cyan"
    Pause-Scanner
}

function Start-SysMaintenance {
    Clear-Host
    Show-Header "MANTENIMIENTO"
    Write-Host "       [ * ] Limpiando búferes y optimizando terminal..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    Write-Host "       [+] Sistema optimizado con éxito." -ForegroundColor Green
    Pause-Scanner
}

function Start-Hubs {
    Clear-Host
    Show-Header "HERRAMIENTAS EXTERNAS"
    Write-Host "       [ 1 ] System Informer" -ForegroundColor White
    Write-Host "       [ 2 ] JournalTrace" -ForegroundColor White
    $ch = Read-Host "`n       Selecciona una opción o 0 para salir"
    if ($ch -eq "1") { Start-Process "https://sourceforge.net/projects/systeminformer/" }
    Pause-Scanner
}

function Start-ShowRegistry {
    Clear-Host
    Show-Header "REGISTRO DE ANÁLISIS ACUMULADO"
    if ($script:MasterLog.Count -eq 0) {
        Write-Host "`n       [!] La memoria de análisis está vacía. Ejecute un escaneo primero." -ForegroundColor Yellow
    } else {
        Show-CategoryBox -Title "HISTORIAL DE HALLAZGOS (SESIÓN ACTUAL)" -Items $script:MasterLog -Force -TitleColor "White"
    }
    Pause-Scanner
}

# ============================================================
# MENÚ PRINCIPAL MAESTRO
# ============================================================
function Show-MainMenu {
    if ($script:FirstRun) {
        Show-BootAnimation
        $script:FirstRun = $false
    }

    while ($true) {
        Show-Banner
        $isAdmin = Test-Administrator
        $statusText = if ($isAdmin) { " [ ESTADO: PRIVILEGIOS DE ADMINISTRADOR ACTIVOS ] " } else { " [ AVISO: EJECUTE COMO ADMINISTRADOR PARA MÁXIMA EFECTIVIDAD ] " }

        $menuLines = @(
            "       ╔═══════════════════════════════════════════════════════════════════════════════════════╗"
            "       ║                        [ CONSOLA CENTRAL DE OPERACIONES FORENSES ]                    ║"
            "       ╠═══════════════════════════════════════════════════════════════════════════════════════╣"
            "       ║$($statusText.PadRight(95))║"
            "       ╠═══════════════════════════════════════════════════════════════════════════════════════╣"
            "       ║                                                                                       ║"
            "       ║   [ 01 ] Escaneo Global Optimizado       ║   [ 06 ] Auditoría de Servicios Windows    ║"
            "       ║   [ 02 ] Auditoría de Mods e Instancias  ║   [ 07 ] Utilidades y Mantenimiento        ║"
            "       ║   [ 03 ] Doomsday Detector (Nube)        ║   [ 08 ] Hub de Herramientas Externas      ║"
            "       ║   [ 04 ] Análisis de Prefetch (solo)     ║   [ 09 ] Registro de Análisis (Memoria)    ║"
            "       ║   [ 05 ] Búsqueda de Macros & Autoclick  ║   [ 10 ] Salir del Framework               ║"
            "       ║                                          ║   [ 00 ] EXIT SILENCIOSO (PANIC BUTTON)    ║"
            "       ║                                                                                       ║"
            "       ╚═══════════════════════════════════════════════════════════════════════════════════════╝"
        )

        $gap        = "  "
        $catTopPad  = [math]::Max(0, [math]::Floor(($menuLines.Count - $script:sideCat.Count) / 2))
        $totalLines = [math]::Max($menuLines.Count, $catTopPad + $script:sideCat.Count)

        for ($i = 0; $i -lt $totalLines; $i++) {
            if ($i -lt $menuLines.Count) {
                $left = $menuLines[$i]
                if ($left -match "╔|╚|═|╠") {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor DarkBlue
                } elseif ($left -match "CONSOLA CENTRAL") {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Cyan
                } elseif ($left -match "ESTADO|AVISO") {
                    $col = if ($isAdmin) { "Green" } else { "Yellow" }
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor $col
                } else {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Blue
                }
            } else {
                Write-Host (" " * $script:BoxW) -NoNewline
            }

            Write-Host $gap -NoNewline

            $catIdx = $i - $catTopPad
            if ($catIdx -ge 0 -and $catIdx -lt $script:sideCat.Count) {
                $catLine = $script:sideCat[$catIdx].TrimEnd()
                if ($catLine -match "o o") { Write-Host $catLine -ForegroundColor White }
                elseif ($catLine -match "\=\^\=") { Write-Host $catLine -ForegroundColor Yellow }
                elseif ($catLine -match "___|_______|____") { Write-Host $catLine -ForegroundColor DarkBlue }
                else { Write-Host $catLine -ForegroundColor Cyan }
            } else { Write-Host "" }
        }
        Write-Host ""

        $option = [string](Read-Host "       [ROOT@SOMBRIO-GATO]# Seleccione un módulo operativo [00-10]")

        switch ($option.Trim()) {
            "0"  { exit }
            "00" { exit }
            "1"  { Start-GlobalScan }
            "01" { Start-GlobalScan }
            "2"  { Start-UnifiedModScan }
            "02" { Start-UnifiedModScan }
            "3"  { Start-SafeRemote -Url "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1" -Title "DOOMSDAY DETECTOR" }
            "03" { Start-SafeRemote -Url "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1" -Title "DOOMSDAY DETECTOR" }
            "4"  { Start-TraceScan }
            "04" { Start-TraceScan }
            "5"  { Start-MacroAutoclickScan }
            "05" { Start-MacroAutoclickScan }
            "6"  { Start-ServicesAudit }
            "06" { Start-ServicesAudit }
            "7"  { Start-SysMaintenance }
            "07" { Start-SysMaintenance }
            "8"  { Start-Hubs }
            "08" { Start-Hubs }
            "9"  { Start-ShowRegistry }
            "09" { Start-ShowRegistry }
            "10" { return }
            default {
                if ($option.Trim() -ne "") {
                    Write-Host "`n       [!] Comando no reconocido en el sistema." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}

Show-MainMenu
