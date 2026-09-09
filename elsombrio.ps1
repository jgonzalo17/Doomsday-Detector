#Requires -Version 5.1
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V55 - VIRUS INJECTION UI)
# ============================================================

$script:DefaultModsPath = "$env:APPDATA\.minecraft\mods"
$script:FirstRun = $true
$script:BoxW = 95 # Ancho global de la interfaz

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
# LISTAS Y REGEX OPTIMIZADOS
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
$script:PathWhitelistPatterns = "site-packages|dist-packages|\\lib\\python|\\Lib\\|\\venv\\|\\\.venv\\|\\conda\\|node_modules|\\Scripts\\|pydevd"

$script:RxOpts = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled'
$script:RxHacks           = [regex]::new($script:RegexHacks, $script:RxOpts)
$script:RxMacroCritical   = [regex]::new($script:RegexMacroCritical, $script:RxOpts)
$script:RxPathWhitelist   = [regex]::new($script:PathWhitelistPatterns, $script:RxOpts)
$script:RxMcProcess       = [regex]::new("java|javaw|lunarclient|craft", $script:RxOpts)

$script:WindowsServices = @("dps", "appinfo", "pcasvc", "eventlog", "sysmain", "dusmsvc", "bam")

# ============================================================
# MOTOR DECOMPRESSOR SEGURO
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
# INTERFAZ GRÁFICA CORE
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
        Write-Host "`n`n`n`n`n"
        Write-Host "                                   |\__/,|   (`\ " -ForegroundColor Cyan
        Write-Host "                                 _.|o o  |_   ) ) " -ForegroundColor Cyan
        Write-Host "                                -(((---(((-------- " -ForegroundColor Cyan
        
        $stepIndex = [math]::Min([math]::Floor($i / 3), $bootSteps.Count - 1)
        Write-Host "`n       [Bootloader] $($bootSteps[$stepIndex])" -ForegroundColor DarkGray
        
        $pct = [math]::Round((($i + 1) / 15) * 100)
        $barLength = 50
        $filled = [math]::Round(($pct / 100) * $barLength)
        $empty = $barLength - $filled
        $progressBar = "█" * $filled + "▒" * $empty
        
        Write-Host "       [System]     $pct% [$progressBar]" -ForegroundColor Magenta
        Start-Sleep -Milliseconds 120
    }
    Write-Host "`n       [OK] INTERFAZ LISTA. SISTEMA FORENSE OPERATIVO.`n" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
}

