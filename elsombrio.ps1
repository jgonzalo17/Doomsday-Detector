#Requires -Version 5.1
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V49 - CUSTOM ANIME UI)
# ============================================================

$script:DefaultModsPath = "$env:APPDATA\.minecraft\mods"
$script:FirstRun = $true

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

$script:RegexHacks = ($script:IllegalKeywords -join "|")

# ------------------------------------------------------------
# LISTA UNIFICADA Y AMPLIADA DE MACROS / AUTOCLICKERS
# ------------------------------------------------------------
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
$script:RegexMacroCritical = ($script:MacroAutoclickCritical -join "|")

$script:MacroAutoclickSuspect = @(
    "clickspeed", "click-speed", "fastclick", "fast-click", "clicklock", "clickr",
    "multiclicker", "hydraclicker", "clickmachine", "neoclicker", "advancedclicker",
    "leftclickrepeater", "clickrepeater", "speedclicker", "clickyclicky", "perfectautomate",
    "doitagain", "do it again", "orion macro", "quick macros", "quickmacros",
    "automationanywhere", "x-mouse", "xbutton", "xmousebuttoncontrol"
)
$script:RegexMacroSuspect = ($script:MacroAutoclickSuspect -join "|")

$script:PathWhitelistPatterns = "site-packages|dist-packages|\\lib\\python|\\Lib\\|\\venv\\|\\\.venv\\|\\conda\\|node_modules|\\Scripts\\|pydevd"

# ------------------------------------------------------------
# OPTIMIZACIÓN: Regex precompilados
# ------------------------------------------------------------
$script:RxOpts = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled'
$script:RxHacks           = [regex]::new($script:RegexHacks, $script:RxOpts)
$script:RxMacroCritical   = [regex]::new($script:RegexMacroCritical, $script:RxOpts)
$script:RxMacroSuspect    = [regex]::new($script:RegexMacroSuspect, $script:RxOpts)
$script:RxPathWhitelist   = [regex]::new($script:PathWhitelistPatterns, $script:RxOpts)
$script:RxMcProcess       = [regex]::new("java|javaw|lunarclient|craft", $script:RxOpts)

$script:WindowsServices = @("dps", "appinfo", "pcasvc", "eventlog", "sysmain", "dusmsvc", "bam")

# ============================================================
# MOTOR SOMBRIO DECOMPRESSOR SEGURO
# ============================================================
if (-not ([System.Management.Automation.PSTypeName]'SombrioDecompressor').Type) {
    try {
        Add-Type -TypeDefinition @"
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
"@
    } catch { }
}

# ============================================================
# ANIMACIONES Y EFECTOS VISUALES
# ============================================================
function Invoke-Typewriter {
    param([string]$Text, [int]$Speed = 15, [string]$Color = "White")
    foreach ($char in $Text.ToCharArray()) {
        Write-Host $char -NoNewline -ForegroundColor $Color
        Start-Sleep -Milliseconds $Speed
    }
    Write-Host ""
}

function Show-BootAnimation {
    $bootSteps = @(
        "Inicializando módulos de descompresión NT...",
        "Resolviendo dependencias remotas y APIs...",
        "Inyectando hooks en procesos de memoria...",
        "Sincronizando paleta de colores Ciber-Neón...",
        "Estableciendo enlace de sistema seguro..."
    )

    for ($i=0; $i -lt 15; $i++) {
        Clear-Host
        Write-Host "`n`n`n`n"
        Write-Host "                            |\__/,|   (`\ " -ForegroundColor Cyan
        Write-Host "                          _.|o o  |_   ) ) " -ForegroundColor Cyan
        Write-Host "                         -(((---(((-------- " -ForegroundColor Cyan
        
        $stepIndex = [math]::Min([math]::Floor($i / 3), $bootSteps.Count - 1)
        Write-Host "`n       [Bootloader] $($bootSteps[$stepIndex])" -ForegroundColor DarkGray
        
        $pct = [math]::Round((($i + 1) / 15) * 100)
        $barLength = 40
        $filled = [math]::Round(($pct / 100) * $barLength)
        $empty = $barLength - $filled
        $progressBar = "█" * $filled + "▒" * $empty
        
        Write-Host "       [System]     $pct% [$progressBar]" -ForegroundColor Magenta
        Start-Sleep -Milliseconds 120
    }
    Write-Host "`n       [OK] INTERFAZ LISTA. SISTEMA FORENSE OPERATIVO.`n" -ForegroundColor Green
    Start-Sleep -Milliseconds 600
}

function Show-Banner {
    Clear-Host
    $banner = @"
       ███████╗ ██████╗ ███╗   ███╗██████╗ ██████╗ ██╗ ██████╗
       ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║██╔═══██╗
       ███████╗██║   ██║██╔████╔██║██████╔╝██████╔╝██║██║   ██║
       ╚════██║██║   ██║██║╚██╔╝██║██╔══██╗██╔══██╗██║██║   ██║
       ███████║╚██████╔╝██║ ╚═╝ ██║██████╔╝██║  ██║██║╚██████╔╝
       ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "                  [ ADVANCED FORENSIC SCANNER - CUSTOM UI ]                `n" -ForegroundColor Magenta
}

