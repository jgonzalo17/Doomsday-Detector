#Requires -Version 5.1
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V66 - ENTERPRISE GRADE)
# ============================================================

$script:DefaultModsPath = "$env:APPDATA\.minecraft\mods"
$script:FirstRun = $true
$script:BoxW = 95 

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
# FUNCIONES DE INTERFAZ Y UTILIDADES PROFESIONALES
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
    for ($i = 0; $i -lt $script:sideGirl.Count; $i++) {
        $line = $script:sideGirl[$i]
        if ($i -ge 12 -and $i -le 24) { Write-Host $line -ForegroundColor DarkBlue } 
        elseif ($i -gt 24 -and $i -le 48) { Write-Host $line -ForegroundColor Blue } 
        else { Write-Host $line -ForegroundColor Cyan }
    }
    Write-Host "`n"

    $bootSteps = @(
        "Inicializando subsistema de auditoría NT...",
        "Comprobando integridad de hashes y motores de descompresión...",
        "Estableciendo enlaces seguros con la memoria RAM...",
        "Configurando entorno visual de alta seguridad...",
        "Carga de módulos forenses completada con éxito."
    )

    for ($i=0; $i -lt 15; $i++) {
        $stepIndex = [math]::Min([math]::Floor($i / 3), $bootSteps.Count - 1)
        $stepText = $bootSteps[$stepIndex].PadRight(55, ' ')
        
        $pct = [math]::Round((($i + 1) / 15) * 100)
        $barLength = 35
        $filled = [math]::Round(($pct / 100) * $barLength)
        $empty = $barLength - $filled
        $progressBar = "█" * $filled + "▒" * $empty
        
        Write-Host "`r       [CORE] $stepText | [$progressBar] $pct% " -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 90
    }
    Write-Host "`n`n       [OK] SISTEMA LISTO PARA OPERAR.\n" -ForegroundColor Green
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
              ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝ ╚══════╝