function Show-Banner {
    Clear-Host
    Write-Host "`n`n"
    $banner = @"
                                   |\__/,|   (`\
                                 _.|o o  |_   ) )
                                -(((---(((--------

              ███████╗ ██████╗ ███╗   ███╗██████╗ ██████╗ ██╗ ██████╗
              ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║██╔═══██╗
              ███████╗██║   ██║██╔████╔██║██████╔╝██████╔╝██║██║   ██║
              ╚════██║██║   ██║██║╚██╔╝██║██╔══██╗██╔══██╗██║██║   ██║
              ███████║╚██████╔╝██║ ╚═╝ ██║██████╔╝██║  ██║██║╚██████╔╝
              ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝
"@
    Write-Host $banner -ForegroundColor Cyan
    $pad = [math]::Max(0, [math]::Floor(($script:BoxW - 41) / 2))
    $str = ((' ' * $pad) + "[ ADVANCED FORENSIC SCANNER - WIDESCREEN UI ]").PadRight($script:BoxW, ' ')
    Write-Host "       $str`n" -ForegroundColor Magenta
}

function Show-Header {
    param([string]$Subtitle)
    Write-Host "`n`n`n       ╔$($("═" * $script:BoxW))╗" -ForegroundColor DarkCyan
    $titlePad = [math]::Max(0, [math]::Floor(($script:BoxW - 38) / 2))
    $titleStr = ((' ' * $titlePad) + "EL SOMBRIO IF - FORENSIC SCANNER").PadRight($script:BoxW, ' ')
    Write-Host "       ║$titleStr║" -ForegroundColor Cyan
    Write-Host "       ╠$($("═" * $script:BoxW))╣" -ForegroundColor DarkCyan
    $subPad = [math]::Max(0, [math]::Floor(($script:BoxW - $Subtitle.Length) / 2))
    $subStr = ((' ' * $subPad) + $Subtitle).PadRight($script:BoxW, ' ')
    Write-Host "       ║$subStr║" -ForegroundColor White
    Write-Host "       ╚$($("═" * $script:BoxW))╝`n" -ForegroundColor DarkCyan
}

function Pause-Scanner {
    Write-Host "`n       $($("─" * $script:BoxW))" -ForegroundColor DarkGray
    Invoke-Typewriter "       [ Presiona CUALQUIER TECLA para regresar al menú principal ]" -Speed 10 -Color Magenta
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { $null = Read-Host }
}

function Show-DetectionBox {
    param([array]$Detections, [string]$Title)
    
    Clear-Host
    Show-Header "REPORTE DE AUDITORÍA"
    $cW = [math]::Floor(($script:BoxW - 1) / 2) 

    $borderColor = if ($Detections | Where-Object { $_ -match "HACK|TE VAS BAN|ILEGAL|PELIGRO" }) { "Red" } else { "DarkGray" }

    Write-Host "       ╔$($("═" * $cW))╦$($("═" * $cW))╗" -ForegroundColor Cyan
    Write-Host "       ║$($(" ALERTA / DETECCIÓN".PadRight($cW, ' ')))║$($(" RUTA / DETALLES".PadRight($cW, ' ')))║" -ForegroundColor Yellow
    Write-Host "       ╠$($("═" * $cW))╬$($("═" * $cW))╣" -ForegroundColor Cyan
    
    if ($Detections.Count -eq 0) {
        Write-Host "       ║$($(" Ninguna anomalía detectada.".PadRight($cW, ' ')))║$($(" ---".PadRight($cW, ' ')))║" -ForegroundColor Green
    } else {
        foreach ($item in $Detections) {
            $item = [string]$item
            $leftText = $item
            $rightText = "---"
            
            $idx = $item.IndexOf(" | Ruta: ")
            if ($idx -ge 0) {
                $leftText = $item.Substring(0, $idx).Trim()
                $rightText = $item.Substring($idx + 9).Trim()
            }

            $color = "Yellow"
            if ($leftText -match "HACK|TE VAS BAN|ILEGAL|PELIGRO") { $color = "Red" }
            elseif ($leftText -match "\[JAVA\]|java\.exe|javaw\.exe|lunarclient") { $color = "Cyan" }
            elseif ($leftText -match "======") { $color = "Magenta" }
            elseif ($leftText -match "\[NORMAL\]|\[ELIMINADO\]|APROBADO") { $color = "Green" }

            if ($leftText -match "======") {
                $strL = " " + $leftText; $strR = ""
            } else {
                $strL = "> " + $leftText; $strR = $rightText
            }

            if ($strL.Length -gt $cW) { $strL = $strL.Substring(0, $cW - 3) + "..." }
            if ($strR.Length -gt $cW) { $strR = $strR.Substring(0, $cW - 3) + "..." }
            
            $lPad = $strL.PadRight($cW, ' ')
            $rPad = $strR.PadRight($cW, ' ')

            Write-Host "       ║" -NoNewline -ForegroundColor Cyan
            Write-Host $lPad -NoNewline -ForegroundColor $color
            Write-Host "║" -NoNewline -ForegroundColor Cyan
            Write-Host $rPad -NoNewline -ForegroundColor $color
            Write-Host "║" -ForegroundColor Cyan
        }
    }
    Write-Host "       ╚$($("═" * $cW))╩$($("═" * $cW))╝" -ForegroundColor Cyan
    
    if ($Detections.Count -gt 0) {
        Write-Host "`n       [ ❖ ] LOG COMPLETO DE RUTAS DETECTADAS (POR SI SE RECORTARON):" -ForegroundColor Cyan
        Write-Host "       $($("─" * $script:BoxW))" -ForegroundColor DarkGray
        foreach ($item in $Detections) { 
            if ($item -notmatch "======") {
                $textColor = "Gray"
                if ($item -match "HACK|TE VAS BAN|ILEGAL|PELIGRO") { $textColor = "Red" }
                elseif ($item -match "\[JAVA\]") { $textColor = "Cyan" }
                elseif ($item -match "\[NORMAL\]|\[ELIMINADO\]|APROBADO") { $textColor = "Green" }
                Write-Host "       -> $item" -ForegroundColor $textColor 
            }
        }
    }
}

function Test-Administrator { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

# ============================================================
# AISLAMIENTO DE SCRIPTS EXTERNOS (ANTI-CRASHEO MEJORADO)
# ============================================================
function Start-SafeRemote {
    param([string]$Url, [string]$Title)
    Clear-Host
    Show-Header $Title
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    
    Write-Host "       [ ❖ ] CONECTANDO Y LANZANDO MÓDULO AISLADO..." -ForegroundColor Cyan
    Write-Host "       $($("─" * $script:BoxW))" -ForegroundColor DarkGray
    Write-Host "       [*] La herramienta se ejecutará en una NUEVA VENTANA." -ForegroundColor Gray
    Write-Host "       [*] La ventana NO se cerrará sola. Ciérrala manualmente (en la 'X') cuando termines de leer.`n" -ForegroundColor Magenta
    
    try {
        $cmd = "irm '$Url' | iex"
        Start-Process powershell.exe -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -Wait
    } catch {
        Write-Host "`n       [!] Error al invocar la ventana externa: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n       [+] Ventana externa cerrada. Regresando al núcleo..." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

# ============================================================
# MÓDULOS DE ESCANEO UNIFICADOS
# ============================================================

# [OPCIÓN 1] GLOBAL SCAN
function Start-GlobalScan {
    Clear-Host
    Show-Header "ESCANEO GLOBAL DEL SISTEMA (ONE-CLICK)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    
    $hallazgosGlobales = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] INICIANDO AUDITORÍA GLOBAL. POR FAVOR ESPERA..." -ForegroundColor Cyan
    Write-Host "       $($("─" * $script:BoxW))" -ForegroundColor DarkGray

    Write-Host "       [*] 1/6 Analizando Memoria RAM e Instancias..." -ForegroundColor White
    $allProcs = Get-Process -ErrorAction SilentlyContinue
    $mcProcs = $allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) }
    $badProcs = $allProcs | Where-Object { $script:RxHacks.IsMatch($_.Name) }
    
    if ($mcProcs) {
        foreach ($proc in $mcProcs) {
            $hallazgosGlobales.Add("[JAVA] INSTANCIA ACTIVA : $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
            try {
                $proc.Modules | Where-Object { $script:RxHacks.IsMatch($_.FileName) } | ForEach-Object {
                    $hallazgosGlobales.Add("[INYECCIÓN EN RAM - TE VAS BAN] $($_.ModuleName) | Ruta: $($_.FileName)")
                }
            } catch {}
        }
    }
    if ($badProcs) {
        foreach ($proc in $badProcs) {
            $hallazgosGlobales.Add("[PROCESO HACK - TE VAS BAN] $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
        }
    }

    Write-Host "       [*] 2/6 Extrayendo historial de Prefetch..." -ForegroundColor White
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
    if ($pfFiles) {
        $hace2 = (Get-Date).Date.AddDays(-2)
        $validFiles = $pfFiles | Where-Object { $_.LastWriteTime.Date -ge $hace2 }
        foreach ($item in $validFiles) {
            if ($script:RxHacks.IsMatch($item.Name)) {
                $hallazgosGlobales.Add("[PREFETCH HACK - TE VAS BAN] $($item.Name) | Ruta: C:\Windows\Prefetch")
            }
        }
    }

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

    Write-Host "       [*] 6/6 Evaluando Servicios Base de Windows..." -ForegroundColor White
    foreach ($service in @("pcasvc", "bam", "sysmain")) {
        $output = @(& sc.exe query $service 2>&1) -join "`n"
        if ($output -match 'STOPPED') {
            $hallazgosGlobales.Add("[PELIGRO] SERVICIO APAGADO CRÍTICO: $service | Ruta: Sistema Operativo")
        }
    }

    Start-Sleep -Seconds 1
    Show-DetectionBox -Detections $hallazgosGlobales -Title "ALERTAS GLOBALES (MODS, RAM, DISCO)"
    Pause-Scanner
}

# [OPCIÓN 2] UNIFIED MODS
function Start-UnifiedModScan {
    Clear-Host
    Show-Header "AUDITORÍA DE MODS E INSTANCIAS (LOCAL Y NUBE)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] 1. VERIFICANDO MEMORIA RAM EN TIEMPO REAL..." -ForegroundColor Cyan
    $allProcs = Get-Process -ErrorAction SilentlyContinue
    $mcProcs = $allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) }
    if ($mcProcs) {
        foreach ($proc in $mcProcs) {
            $hallazgos.Add("[JAVA] INSTANCIA ACTIVA : $($proc.Name).exe | Ruta: PID $($proc.Id)")
            try {
                $proc.Modules | Where-Object { $script:RxHacks.IsMatch($_.FileName) } | ForEach-Object {
                    $hallazgos.Add("[INYECCIÓN EN RAM - TE VAS BAN] $($_.ModuleName) | Ruta: $($_.FileName)")
                }
            } catch {}
        }
    }

    Write-Host "       [ ❖ ] 2. ANALIZANDO CARPETA DE MODS (.JAR)..." -ForegroundColor Cyan
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
                $hallazgos.Add("[MOD APROBADO] $($mod.Name) | Ruta: OK")
            }
        }
    }

    Write-Host "       [ ❖ ] 3. BUSCANDO MODS ELIMINADOS EN LA PAPELERA..." -ForegroundColor Cyan
    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        foreach ($item in $papelera.Items()) {
            if ($script:RxHacks.IsMatch($item.Name)) {
                $hallazgos.Add("[PAPELERA HACK - TE VAS BAN] $($item.Name) | Ruta: $($item.Path)")
            }
        }
    } catch {}

    Show-DetectionBox -Detections $hallazgos -Title "RESULTADOS DE MODS LOCALES"
    
    Write-Host ""
    $ans = [string](Read-Host "       [?] ¿Deseas lanzar el escaneo profundo en la NUBE (Meow Analyzer)? (S/N)")
    if ($ans.ToUpper() -eq "S") {
        Start-SafeRemote -Url "https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1" -Title "MEOW MOD ANALYZER (NUBE)"
    } else {
        Pause-Scanner
    }
}