function Show-Header {
    param([string]$Subtitle)
    Write-Host "`n       ╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "       ║                  EL SOMBRIO IF - FORENSIC SCANNER                     ║" -ForegroundColor Cyan
    Write-Host "       ╠═══════════════════════════════════════════════════════════════════════╣" -ForegroundColor DarkCyan
    $pad = [math]::Max(0, [math]::Floor((71 - $Subtitle.Length) / 2))
    $str = ((' ' * $pad) + $Subtitle).PadRight(71, ' ')
    Write-Host ("       ║{0}║" -f $str) -ForegroundColor White
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor DarkCyan
}

function Pause-Scanner {
    Write-Host "`n       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Invoke-Typewriter "       [ Presiona ENTER para regresar al menú principal ]" -Speed 10 -Color Magenta
    Read-Host | Out-Null
}

function Show-DetectionBox {
    param([array]$Detections, [string]$Title, [bool]$IsDanger = $false)
    
    Clear-Host
    Show-Header "REPORTE DE AUDITORÍA"

    $borderColor = if ($IsDanger -or ($Detections | Where-Object { $_ -match "HACK|TE VAS BAN|ILEGAL|PELIGRO" })) { "Red" } else { "DarkGray" }
    
    Write-Host "       ╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $borderColor
    $pad = [math]::Max(0, [math]::Floor((71 - $Title.Length) / 2))
    $str = ((' ' * $pad) + $Title).PadRight(71, ' ')
    Write-Host "       ║$str║" -ForegroundColor Yellow
    Write-Host "       ╠═══════════════════════════════════════════════════════════════════════╣" -ForegroundColor $borderColor
    
    if ($Detections.Count -eq 0) {
        Write-Host "       ║ No se detectaron anomalías en este escaneo.                           ║" -ForegroundColor Green
    } else {
        foreach ($item in $Detections) {
            $displayStr = $item
            $idx = $displayStr.IndexOf(" | Ruta:")
            if ($idx -ge 0) { $displayStr = $displayStr.Substring(0, $idx) }
            if ($displayStr.Length -gt 67) { $displayStr = $displayStr.Substring(0, 64) + "..." }
            
            $textColor = "Yellow"
            if ($item -match "HACK|TE VAS BAN|ILEGAL|PELIGRO") { $textColor = "Red" }
            elseif ($item -match "\[JAVA\]|java\.exe|javaw\.exe|lunarclient") { $textColor = "Cyan" }
            elseif ($item -match "======") { $textColor = "Magenta" }
            elseif ($item -match "\[NORMAL\]|\[ELIMINADO\]|APROBADO") { $textColor = "Green" }
            
            if ($item -match "======") {
                $itemStr = ("   " + $displayStr).PadRight(71, ' ')
            } else {
                $itemStr = (" > " + $displayStr).PadRight(71, ' ')
            }

            Write-Host "       ║$itemStr║" -ForegroundColor $textColor
        }
    }
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $borderColor
    
    if ($Detections.Count -gt 0) {
        Write-Host "`n       [ ❖ ] LOG DETALLADO Y RUTAS:" -ForegroundColor Cyan
        Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($item in $Detections) { 
            if ($item -notmatch "======") {
                $textColor = "Gray"
                if ($item -match "HACK|TE VAS BAN|ILEGAL|PELIGRO") { $textColor = "Red" }
                elseif ($item -match "\[JAVA\]|java\.exe|javaw\.exe|lunarclient") { $textColor = "Cyan" }
                elseif ($item -match "\[NORMAL\]|\[ELIMINADO\]|APROBADO") { $textColor = "Green" }
                Write-Host "       -> $item" -ForegroundColor $textColor 
            }
        }
    }
}