"@
    Write-Host $banner -ForegroundColor Blue
    $pad = [math]::Max(0, [math]::Floor(($script:BoxW - 52) / 2))
    $str = ((' ' * $pad) + "[ ENTERPRISE FORENSIC FRAMEWORK - SECURE RUNTIME ]").PadRight($script:BoxW, ' ')
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
    for ($i=0; $i -lt 15; $i++) {
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

function Show-DetectionBox {
    param([array]$Detections, [string]$Title)
    
    Clear-Host
    Show-Header "REPORTE DE AUDITORÍA"
    $cW = [math]::Floor(($script:BoxW - 1) / 2) 

    $hasHacks = ($Detections | Where-Object { $_ -match "HACK|TE VAS BAN|ILEGAL|PELIGRO|STOPPED" })
    $borderColor = if ($hasHacks) { "Blue" } else { "DarkBlue" }

    Write-Host "       ╔$($("═" * $cW))╦$($("═" * $cW))╗" -ForegroundColor $borderColor
    Write-Host "       ║$($(" ALERTA / DETECCIÓN".PadRight($cW, ' ')))║$($(" RUTA / DETALLES".PadRight($cW, ' ')))║" -ForegroundColor Cyan
    Write-Host "       ╠$($("═" * $cW))╬$($("═" * $cW))╣" -ForegroundColor $borderColor
    
    if ($Detections.Count -eq 0) {
        Write-Host "       ║$($(" Ninguna anomalía detectada.".PadRight($cW, ' ')))║$($(" ---".PadRight($cW, ' ')))║" -ForegroundColor Green
    } else {
        foreach ($item in $Detections) {
            $item = [string]$item
            $leftText = $item
            $rightText = "---"
            
            $idx = $item.IndexOf(" | Ruta: ")
            if ($idx -lt 0) { $idx = $item.IndexOf(" | Estado: ") }
            if ($idx -ge 0) {
                $leftText = $item.Substring(0, $idx).Trim()
                $rightText = $item.Substring($idx + 9).Trim()
            }

            $color = "Cyan"
            if ($leftText -match "HACK|TE VAS BAN|ILEGAL|PELIGRO|STOPPED") { $color = "Yellow" }
            elseif ($leftText -match "\[JAVA\]|java\.exe|javaw\.exe|lunarclient") { $color = "Blue" }
            elseif ($leftText -match "======") { $color = "DarkCyan" }
            elseif ($leftText -match "\[NORMAL\]|\[ELIMINADO\]|APROBADO|\[USB DETECTADO\]|RUNNING") { $color = "Green" }

            $strL = if ($leftText -match "======") { " " + $leftText } else { "> " + $leftText }
            $strR = if ($leftText -match "======") { "" } else { $rightText }

            if ($strL.Length -gt $cW) { $strL = $strL.Substring(0, $cW - 3) + "..." }
            if ($strR.Length -gt $cW) { $strR = $strR.Substring(0, $cW - 3) + "..." }
            
            $lPad = $strL.PadRight($cW, ' ')
            $rPad = $strR.PadRight($cW, ' ')

            Write-Host "       ║" -NoNewline -ForegroundColor $borderColor
            Write-Host $lPad -NoNewline -ForegroundColor $color
            Write-Host "║" -NoNewline -ForegroundColor $borderColor
            Write-Host $rPad -NoNewline -ForegroundColor $color
            Write-Host "║" -ForegroundColor $borderColor
        }
    }
    Write-Host "       ╚$($("═" * $cW))╩$($("═" * $cW))╝" -ForegroundColor $borderColor
}

function Start-SafeRemote {
    param([string]$Url, [string]$Title)
    Clear-Host
    Show-Header $Title
    
    Write-Host "       [ ❖ ] DESCARGANDO Y EJECUTANDO SCRIPT EN ESTA TERMINAL..." -ForegroundColor Cyan
    Write-Host "       $($("─" * $script:BoxW))" -ForegroundColor DarkBlue
    
    try {
        $scriptContent = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 15
        $scriptBlock = [ScriptBlock]::Create($scriptContent)
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
    Show-Header "ESCANEO GLOBAL DEL SISTEMA (ONE-CLICK)"
    $hallazgosGlobales = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] INICIANDO AUDITORÍA GLOBAL. POR FAVOR ESPERA..." -ForegroundColor Cyan
    Write-Host "       $($("─" * $script:BoxW))" -ForegroundColor DarkBlue

    try {
        Write-Host "       [*] 1/6 Analizando Memoria RAM e Instancias..." -ForegroundColor White
        $allProcs = Get-Process -ErrorAction SilentlyContinue
        foreach ($proc in ($allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) })) {
            $hallazgosGlobales.Add("[JAVA] INSTANCIA ACTIVA : $($proc.Name).exe | Ruta: Memoria (PID: $($proc.Id))")
        }
    } catch {}

    try {
        Write-Host "       [*] 2/6 Extrayendo historial de Prefetch..." -ForegroundColor White
        $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
        $hace2 = (Get-Date).Date.AddDays(-2)
        foreach ($item in ($pfFiles | Where-Object { $_.LastWriteTime.Date -ge $hace2 })) {
            if ($script:RxHacks.IsMatch($item.Name)) {
                $hallazgosGlobales.Add("[PREFETCH HACK - TE VAS BAN] $($item.Name) | Ruta: C:\Windows\Prefetch")
            }
        }
    } catch {}

    try {
        Write-Host "       [*] 3/6 Volcando Papelera de Reciclaje..." -ForegroundColor White
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        if ($papelera) {
            foreach ($item in $papelera.Items()) {
                if ($script:RxHacks.IsMatch($item.Name)) {
                    $hallazgosGlobales.Add("[PAPELERA HACK - TE VAS BAN] $($item.Name) | Ruta: $($item.Path)")
                }
            }
        }
    } catch {}

    try {
        Write-Host "       [*] 4/6 Auditando modificaciones en .minecraft/mods..." -ForegroundColor White
        if (Test-Path $script:DefaultModsPath) {
            foreach ($mod in (Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip","*.dll" -ErrorAction SilentlyContinue)) {
                if ($script:RxHacks.IsMatch($mod.Name) -or $mod.Length -lt 15KB) {
                    $hallazgosGlobales.Add("[MOD ILEGAL - TE VAS BAN] $($mod.Name) | Ruta: $($mod.FullName)")
                }
            }
        }
    } catch {}

    try {
        Write-Host "       [*] 5/6 Verificando directorios de Macros y Periféricos..." -ForegroundColor White
        foreach ($kp in @(
            @{ Path = "$env:USERPROFILE\AppData\Local\LGHUB\settings.db"; Name = "Logitech G HUB" },
            @{ Path = "$env:APPDATA\AutoHotkey"; Name = "AutoHotkey" }
        )) {
            if (Test-Path $kp.Path) {
                $hallazgosGlobales.Add("[SOFTWARE MACRO INSTALADO] $($kp.Name) | Ruta: $($kp.Path)")
            }
        }
    } catch {}

    try {
        Write-Host "       [*] 6/6 Evaluando Servicios Base de Windows..." -ForegroundColor White
        foreach ($service in @("pcasvc", "bam", "sysmain")) {
            $output = @(& sc.exe query $service 2>&1) -join "`n"
            if ($output -match 'STOPPED') {
                $hallazgosGlobales.Add("[PELIGRO] SERVICIO APAGADO CRÍTICO: $service | Ruta: Sistema Operativo")
            }
        }
    } catch {}

    try {
        $reportPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Reporte_Sombrio_Enterprise.txt"
        $hallazgosGlobales | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        Write-Host "`n       [+] REPORTE GUARDADO EXITOSAMENTE EN: $reportPath" -ForegroundColor Green
    } catch {}

    Start-Sleep -Seconds 1
    Show-DetectionBox -Detections $hallazgosGlobales -Title "RESULTADOS GLOBALES"
    Pause-Scanner
}