# [OPCIÓN 4] UNIFIED TRACES (PREFETCH + PAPELERA + DISCO)
function Start-TraceScan {
    Clear-Host
    Show-Header "ANÁLISIS DE RASTROS (PREFETCH, PAPELERA Y DISCO)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    $sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    
    Write-Host "       [ ❖ ] 1. HISTORIAL DE PREFETCH (ÚLTIMOS 3 DÍAS)..." -ForegroundColor Cyan
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
    if ($pfFiles) {
        $hoy = (Get-Date).Date; $ayer = $hoy.AddDays(-1); $hace2 = $hoy.AddDays(-2)
        $validFiles = $pfFiles | Where-Object { $_.LastWriteTime.Date -ge $hace2 } | Sort-Object LastWriteTime -Descending
        
        function Add-Group($group, $title) {
            if ($group -and $group.Count -gt 0) {
                $hallazgos.Add("====== $title ======")
                foreach ($item in $group) {
                    $t = $item.LastWriteTime.ToString("HH:mm:ss")
                    if ($script:RxHacks.IsMatch($item.Name)) { $hallazgos.Add("[HACK - TE VAS BAN] $($item.Name) | Ruta: Ejecutado a las $t") } 
                    elseif ($script:RxMcProcess.IsMatch($item.Name)) { $hallazgos.Add("[JAVA] $($item.Name) | Ruta: Ejecutado a las $t") } 
                }
            }
        }
        Add-Group ($validFiles | Where-Object { $_.LastWriteTime.Date -eq $hoy }) "PREFETCH HOY"
        Add-Group ($validFiles | Where-Object { $_.LastWriteTime.Date -eq $ayer }) "PREFETCH AYER"
        Add-Group ($validFiles | Where-Object { $_.LastWriteTime.Date -eq $hace2 }) "PREFETCH HACE DOS DÍAS"
    }
    
    Write-Host "       [ ❖ ] 2. PAPELERA DE RECICLAJE (TODOS LOS DISCOS)..." -ForegroundColor Cyan
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    $hallazgos.Add("====== PAPELERA DE RECICLAJE ======")
    foreach ($drive in $drives) {
        $recPath = "$drive`$Recycle.Bin\$sid"
        if (Test-Path $recPath) {
            Get-ChildItem -Path $recPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($script:RxHacks.IsMatch($_.Name)) {
                    $hallazgos.Add("[HACK BORRADO - TE VAS BAN] $($_.Name) | Ruta: $($_.FullName)")
                }
            }
        }
    }

    Write-Host "       [ ❖ ] 3. ARCHIVOS MODIFICADOS RECIENTEMENTE (C:\Users)..." -ForegroundColor Cyan
    $hallazgos.Add("====== ARCHIVOS MODIFICADOS EN DISCO ======")
    Get-ChildItem -Path "C:\Users" -Recurse -File -Include "*.jar","*.exe","*.bat" -ErrorAction SilentlyContinue | 
    Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-2) -and $script:RxHacks.IsMatch($_.Name) } | ForEach-Object {
        $hallazgos.Add("[MODIFICADO HACK - TE VAS BAN] $($_.Name) | Ruta: $($_.FullName)")
    }
    
    Show-DetectionBox -Detections $hallazgos -Title "RESULTADO DE RASTROS (PREFETCH, PAPELERA Y DISCO)"
    Pause-Scanner
}