function Test-Administrator { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

# ============================================================
# AISLAMIENTO DE SCRIPTS EXTERNOS (ANTI-CRASHEO)
# ============================================================
function Start-SafeRemote {
    param([string]$Url, [string]$Title)
    Clear-Host
    Show-Header $Title
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    
    Write-Host "       [ ❖ ] CONECTANDO Y LANZANDO MÓDULO AISLADO..." -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "       [*] Esto protege el escáner si el módulo externo falla o lo cierras." -ForegroundColor Gray
    Write-Host "       [*] Ejecutando herramienta externa, por favor espera...`n" -ForegroundColor Magenta
    
    try {
        # Ejecuta el script remoto en un sub-proceso bloqueando errores fatales. Si da error, sale limpio.
        $cmd = "irm '$Url' | iex"
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -Wait -NoNewWindow
    } catch {
        Write-Host "`n       [!] Error al invocar el proceso externo: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host "`n       [+] Módulo finalizado correctamente. Regresando al núcleo..." -ForegroundColor Green
    Pause-Scanner
}

# ============================================================
# MÓDULOS DE ESCANEO
# ============================================================

function Start-GlobalScan {
    Clear-Host
    Show-Header "ESCANEO GLOBAL DEL SISTEMA (ONE-CLICK)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    
    $hallazgosGlobales = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] INICIANDO AUDITORÍA GLOBAL. POR FAVOR ESPERA..." -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    # 1. Instancias RAM
    Write-Host "       [*] 1/6 Analizando Memoria RAM e Instancias..." -ForegroundColor White
    $allProcs = Get-Process -ErrorAction SilentlyContinue
    $mcProcs = $allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) }
    $badProcs = $allProcs | Where-Object { $script:RxHacks.IsMatch($_.Name) }
    
    if ($mcProcs) {
        foreach ($proc in $mcProcs) {
            $hallazgosGlobales.Add("[JAVA] INSTANCIA ACTIVA : $($proc.Name).exe (PID: $($proc.Id)) | Ruta: Memoria")
            try {
                $proc.Modules | Where-Object { $script:RxHacks.IsMatch($_.FileName) } | ForEach-Object {
                    $hallazgosGlobales.Add("[INYECCIÓN EN RAM - TE VAS BAN] $($_.ModuleName) | Ruta: $($_.FileName)")
                }
            } catch {}
        }
    }
    if ($badProcs) {
        foreach ($proc in $badProcs) {
            $hallazgosGlobales.Add("[PROCESO HACK - TE VAS BAN] $($proc.Name).exe (PID: $($proc.Id)) | Ruta: Memoria (Activo)")
        }
    }

    # 2. Prefetch
    Write-Host "       [*] 2/6 Extrayendo historial de Prefetch..." -ForegroundColor White
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
    if ($pfFiles) {
        $hace2 = (Get-Date).Date.AddDays(-2)
        $validFiles = $pfFiles | Where-Object { $_.LastWriteTime.Date -ge $hace2 } | Sort-Object LastWriteTime -Descending
        foreach ($item in $validFiles) {
            if ($script:RxHacks.IsMatch($item.Name)) {
                $hallazgosGlobales.Add("[PREFETCH HACK - TE VAS BAN] $($item.LastWriteTime.ToString('dd/MM HH:mm')) -> $($item.Name) | Ruta: C:\Windows\Prefetch")
            }
        }
    }

    # 3. Papelera
    Write-Host "       [*] 3/6 Volcando Papelera de Reciclaje..." -ForegroundColor White
    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        foreach ($item in $papelera.Items()) {
            if ($script:RxHacks.IsMatch($item.Name)) {
                $hallazgosGlobales.Add("[PAPELERA HACK - TE VAS BAN] $($item.Name) | Ruta: $($item.Path)")
            }
        }
    } catch {}

    # 4. Carpeta de Mods
    Write-Host "       [*] 4/6 Auditando modificaciones en .minecraft/mods..." -ForegroundColor White
    if (Test-Path $script:DefaultModsPath) {
        $modFiles = Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar", "*.zip", "*.dll"
        foreach ($mod in $modFiles) {
            $isBad = $false
            if ($script:RxHacks.IsMatch($mod.Name)) { $isBad = $true }
            if ($mod.LastWriteTime -gt $mod.CreationTime.AddDays(7)) { $isBad = $true }
            if ($mod.Length -lt 15KB) { $isBad = $true }
            if ($isBad) {
                $hallazgosGlobales.Add("[MOD ILEGAL - TE VAS BAN] $($mod.Name) | Ruta: $($mod.FullName)")
            }
        }
    }

    # 5. Macros Instaladas
    Write-Host "       [*] 5/6 Verificando directorios de Macros y Periféricos..." -ForegroundColor White
    $knownPaths = @(
        @{ Path = "$env:USERPROFILE\AppData\Local\Logitech\Logitech Gaming Software\settings.json"; Name = "Logitech Gaming Software" },
        @{ Path = "$env:USERPROFILE\AppData\Local\LGHUB\settings.db"; Name = "Logitech G HUB" },
        @{ Path = "C:\Program Files (x86)\Bloody7\Bloody7\Data\Mouse\English\ScriptsMacros\GunLib\"; Name = "Bloody Macro Suite" },
        @{ Path = "$env:APPDATA\AutoHotkey"; Name = "AutoHotkey" }
    )
    foreach ($kp in $knownPaths) {
        if (Test-Path $kp.Path) {
            $hallazgosGlobales.Add("[SOFTWARE MACRO INSTALADO] $($kp.Name) | Ruta: $($kp.Path)")
        }
    }

    # 6. Servicios Críticos
    Write-Host "       [*] 6/6 Evaluando Servicios Base de Windows..." -ForegroundColor White
    foreach ($service in @("pcasvc", "bam", "sysmain")) {
        $output = @(& sc.exe query $service 2>&1) -join "`n"
        if ($output -match 'STOPPED') {
            $hallazgosGlobales.Add("[PELIGRO] SERVICIO APAGADO CRÍTICO: $service | Ruta: N/A")
        }
    }

    Start-Sleep -Seconds 1
    Show-DetectionBox -Detections $hallazgosGlobales -Title "RESULTADOS DE ALERTAS DE AUDITORÍA GLOBAL"
    Pause-Scanner
}


function Start-SystemScan {
    Clear-Host
    Show-Header "INTERVENCIÓN RÁPIDA (PREFETCH - ÚLTIMOS 3 DÍAS)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador para leer Prefetch."; Pause-Scanner; return }
    
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
    if ($pfFiles) {
        $hoy = (Get-Date).Date
        $ayer = $hoy.AddDays(-1)
        $hace2 = $hoy.AddDays(-2)

        $validFiles = $pfFiles | Where-Object { $_.LastWriteTime.Date -ge $hace2 } | Sort-Object LastWriteTime -Descending
        
        $listHoy = $validFiles | Where-Object { $_.LastWriteTime.Date -eq $hoy }
        $listAyer = $validFiles | Where-Object { $_.LastWriteTime.Date -eq $ayer }
        $listHace2 = $validFiles | Where-Object { $_.LastWriteTime.Date -eq $hace2 }

        function Add-GroupToList($group, $title) {
            if ($group -and $group.Count -gt 0) {
                $hallazgos.Add("====== $title ======")
                foreach ($item in $group) {
                    $timeStr = $item.LastWriteTime.ToString("HH:mm:ss")
                    if ($script:RxHacks.IsMatch($item.Name)) {
                        $hallazgos.Add("[HACK - TE VAS BAN] HORA: $timeStr -> $($item.Name) | Ruta: $($item.FullName)")
                    } elseif ($script:RxMcProcess.IsMatch($item.Name)) {
                        $hallazgos.Add("[JAVA] HORA: $timeStr -> $($item.Name) | Ruta: $($item.FullName)")
                    } else {
                        $hallazgos.Add("[NORMAL] HORA: $timeStr -> $($item.Name) | Ruta: $($item.FullName)")
                    }
                }
            }
        }

        Add-GroupToList $listHoy "HOY"
        Add-GroupToList $listAyer "AYER"
        Add-GroupToList $listHace2 "HACE DOS DÍAS"

    } else {
         $hallazgos.Add("[!] La carpeta Prefetch está completamente vacía o el acceso fue denegado.")
    }
    
    Show-DetectionBox -Detections $hallazgos -Title "HISTORIAL PREFETCH COMPLETO (3 DÍAS)"
    Pause-Scanner
}