function Start-UnifiedModScan {
    Clear-Host
    Show-Header "AUDITORÍA AVANZADA DE MODS"
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] Analizando integridad de mods locales..." -ForegroundColor Cyan
    if (Test-Path $script:DefaultModsPath) {
        foreach ($mod in (Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar","*.zip" -ErrorAction SilentlyContinue)) {
            if ($script:RxHacks.IsMatch($mod.Name)) {
                $hallazgos.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
            } else {
                $hallazgos.Add("[MOD APROBADO] $($mod.Name) | Ruta: OK")
            }
        }
    }
    Show-DetectionBox -Detections $hallazgos -Title "ESTADO DE MODS"
    Pause-Scanner
}

function Start-TraceScan {
    Clear-Host
    Show-Header "ANÁLISIS FORENSE DE RASTROS"
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] Analizando Prefetch y Papelera de Reciclaje..." -ForegroundColor Cyan
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
    foreach ($item in ($pfFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 20)) {
        if ($script:RxHacks.IsMatch($item.Name)) {
            $hallazgos.Add("[PREFETCH HACK] $($item.Name) | Hora: $($item.LastWriteTime)")
        } else {
            $hallazgos.Add("[PREFETCH NORMAL] $($item.Name) | Hora: $($item.LastWriteTime)")
        }
    }
    Show-DetectionBox -Detections $hallazgos -Title "RASTROS EN DISCO"
    Pause-Scanner
}

function Start-MacroAutoclickScan {
    Clear-Host
    Show-Header "DETECCIÓN DE MACROS Y AUTOCLICKERS"
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "       [ ❖ ] Analizando procesos en ejecución..." -ForegroundColor Cyan
    foreach ($proc in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) })) {
        $hallazgos.Add("[PROCESO MALICIOSO] $($proc.Name).exe | PID: $($proc.Id)")
    }
    Show-DetectionBox -Detections $hallazgos -Title "MACROS EN MEMORIA"
    Pause-Scanner
}

function Start-ServicesAudit {
    Clear-Host
    Show-Header "AUDITORÍA DE SERVICIOS DEL SISTEMA"
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    foreach ($srvName in $script:WindowsServices) {
        $srv = Get-Service -Name $srvName -ErrorAction SilentlyContinue
        if ($srv) {
            $hallazgos.Add("$($srv.Name) ($($srv.DisplayName)) | Estado: $($srv.Status)")
        }
    }
    Show-DetectionBox -Detections $hallazgos -Title "SERVICIOS ACTIVOS"
    Pause-Scanner
}

function Start-SysMaintenance {
    Clear-Host
    Show-Header "UTILIDADES Y GESTIÓN DE PROCESOS"
    Write-Host "       [ ❖ ] Limpiando búferes y optimizando terminal..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    Write-Host "       [+] Sistema optimizado con éxito." -ForegroundColor Green
    Pause-Scanner
}

function Start-Hubs {
    Clear-Host
    Show-Header "HUB DE HERRAMIENTAS EXTERNAS"
    Write-Host "       [ 1 ] System Informer (Descarga directa)" -ForegroundColor White
    Write-Host "       [ 2 ] JournalTrace (Utilidad de análisis)" -ForegroundColor White
    $ch = Read-Host "`n       Selecciona una opción o 0 para salir"
    if ($ch -eq "1") { Start-Process "https://sourceforge.net/projects/systeminformer/" }
    Pause-Scanner
}