# [OPCIÓN 5] UNIFIED MACRO/AUTOCLICK SCAN
function Start-MacroAutoclickScan {
    Clear-Host
    Show-Header "BÚSQUEDA DE MACROS Y AUTOCLICKERS"
    $hallazgos = [System.Collections.Generic.List[string]]::new()

    Write-Host "       [ ❖ ] FASE 1: PROCESOS ACTIVOS EN MEMORIA" -ForegroundColor Cyan
    $activeProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) }
    if ($activeProcs) {
        foreach ($proc in $activeProcs) {
            $hallazgos.Add("[PROCESO ACTIVO - TE VAS BAN] $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
        }
    }

    Write-Host "       [ ❖ ] FASE 2: ESCANEO PROFUNDO DE DISCO" -ForegroundColor Cyan
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
    
    Show-DetectionBox -Detections $hallazgos -Title "RESULTADOS: MACROS Y AUTOCLICKERS"
    Pause-Scanner
}

# [OPCIÓN 6] UNIFIED SYSTEM MAINTENANCE (DIFF + SERVICES)
function Start-SysMaintenance {
    Clear-Host
    Show-Header "UTILIDADES DEL SISTEMA (PROCESOS Y SERVICIOS)"
    
    Write-Host "       [ ❖ ] FINALIZADOR DE PROCESOS DE CAPTURA OCULTOS" -ForegroundColor Cyan
    $forbidden = @("obs","obs32","obs64","discord","streamlabs","bandicam","sharex","gamebar")
    $detected = @()
    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        if ($forbidden -contains $proc.Name.ToLower()) { 
            $detected += $proc.Name
            Write-Host "       [!] Proceso detectado: $($proc.Name)" -ForegroundColor Yellow 
        }
    }
    if ($detected.Count -gt 0) {
        $ans = [string](Read-Host "`n       [?] ¿Deseas forzar el cierre de todas estas aplicaciones? (S/N)")
        if ($ans.ToUpper() -eq "S") {
            foreach ($name in $detected) { Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force }
            Write-Host "       [+] Procesos finalizados con éxito." -ForegroundColor Green
        }
    } else {
        Write-Host "       [+] No se encontraron aplicaciones de grabación ocultas." -ForegroundColor Green
    }

    Write-Host "`n       [ ❖ ] ESTADO DE SERVICIOS WINDOWS CRÍTICOS" -ForegroundColor Cyan
    $hallazgosSvc = [System.Collections.Generic.List[string]]::new()
    foreach ($service in $script:WindowsServices) {
        $output = @(& sc.exe query $service 2>&1) -join "`n"
        if ($output -match 'STOPPED' -and ($service -eq "pcasvc" -or $service -eq "bam" -or $service -eq "sysmain")) {
            $hallazgosSvc.Add("[PELIGRO] SERVICIO APAGADO CRÍTICO: $service | Ruta: Sistema Operativo")
        } else {
            $hallazgosSvc.Add("[NORMAL] SERVICIO ACTIVO: $service | Ruta: OK")
        }
    }
    Show-DetectionBox -Detections $hallazgosSvc -Title "ESTADO DE SERVICIOS DE WINDOWS"
    Pause-Scanner
}