function Start-RecycleBinScan {
    Clear-Host
    Show-Header "ANÁLISIS DE PAPELERA DE RECICLAJE"
    $hallazgosPapelera = [System.Collections.Generic.List[string]]::new()
    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        foreach ($item in $papelera.Items()) {
            if ($script:RxHacks.IsMatch($item.Name)) { 
                $hallazgosPapelera.Add("[HACK BORRADO - TE VAS BAN] $($item.Name) | Ruta: $($item.Path)") 
            } else {
                $hallazgosPapelera.Add("[ELIMINADO] $($item.Name) | Ruta: $($item.Path)")
            }
        }
    } catch {}
    Show-DetectionBox -Detections $hallazgosPapelera -Title "RESULTADOS DE ALERTAS DE AUDITORÍA"
    Pause-Scanner
}

function Start-MacroAutoclickScan {
    Clear-Host
    Show-Header "AUDITORÍA UNIFICADA: MACROS Y AUTOCLICKERS"
    $hallazgos = [System.Collections.Generic.List[string]]::new()

    Write-Host "       [ ❖ ] FASE 1: SOFTWARE DE MACROS/PERIFÉRICOS INSTALADO" -ForegroundColor Cyan
    $knownPaths = @(
        @{ Path = "$env:USERPROFILE\AppData\Local\Logitech\Logitech Gaming Software\settings.json"; Name = "Logitech Gaming Software" },
        @{ Path = "$env:USERPROFILE\AppData\Local\LGHUB\settings.db"; Name = "Logitech G HUB" },
        @{ Path = "C:\Program Files (x86)\Bloody7\Bloody7\Data\Mouse\English\ScriptsMacros\GunLib\"; Name = "Bloody Macro Suite" },
        @{ Path = "$env:APPDATA\AutoHotkey"; Name = "AutoHotkey (config/scripts)" },
        @{ Path = "$env:LOCALAPPDATA\TinyTask"; Name = "TinyTask" }
    )
    foreach ($kp in $knownPaths) {
        if (Test-Path $kp.Path) {
            $hallazgos.Add("[SOFTWARE MACRO INSTALADO] $($kp.Name) | Ruta: $($kp.Path)")
        }
    }

    Write-Host "       [ ❖ ] FASE 2: PROCESOS ACTIVOS EN MEMORIA" -ForegroundColor Cyan
    $activeProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) }
    if ($activeProcs) {
        foreach ($proc in $activeProcs) {
            $hallazgos.Add("[PROCESO ACTIVO - TE VAS BAN] $($proc.Name).exe (PID: $($proc.Id)) | Ruta: Memoria (Activo)")
        }
    }

    Write-Host "       [ ❖ ] FASE 3: ESCANEO PROFUNDO DE DISCO" -ForegroundColor Cyan
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } | Select-Object -ExpandProperty Root
    $allDirs = @()
    foreach ($drive in $drives) { $allDirs += Get-ChildItem -Path $drive -Directory -ErrorAction SilentlyContinue }
    $totalDirs = $allDirs.Count; $dirCount = 0

    foreach ($dir in $allDirs) {
        $dirCount++
        $pct = if ($totalDirs -gt 0) { [math]::Round(($dirCount / $totalDirs) * 100) } else { 100 }
        $barLength = 40; $filled = [math]::Round(($pct / 100) * $barLength); $pBar = "█" * $filled + "▒" * ($barLength - $filled)
        Write-Host "`r       [*] Escaneando Sistema [$pBar] $pct% " -NoNewline -ForegroundColor Magenta

        Get-ChildItem -Path $dir.FullName -Recurse -File -Include "*.exe","*.jar","*.bat","*.ahk","*.au3","*.vbs","*.py","*.dll","*.ps1" -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($script:RxMacroCritical.IsMatch($_.Name)) {
                $hallazgos.Add("[MACRO/AUTOCLICK DETECTADO - TE VAS BAN] $($_.Name) | Ruta: $($_.FullName)")
            }
        }
    }
    
    Show-DetectionBox -Detections $hallazgos -Title "RESULTADOS DE ALERTAS DE AUDITORÍA"
    Pause-Scanner
}