function Invoke-Screamer {
    Clear-Host
    Write-Host "`n       [!] EJECUTANDO PROTOCOLO DE SIMULACIÓN TROLL..." -ForegroundColor Red
    Start-Sleep -Seconds 1
    for ($i=1; $i -le 10; $i++) {
        Write-Host "`r       [!] Simulando brecha de seguridad [$i/10]..." -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 200
    }
    Write-Host "`n       [+] Protocolo finalizado sin daños reales." -ForegroundColor Green
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
        $statusText = if ($isAdmin) { " [ ESTADO DE SEGURIDAD: PRIVILEGIOS DE ADMINISTRADOR ACTIVOS ] " } else { " [ AVISO: EJECUTE COMO ADMINISTRADOR PARA MÁXIMA EFECTIVIDAD ] " }

        $menuLines = @(
            "       ╔═══════════════════════════════════════════════════════════════════════════════════════╗"
            "       ║                        [ CONSOLA CENTRAL DE OPERACIONES FORENSES ]                    ║"
            "       ╠═══════════════════════════════════════════════════════════════════════════════════════╣"
            "       ║$($statusText.PadRight(95))║"
            "       ╠═══════════════════════════════════════════════════════════════════════════════════════╣"
            "       ║                                                                                       ║"
            "       ║   [ 01 ] Escaneo Global del Sistema      ║   [ 06 ] Utilidades y Mantenimiento        ║"
            "       ║   [ 02 ] Auditoría de Mods e Instancias  ║   [ 07 ] Hub de Herramientas Externas      ║"
            "       ║   [ 03 ] Doomsday Detector (Nube)        ║   [ 08 ] Módulo Restringido (Simulación)   ║"
            "       ║   [ 04 ] Análisis de Rastros y Prefetch  ║   [ 09 ] Salir del Framework               ║"
            "       ║   [ 05 ] Búsqueda de Macros & Autoclick  ║   [ 10 ] Auditoría de Servicios Windows    ║"
            "       ║                                          ║   [ 00 ] EXIT SILENCIOSO (PANIC BUTTON)    ║"
            "       ║                                                                                       ║"
            "       ╚═══════════════════════════════════════════════════════════════════════════════════════╝"
        )

        $gap = " "
        $totalLines = [math]::Max($menuLines.Count, $script:sideGirl.Count)

        for ($i = 0; $i -lt $totalLines; $i++) {
            if ($i -lt $menuLines.Count) {
                $left = $menuLines[$i]
                if ($left -match "╔|╚|═|╠") {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor DarkBlue
                } elseif ($left -match "CONSOLA CENTRAL") {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Cyan
                } elseif ($left -match "ESTADO DE SEGURIDAD") {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Green
                } elseif ($left -match "AVISO") {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Yellow
                } else {
                    Write-Host $left.PadRight($script:BoxW) -NoNewline -ForegroundColor Blue
                }
            } else {
                Write-Host (" " * $script:BoxW) -NoNewline
            }
            
            Write-Host $gap -NoNewline

            if ($i -lt $script:sideGirl.Count) {
                $girlLine = $script:sideGirl[$i].TrimEnd()
                if ($i -ge 12 -and $i -le 24) { Write-Host $girlLine -ForegroundColor DarkBlue } 
                elseif ($i -gt 24 -and $i -le 48) { Write-Host $girlLine -ForegroundColor Blue } 
                else { Write-Host $girlLine -ForegroundColor Cyan }
            } else { Write-Host "" }
        }
        Write-Host ""
        
        $option = [string](Read-Host "       [ROOT@SOMBRIO-PRO]# Seleccione un módulo operativo [00-10]")

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
            "6"  { Start-SysMaintenance }
            "06" { Start-SysMaintenance }
            "7"  { Start-Hubs }
            "07" { Start-Hubs }
            "8"  { Invoke-Screamer }
            "08" { Invoke-Screamer }
            "9"  { return }
            "09" { return }
            "10" { Start-ServicesAudit }
            default { 
                if ($option.Trim() -ne "") {
                    Write-Host "`n       [!] Comando o módulo no reconocido en el sistema." -ForegroundColor Red
                    Start-Sleep -Seconds 1 
                }
            }
        }
    }
}

Show-MainMenu