# [OPCIÓN 7] UNIFIED HUBS (TOOLS, PAYLOADS, WIN+R)
function Start-Hubs {
    Clear-Host
    Show-Header "HUB DE HERRAMIENTAS Y PAYLOADS"
    
    Write-Host "       [ ❖ ] HERRAMIENTAS SS Y PAYLOADS GITHUB" -ForegroundColor Cyan
    $tools = @(
        [PSCustomObject]@{ Id=1; Name="System Informer"; Type="EXE"; Url="https://sourceforge.net/projects/systeminformer/files/latest/download" }
        [PSCustomObject]@{ Id=2; Name="JournalTrace"; Type="EXE"; Url="https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe" }
        [PSCustomObject]@{ Id=3; Name="Lilith Services (Payload)"; Type="PS1"; Url="https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1" }
        [PSCustomObject]@{ Id=4; Name="Ordiff Kill ScreenRec (Payload)"; Type="PS1"; Url="https://raw.githubusercontent.com/Orbdiff/powershell/refs/heads/main/kill-screen-processes.ps1" }
        [PSCustomObject]@{ Id=5; Name="Carpeta Papelera Oculta"; Type="WIN"; Cmd="C:\`$Recycle.bin" }
        [PSCustomObject]@{ Id=6; Name="Editor de Registro (Regedit)"; Type="WIN"; Cmd="regedit" }
        [PSCustomObject]@{ Id=7; Name="Carpeta Prefetch"; Type="WIN"; Cmd="C:\Windows\Prefetch" }
    )
    
    foreach ($t in $tools) { Write-Host ("       [ {0} ] {1,-35} ({2})" -f $t.Id, $t.Name, $t.Type) -ForegroundColor White }
    
    $choice = [string](Read-Host "`n       [COMANDO] Ingresa el ID para ejecutar (o 0 para salir)")
    if ($choice -ne "0" -and ($tools | Where-Object { $_.Id.ToString() -eq $choice.Trim() })) {
        $sel = $tools | Where-Object { $_.Id.ToString() -eq $choice.Trim() }
        Write-Host "       [*] Ejecutando $($sel.Name)..." -ForegroundColor Yellow
        
        if ($sel.Type -eq "EXE") {
            try {
                $out = "$env:TEMP\$(($sel.Name -replace '\s','_')).exe"
                Invoke-WebRequest -Uri $sel.Url -OutFile $out -UseBasicParsing -TimeoutSec 15
                Start-Process $out -Wait
            } catch { Start-Process $sel.Url }
        } elseif ($sel.Type -eq "PS1") {
            try {
                Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
                & ([ScriptBlock]::Create((Invoke-RestMethod -Uri $sel.Url -UseBasicParsing)))
            } catch { Write-Host "       [!] Error: $($_.Exception.Message)" -ForegroundColor Red }
        } elseif ($sel.Type -eq "WIN") {
            if ($sel.Cmd -eq "regedit") { Start-Process "regedit" } else { Start-Process "explorer.exe" $sel.Cmd }
        }
    }
    Pause-Scanner
}