function Start-FullDiskScan {
    Clear-Host
    Show-Header "ANÁLISIS COMPLETO (MODIFICADOS Y BORRADOS)"
    $hallazgosDisco = [System.Collections.Generic.List[string]]::new()
    Write-Host "       [ ❖ ] FASE 1: ESCANEANDO PAPELERA EN TODOS LOS DISCOS LÓGICOS..." -ForegroundColor Cyan
    $sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    $dTotal = $drives.Count; $dCount = 0
    foreach ($drive in $drives) {
        $dCount++
        $pct = [math]::Round(($dCount / $dTotal) * 100)
        $barLength = 30; $filled = [math]::Round(($pct / 100) * $barLength); $pBar = "█" * $filled + "▒" * ($barLength - $filled)
        Write-Host "`r       [*] Procesando Papeleras   [$pBar] $pct% " -NoNewline -ForegroundColor Magenta
        $recPath = "$drive`$Recycle.Bin\$sid"
        if (Test-Path $recPath) {
            Get-ChildItem -Path $recPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($script:RxHacks.IsMatch($_.Name)) {
                    $hallazgosDisco.Add("[BORRADO HACK - TE VAS BAN] $($_.Name) | Ruta: $($_.FullName)")
                } else {
                    $hallazgosDisco.Add("[BORRADO NORMAL] $($_.Name) | Ruta: $($_.FullName)")
                }
            }
        }
    }
    Write-Host "`n       [ ❖ ] FASE 2: BUSCANDO EJECUTABLES Y MODS RECIENTEMENTE MODIFICADOS..." -ForegroundColor Cyan
    $userDirs = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    $uTotal = $userDirs.Count; $uCount = 0
    foreach ($dir in $userDirs) {
        $uCount++
        $pct = [math]::Round(($uCount / $uTotal) * 100)
        $barLength = 30; $filled = [math]::Round(($pct / 100) * $barLength); $pBar = "█" * $filled + "▒" * ($barLength - $filled)
        Write-Host "`r       [*] Escaneando Modificados [$pBar] $pct% " -NoNewline -ForegroundColor Magenta
        Get-ChildItem -Path $dir.FullName -Recurse -File -Include "*.jar","*.exe","*.bat" -ErrorAction SilentlyContinue | 
        Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-2) } | ForEach-Object {
            if ($script:RxHacks.IsMatch($_.Name)) {
                $hallazgosDisco.Add("[MODIFICADO HACK - TE VAS BAN] $($_.Name) | Ruta: $($_.FullName)")
            } else {
                $hallazgosDisco.Add("[MODIFICADO RECIENTE] $($_.Name) | Ruta: $($_.FullName)")
            }
        }
    }
    
    Show-DetectionBox -Detections $hallazgosDisco -Title "RESULTADOS DE ALERTAS DE AUDITORÍA"
    Pause-Scanner
}

function Start-ExtremeModScan {
    Clear-Host
    Show-Header "ANÁLISIS EXTREMO (PROCESOS, INSTANCIAS Y MODS)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] SEPARACIÓN DE PROCESOS (MEMORIA RAM EN TIEMPO REAL)" -ForegroundColor Cyan
    $allProcs = Get-Process -ErrorAction SilentlyContinue
    $mcProcs = $allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) }
    $badProcs = $allProcs | Where-Object { $script:RxHacks.IsMatch($_.Name) }

    if ($mcProcs) {
        foreach ($proc in $mcProcs) {
            $hallazgos.Add("[JAVA] INSTANCIA ACTIVA : $($proc.Name).exe (PID: $($proc.Id)) | Ruta: Memoria")
            try {
                $proc.Modules | Where-Object { $script:RxHacks.IsMatch($_.FileName) } | ForEach-Object {
                    $hallazgos.Add("[INYECCIÓN EN RAM - TE VAS BAN] $($_.ModuleName) | Ruta: $($_.FileName)")
                }
            } catch {}
        }
    }
    if ($badProcs) {
        foreach ($proc in $badProcs) {
            $hallazgos.Add("[PROCESO EXTERNO - TE VAS BAN] $($proc.Name).exe (PID: $($proc.Id)) | Ruta: Memoria (Activo)")
        }
    }

    Write-Host "`n       [ ❖ ] ANÁLISIS DE CARPETA DE MODS (.JAR)" -ForegroundColor Cyan
    if (Test-Path $script:DefaultModsPath) {
        $modFiles = Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar", "*.zip", "*.dll"
        foreach ($mod in $modFiles) {
            $isBad = $false
            if ($script:RxHacks.IsMatch($mod.Name)) { $isBad = $true }
            if ($mod.LastWriteTime -gt $mod.CreationTime.AddDays(7)) { $isBad = $true }
            if ($mod.Length -lt 15KB) { $isBad = $true }
            if ($isBad) {
                $hallazgos.Add("[MOD ILEGAL - TE VAS BAN] $($mod.Name) | Ruta: $($mod.FullName)")
            } else {
                $hallazgos.Add("[MOD APROBADO] $($mod.Name) | Ruta: $($mod.FullName)")
            }
        }
    }

    Show-DetectionBox -Detections $hallazgos -Title "RESULTADOS DE ALERTAS DE AUDITORÍA"
    Pause-Scanner
}


# ------------------------------------------------------------
# EASTER EGG: EL DOXEO TROLL MEJORADO (BSOD CAT)
# ------------------------------------------------------------
function Invoke-Screamer {
    $origBG = $Host.UI.RawUI.BackgroundColor
    $origFG = $Host.UI.RawUI.ForegroundColor

    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    Clear-Host

    Write-Host "`n       [!] ADVERTENCIA: INICIANDO VULNERACIÓN DE SISTEMA..." -ForegroundColor Red
    Start-Sleep -Seconds 1

    # Animación Matrix / Brute Force
    Write-Host "`n       [❖] BRUTEFORCING KERNEL HASH..." -ForegroundColor Yellow
    for ($i=0; $i -lt 30; $i++) {
        $hash = -join ((33..126) | Get-Random -Count 64 | % {[char]$_})
        Write-Host "`r       [HASH] $hash" -NoNewline -ForegroundColor DarkGreen
        Start-Sleep -Milliseconds 40
    }
    Write-Host "`r       [HASH] 0xEF92A4C2B91100DF8A91B4C9A0F22A1 -> MATCH!                                    " -ForegroundColor Green
    Start-Sleep -Milliseconds 500

    Write-Host "       [+] Bypass de firewall y Windows Defender completado..." -ForegroundColor Green
    Start-Sleep -Milliseconds 600

    # 1. CUADRO INFORMACIÓN IP
    $uName = $env:USERNAME
    if ($uName.Length -gt 25) { $uName = $uName.Substring(0, 22) + "..." }
    $fakeIP = "192.168.$((Get-Random -Min 0 -Max 255)).$((Get-Random -Min 2 -Max 254))"
    $mac = "{0:X2}-{1:X2}-{2:X2}-{3:X2}-{4:X2}-{5:X2}" -f (Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256)

    Write-Host "`n       ╔════ [ INFORMACIÓN IP EXTRAÍDA Y COMPROMETIDA ] ═══════════════════════╗" -ForegroundColor Cyan
    Write-Host ("       ║ > USUARIO : " + $uName).PadRight(71) + "║" -ForegroundColor Green
    Write-Host ("       ║ > IPV4    : " + $fakeIP).PadRight(71) + "║" -ForegroundColor Green
    Write-Host ("       ║ > MAC     : " + $mac).PadRight(71) + "║" -ForegroundColor Green
    Write-Host ("       ║ > ESTADO  : TOMANDO CONTROL DE LA MÁQUINA...").PadRight(71) + "║" -ForegroundColor Red
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    Start-Sleep -Seconds 1

    # 2. CUADRO HACKEANDO Y BORRANDO (CÓDIGO BINARIO)
    Write-Host "`n       ╔════ [ HACKEANDO Y BORRANDO SISTEMA ] ═════════════════════════════════╗" -ForegroundColor Red
    for ($i = 0; $i -lt 35; $i++) {
        $binLine = -join ((1..35) | ForEach-Object { Get-Random -Min 0 -Max 2 })
        $binStr = $binLine -replace '0','0 ' -replace '1','1 '
        Write-Host ("       ║ " + $binStr.PadRight(70) + "║") -ForegroundColor DarkGreen
        
        if ($i % 3 -eq 0) {
            $fakeFiles = @("hal.dll", "ntoskrnl.exe", "bootmgr", "winload.efi", "explorer.exe", "cmd.exe", "winlogon.exe", "lsass.exe", "svchost.exe", "kernel32.dll")
            $f = $fakeFiles | Get-Random
            $delStr = " [!] DELETING C:\Windows\System32\$f ... OK"
            Write-Host ("       ║" + $delStr.PadRight(71) + "║") -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 50
    }
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red

    Start-Sleep -Seconds 1

    # 3. PANTALLAZO AZUL (BSOD) CON EL GATITO
    $Host.UI.RawUI.BackgroundColor = "Blue"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host

    try { [console]::Beep(800, 400); [console]::Beep(600, 600) } catch {}

    Write-Host @"

                   .-----------------------------.
                  (  adios pc hora pantalla azul  )
                   `-----------------------.-----'
                                          o
                                           o
                                             /\_/\  
                                            ( o.o ) 
                                             > ^ <

    A problem has been detected and Windows has been shut down to prevent damage
    to your computer.

    CRITICAL_PROCESS_DIED
    
    If this is the first time you've seen this Stop error screen,
    restart your computer. If this screen appears again, follow
    these steps:
    
    Check to make sure any new hardware or software is properly installed.
    If this is a new installation, ask your hardware or software manufacturer
    for any Windows updates you might need.

    *** STOP: 0x000000EF (0x00000000, 0x00000000, 0x00000000, 0x00000000)

"@ -ForegroundColor White

    Start-Sleep -Seconds 5

    # Regreso a la normalidad
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    Clear-Host
    Write-Host "`n       [+] Es una broma. Ningún dato fue robado ni borrado. Relájate ;)`n" -ForegroundColor Green
    
    $Host.UI.RawUI.BackgroundColor = $origBG
    $Host.UI.RawUI.ForegroundColor = $origFG
    Pause-Scanner
}

function Show-WindowsServices {
    Clear-Host
    Show-Header "ESTADO DE SERVICIOS WINDOWS"
    
    $hallazgosSvc = [System.Collections.Generic.List[string]]::new()
    foreach ($service in $script:WindowsServices) {
        $output = @(& sc.exe query $service 2>&1) -join "`n"
        if ($output -match 'STOPPED' -and ($service -eq "pcasvc" -or $service -eq "bam" -or $service -eq "sysmain")) {
            $hallazgosSvc.Add("[PELIGRO] SERVICIO APAGADO CRÍTICO: $service | Ruta: N/A")
        } else {
            $hallazgosSvc.Add("[NORMAL] SERVICIO ACTIVO: $service | Ruta: N/A")
        }
    }
    Show-DetectionBox -Detections $hallazgosSvc -Title "RESULTADOS DE ALERTAS DE AUDITORÍA"
    Pause-Scanner
}