# ------------------------------------------------------------
# EASTER EGG: EL DOXEO TROLL MEJORADO (VIRUS INJECTION)
# ------------------------------------------------------------
function Invoke-Screamer {
    $origBG = $Host.UI.RawUI.BackgroundColor
    $origFG = $Host.UI.RawUI.ForegroundColor

    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    Clear-Host

    Write-Host "`n       [!] ADVERTENCIA: INICIANDO VULNERACIÓN DE SISTEMA..." -ForegroundColor Red
    Start-Sleep -Seconds 1

    $hackingAscii = @"
       ██╗  ██╗ █████╗  ██████╗██╗  ██╗██╗███╗   ██╗ ██████╗ 
       ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██║████╗  ██║██╔════╝ 
       ███████║███████║██║     █████╔╝ ██║██╔██╗ ██║██║  ███╗
       ██╔══██║██╔══██║██║     ██╔═██╗ ██║██║╚██╗██║██║   ██║
       ██║  ██║██║  ██║╚██████╗██║  ██╗██║██║ ╚████║╚██████╔╝
       ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 
        ██╗   ██╗ ██████╗ ██╗   ██╗██████╗                    
        ╚██╗ ██╔╝██╔═══██╗██║   ██║██╔══██╗                   
         ╚████╔╝ ██║   ██║██║   ██║██████╔╝                   
          ╚██╔╝  ██║   ██║██║   ██║██╔══██╗                   
           ██║   ╚██████╔╝╚██████╔╝██║  ██║                   
           ╚═╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝                   
    ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗   ██╗████████╗███████╗██████╗ 
    ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║   ██║╚══██╔══╝██╔════╝██╔══██╗
    ██║     ██║   ██║██╔████╔██║██████╔╝██║   ██║   ██║   █████╗  ██████╔╝
    ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║   ██║   ██║   ██╔══╝  ██╔══██╗
    ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ╚██████╔╝   ██║   ███████╗██║  ██║
     ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝      ╚═════╝    ╚═╝   ╚══════╝╚═╝  ╚═╝
"@
    Write-Host $hackingAscii -ForegroundColor Red
    Start-Sleep -Seconds 2

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

    $uName = $env:USERNAME
    if ($uName.Length -gt 25) { $uName = $uName.Substring(0, 22) + "..." }
    $fakeIP = "192.168.$((Get-Random -Min 0 -Max 255)).$((Get-Random -Min 2 -Max 254))"
    $mac = "{0:X2}-{1:X2}-{2:X2}-{3:X2}-{4:X2}-{5:X2}" -f (Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256),(Get-Random -Max 256)

    Write-Host "`n       ╔════ [ INFORMACIÓN IP EXTRAÍDA Y COMPROMETIDA ] $($("═" * ($script:BoxW - 57)))╗" -ForegroundColor Cyan
    Write-Host ("       ║ > USUARIO : " + $uName).PadRight($script:BoxW + 7) + "║" -ForegroundColor Green
    Write-Host ("       ║ > IPV4    : " + $fakeIP).PadRight($script:BoxW + 7) + "║" -ForegroundColor Green
    Write-Host ("       ║ > MAC     : " + $mac).PadRight($script:BoxW + 7) + "║" -ForegroundColor Green
    Write-Host ("       ║ > ESTADO  : TOMANDO CONTROL DE LA MÁQUINA...").PadRight($script:BoxW + 7) + "║" -ForegroundColor Red
    Write-Host "       ╚$($("═" * $script:BoxW))╝" -ForegroundColor Cyan

    Start-Sleep -Seconds 1

    Write-Host "`n       ╔════ [ HACKEANDO Y BORRANDO SISTEMA ] $($("═" * ($script:BoxW - 39)))╗" -ForegroundColor Red
    for ($i = 0; $i -lt 35; $i++) {
        $binLine = -join ((1..45) | ForEach-Object { Get-Random -Min 0 -Max 2 })
        $binStr = $binLine -replace '0','0 ' -replace '1','1 '
        Write-Host ("       ║ " + $binStr.PadRight($script:BoxW - 2)) + "║" -ForegroundColor DarkGreen
        
        if ($i % 3 -eq 0) {
            $fakeFiles = @("hal.dll", "ntoskrnl.exe", "bootmgr", "winload.efi", "explorer.exe", "cmd.exe", "winlogon.exe", "lsass.exe", "svchost.exe", "kernel32.dll")
            $f = $fakeFiles | Get-Random
            $delStr = " [!] DELETING C:\Windows\System32\$f ... OK"
            Write-Host ("       ║" + $delStr.PadRight($script:BoxW - 1)) + "║" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 50
    }
    Write-Host "       ╚$($("═" * $script:BoxW))╝" -ForegroundColor Red

    Start-Sleep -Seconds 1

    # NUEVA PANTALLA DE VIRUS CUSTOM (Reemplazo del BSOD)
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Red"
    Clear-Host
    Write-Host "`n`n`n"
    
    try { [console]::Beep(800, 400); [console]::Beep(600, 600) } catch {}

    Write-Host "       ╔════ [ ADVERTENCIA CRÍTICA DEL SISTEMA ] $($("═" * ($script:BoxW - 41)))╗" -ForegroundColor Red
    Write-Host "       ║" -NoNewline; Write-Host " DETECTANDO MÚLTIPLES AMENAZAS EN MEMORIA...".PadRight($script:BoxW) -NoNewline -ForegroundColor Yellow; Write-Host "║" -ForegroundColor Red
    Write-Host "       ╚$($("═" * $script:BoxW))╝" -ForegroundColor Red
    Write-Host ""
    
    for ($i = 1; $i -le 100; $i++) {
        $pct = $i
        $barLength = 40
        $filled = [math]::Round(($pct / 100) * $barLength)
        $pBar = "█" * $filled + "▒" * ($barLength - $filled)
        
        Write-Host "`r       [ INYECTANDO MALWARE ] [$pBar] $pct% (Virus en sistema: $i/100)   " -NoNewline -ForegroundColor Red
        Start-Sleep -Milliseconds 30
    }

    Write-Host "`n`n"
    Write-Host @"
              ███████╗██╗         ███████╗████████╗ ██████╗ ██████╗ 
              ██╔════╝██║         ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
              █████╗  ██║         ███████╗   ██║   ██║   ██║██████╔╝
              ██╔══╝  ██║         ╚════██║   ██║   ██║   ██║██╔═══╝ 
              ███████╗███████╗    ███████║   ██║   ╚██████╔╝██║     
              ╚══════╝╚══════╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
"@ -ForegroundColor DarkRed

    Write-Host "`n       >>> 100 VIRUS HAN ENTRADO A TU PC <<<" -ForegroundColor Red
    Write-Host "       >>> EL SOMBRIO SIEMPRE ATACA <<<" -ForegroundColor DarkRed
    Write-Host "`n       [!] BLOQUEANDO ACCESO A LA INTERFAZ... [!]" -ForegroundColor Red

    Start-Sleep -Seconds 5

    # Regreso a la normalidad
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    Clear-Host
    Write-Host "`n`n`n       [+] Es una broma. Ningún dato fue robado ni infectado. Relájate ;)`n" -ForegroundColor Green
    
    $Host.UI.RawUI.BackgroundColor = $origBG
    $Host.UI.RawUI.ForegroundColor = $origFG
    Pause-Scanner
}

# ============================================================
# MENÚ PRINCIPAL UNIFICADO Y LÓGICA DE DIBUJO
# ============================================================
function Show-MainMenu {

    try {
        if ($Host.UI.RawUI.WindowSize.Width -lt 115) {
            $w = $Host.UI.RawUI.WindowSize
            $w.Width = 115
            $Host.UI.RawUI.WindowSize = $w
        }
    } catch {}

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
            Show-Banner
            $menuLines = @(
                "       ╔═══════════════════════════════════════════════════════════════════════════════════════╗"
                "       ║                             [ MODULO CENTRAL DE INTERVENCION ]                        ║"
                "       ╚═══════════════════════════════════════════════════════════════════════════════════════╝"
                "                                                                                                "
                "       [  1  ] Escaneo Global (ONE-CLICK)      [  6  ] Utilidades del Sistema (Procesos)        "
                "       [  2  ] Auditoría de Mods (Local/Nube)  [  7  ] Hub de Herramientas y Payloads           "
                "       [  3  ] Doomsday Detector (Deep Scan)   [  8  ] ⚠ NO TOCAR ⚠                            "
                "       [  4  ] Análisis de Rastros y Papelera  [  9  ] Salir de Framework                       "
                "       [  5  ] Búsqueda de Macros & Autoclick                                                   "
                "                                                                                                "
                "       ─────────────────────────────────────────────────────────────────────────────────────────"
            )

            $gap = " "
            $totalLines = [math]::Max($menuLines.Count, $sideGirl.Count)

            for ($i = 0; $i -lt $totalLines; $i++) {
                if ($i -lt $menuLines.Count) {
                    $left = $menuLines[$i]
                    if ($left -match "╔|║|╚|╠|═|─") {
                        Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor DarkCyan
                    } elseif ($left -match "⚠ NO TOCAR ⚠") {
                        Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Red
                    } else {
                        Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Cyan
                    }
                } else {
                    Write-Host (" " * $script:BoxW) -NoNewline
                }
                
                Write-Host $gap -NoNewline

                if ($i -lt $sideGirl.Count) {
                    $girlLine = $sideGirl[$i].TrimEnd()
                    if ($i -ge 12 -and $i -le 24) { Write-Host $girlLine -ForegroundColor DarkCyan } 
                    elseif ($i -gt 24 -and $i -le 48) { Write-Host $girlLine -ForegroundColor Cyan } 
                    else { Write-Host $girlLine -ForegroundColor DarkMagenta }
                } else { Write-Host "" }
            }
            Write-Host ""
            
            $option = [string](Read-Host "       [ROOT] Selecciona un módulo [1-9]")

            switch ($option.Trim()) {
                "1"  { Start-GlobalScan }
                "01" { Start-GlobalScan }
                "2"  { Start-UnifiedModScan }
                "02" { Start-UnifiedModScan }
                "3"  { Start-SafeRemote -Url "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1" -Title "DETECCIÓN PROFUNDA (DOOMSDAY)" }
                "03" { Start-SafeRemote -Url "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1" -Title "DETECCIÓN PROFUNDA (DOOMSDAY)" }
                "4"  { Start-TraceScan }
                "04" { Start-TraceScan }
                "5"  { Start-MacroAutoclickScan }
                "05" { Start-MacroAutoclickScan }
                "6"  { Start-SysMaintenance }
                "06" { Start-SysMaintenance }
                "7"  { Start-Hubs }
                "07" { Start-Hubs }
                "8"  { Invoke-Screamer }
                "08" { Invoke-Screamer }
                "9"  { 
                    Clear-Host
                    Write-Host "`n`n`n"
                    Invoke-Typewriter "       [!] APAGANDO SISTEMA. HASTA LUEGO.`n" -Color Red
                    return 
                }
                "09" { 
                    Clear-Host
                    Write-Host "`n`n`n"
                    Invoke-Typewriter "       [!] APAGANDO SISTEMA. HASTA LUEGO.`n" -Color Red
                    return 
                }
                default { 
                    if ($option.Trim() -ne "") {
                        Write-Host "`n       [!] Entrada no reconocida en el sistema." -ForegroundColor Red
                        Start-Sleep -Seconds 1 
                    }
                }
            }
        }
        catch {
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