function Start-WinRCommands {
    Clear-Host
    Show-Header "RUTAS DE ANÁLISIS MANUAL (WIN + R)"
    $rutas = @(
        [PSCustomObject]@{ Id=1; Cmd="C:\`$Recycle.bin"; Desc="Papelera" },
        [PSCustomObject]@{ Id=2; Cmd="regedit"; Desc="Registro" },
        [PSCustomObject]@{ Id=3; Cmd="C:\Windows\Prefetch"; Desc="Prefetch" },
        [PSCustomObject]@{ Id=4; Cmd="cmd.exe"; Desc="Consola CMD" }
    )
    Write-Host "       [ ❖ ] ACCESOS DIRECTOS DEL SISTEMA" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($r in $rutas) { Write-Host "       [ $($r.Id) ] $($r.Cmd)  ➜  $($r.Desc)" -ForegroundColor Yellow }
    $choice = (Read-Host "`n       [COMANDO] Ingresa el ID para abrir (o 0 para salir)").Trim()
    if ($choice -ne "0") {
        $sel = $rutas | Where-Object { $_.Id.ToString() -eq $choice }
        if ($sel) {
            if ($sel.Cmd -eq "regedit") {
                Start-Process "regedit"
            } elseif ($sel.Cmd -eq "cmd.exe") {
                Start-Process "cmd.exe"
            } else {
                Start-Process "explorer.exe" $sel.Cmd
            }
        }
    }
}

function Start-DiffKiller {
    Clear-Host
    Show-Header "FINALIZADOR DE PROCESOS OCULTOS (DIFF)"
    $forbidden = @("obs","obs32","obs64","discord","streamlabs","bandicam","sharex","gamebar")
    $detected = @()
    Write-Host "       [ ❖ ] BUSCANDO APLICACIONES DE CAPTURA EN SEGUNDO PLANO..." -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        if ($forbidden -contains $proc.Name.ToLower()) { 
            $detected += $proc.Name
            Write-Host "       [!] Proceso detectado: $($proc.Name)" -ForegroundColor Yellow 
        }
    }
    if ($detected.Count -gt 0) {
        $ans = (Read-Host "`n       [?] ¿Deseas forzar el cierre de todas estas aplicaciones? (S/N)").ToUpper()
        if ($ans -eq "S") {
            foreach ($name in $detected) { Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force }
            Write-Host "       [+] Procesos finalizados con éxito." -ForegroundColor Green
        }
    } else {
        Write-Host "       [+] No se encontraron aplicaciones de grabación ocultas." -ForegroundColor Green
    }
    Pause-Scanner
}


# ============================================================
# MENÚ PRINCIPAL Y LÓGICA DE DIBUJO CON LA MONA CHINA
# ============================================================
function Show-MainMenu {

    if ($script:FirstRun) {
        Show-BootAnimation
        $script:FirstRun = $false
    }

    $sideGirl = @(
        "                                                     .::---:               ::"
        "                                                    =-..-::-*=            -+.   -+-"
        "                                                   -: =.     :+          :=+   ==="
        "                                                  :+ .*       =:        ===-::.==."
        "                                                   -: +                :. ..:. -.=.     .."
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

    while ($true) {
        try {
            Clear-Host
            Show-Banner
            $menuLines = @(
                "       ╔═══════════════════════════════════════════════════════════════════════╗"
                "       ║                  [ MODULO CENTRAL DE INTERVENCION ]                   ║"
                "       ╚═══════════════════════════════════════════════════════════════════════╝"
                "                                                                                "
                "       [  1  ] Escaneo Global (ONE-CLICK) [  9  ] Hub Herramientas SS       "
                "       [  2  ] Analizar Mods              [ 10  ] Hub Payloads (GitHub)     "
                "       [  3  ] Doomsday Detector          [ 11  ] Análisis Completo Disco   "
                "       [  4  ] Análisis Prefetch/BAM      [ 12  ] Rutas Manuales (Win+R)    "
                "       [  5  ] Análisis Papelera          [ 13  ] Mod & Instancia Extreme   "
                "       [  6  ] Macros & Autoclick (ALL)   [ 14  ] ⚠ NO TOCAR ⚠             "
                "       [  7  ] Killer Screen (Diff)       [ 15  ] Salir de Framework        "
                "       [  8  ] Servicios Windows                                            "
                "                                                                                "
                "       ─────────────────────────────────────────────────────────────────────────"
            )

            $leftWidth = 83
            $gap = " "
            $totalLines = [math]::Max($menuLines.Count, $sideGirl.Count)

            for ($i = 0; $i -lt $totalLines; $i++) {
                
                # Imprimir parte izquierda (Menú principal) en Ciber-Neón
                if ($i -lt $menuLines.Count) {
                    $left = $menuLines[$i]
                    if ($left -match "╔|║|╚|╠|═|─") {
                        Write-Host $left.PadRight($leftWidth) -NoNewline -ForegroundColor DarkCyan
                    } elseif ($left -match "⚠ NO TOCAR ⚠") {
                        Write-Host $left.PadRight($leftWidth) -NoNewline -ForegroundColor Red
                    } else {
                        Write-Host $left.PadRight($leftWidth) -NoNewline -ForegroundColor Cyan
                    }
                } else {
                    Write-Host (" " * $leftWidth) -NoNewline
                }
                
                Write-Host $gap -NoNewline

                # Imprimir parte derecha (La Mona China)
                if ($i -lt $sideGirl.Count) {
                    $girlLine = $sideGirl[$i].TrimEnd()
                    if ($i -ge 12 -and $i -le 24) { Write-Host $girlLine -ForegroundColor DarkCyan } 
                    elseif ($i -gt 24 -and $i -le 48) { Write-Host $girlLine -ForegroundColor Cyan } 
                    else { Write-Host $girlLine -ForegroundColor DarkMagenta }
                } else { Write-Host "" }
            }
            Write-Host ""
            $option = (Read-Host "       [ROOT] Selecciona un módulo [1-15]").Trim()

            switch ($option) {
                "1"  { Start-GlobalScan }
                "01" { Start-GlobalScan }
                "2"  { Start-SafeRemote -Url "https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1" -Title "ANÁLISIS AVANZADO DE MODS (MEOW)" }
                "02" { Start-SafeRemote -Url "https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1" -Title "ANÁLISIS AVANZADO DE MODS (MEOW)" }
                "3"  { Start-SafeRemote -Url "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1" -Title "DETECCIÓN PROFUNDA (DOOMSDAY)" }
                "03" { Start-SafeRemote -Url "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1" -Title "DETECCIÓN PROFUNDA (DOOMSDAY)" }
                "4"  { Start-SystemScan }
                "04" { Start-SystemScan }
                "5"  { Start-RecycleBinScan }
                "05" { Start-RecycleBinScan }
                "6"  { Start-MacroAutoclickScan }
                "06" { Start-MacroAutoclickScan }
                "7"  { Start-DiffKiller }
                "07" { Start-DiffKiller }
                "8"  { Show-WindowsServices }
                "08" { Show-WindowsServices }
                "9"  { Start-SSToolsHub }
                "09" { Start-SSToolsHub }
                "10" { Start-RemoteScript }
                "11" { Start-FullDiskScan }
                "12" { Start-WinRCommands }
                "13" { Start-ExtremeModScan }
                "14" { Invoke-Screamer }
                "15" { 
                    Clear-Host
                    Invoke-Typewriter "`n       [!] APAGANDO SISTEMA. HASTA LUEGO, JOAQUÍN.`n" -Color Red
                    return 
                }
                default { 
                    Write-Host "`n       [!] Entrada no reconocida en el sistema." -ForegroundColor Red
                    Start-Sleep -Seconds 1 
                }
            }
        }
        catch {
            # Este bloque ya casi nunca se activará porque los errores externos se bloquean en Start-SafeRemote
            Write-Host "`n       [!] Interrupción detectada. Forzando reinicio de interfaz." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}

# ============================================================
# INICIO
# ============================================================
$script:IsAdmin = Test-Administrator
Show-MainMenu
