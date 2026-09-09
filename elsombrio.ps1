#Requires -Version 5.1
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V35 - COLOR AUDIT)
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
    $furinaAscii = @'
                                                     .::---:               ::
                                                    =-..-::-*=            -+.   -+-
                                                   -: =.     :+          :=+   ===
                                                  :+ .*       =:        ===-::.==.
                                                   -: +                :. ..:. -.=.     ..
                                                    =--=       .....  =:   .=  ==+-   .:++.
                                                     .-==.    =:...::-:    -.   :*-. :==-.
                                                        -=-. .+       :=-     :-: .=:=.+.
                                                          .:=---::::.   -=+:  .  .--.=.
                                                       :----:  ::.  :=:   :=-:   -  :=:::.
                                                     :-.:...::- :- ::::=:  -=.: :-.=-----+
                                                    =. -: :..   . .:    ==  .-.  +-::+.
                                                  --. =.  .   :    =:    *+  -+=:..:=:
                                            :---::. -:  -   :+:  =  =:    ++  .+ ..---
                                             .---::...-.  :-:=  .+   =    .==  --. ..++
                                            ---:.   :. .--..-+  :=    --.   =+.  +.:-:-+
                                            =..: :=--=+-===..-  -..: = :--:.:=-  .=. *+.
                                            *.* -=  *-*..**=  : =..+.=:.   ..=.   .+ :*-
                                            .--.+:  =-*.  .    :--@*=+=:.-=  :=    =:+:+
                                              =:*:-. .+=     .    --.-=:  :-  +    -:=-
                                              :.  ..=-  =-  :::    :-=-    .+=-    --+
                                                   =-..  .-::..::--= ...-:-.-.     ==.
                                                  .=: :. -+:::+-..+..+. -==.      :+
                                                    ::=--=.---+- .-=:=.. ..       :
                                               .:-::--=: :+:.--*--+=. .:=:::
                                              =:-:..:.:.  -..-.... :.:  .  --
                                          .-=-  +=:.=::: .+: .==:=.:-+      =:
                                          =-:. .+ ..  .  .+-:  .-=.=:-     ..+:                   ::
     ==::                              .--     .*  =  -=-.     .:-         :--=+          :-::  ---:  ----+=
    .=::- =--                         --      : +.  --.    .-:::.    .-.      .--  .=:--::. .:-=. ..  :-=:.
   :+:+ -=. -=                .   ::=-        =:.= .  . -=-:.       -= -=       :=.:*-.:    -:-:     :=:---:
   #. *  .*. +              :--+::.        .-:.= +. .=-:==.       .=:   .=-      ::: --*.     =..:-:+=--======
 :-:= .-- +.:--           :-=..*         :=-   +:- -: .-.-       :-.      =-        .=-.      ....      ..-:::
 :-.:=: +.::-::-    ..::-:=:: =:..    ..-: .   --==-..= -.      :=         -+       ++:-:-..  .:-.
  + .-*.:.*::.+:  :*:..     -.:.:-+=::..   +..:. .:.:+  +=     --  ....     =+:.   . ..: *:.--.
  .:---.- =.+. .:: .=.        :.+--       -:  =-::  +. :+-     +.=--:.:+     :=-:::.     .-=.
      ..-.+-+=-:    .+.      .*-+-        +:::..::-.+  :+      --..:  :-      .-::. ....::::::::::=-::::::.
         --.::=::.  -:+   :::.....      ::-:-:==     -=:.=.   :-::-.  .:-        ..:::..          :.-::.  .:-.
        =-..*=-=    -:+ ::.          :--. :=..==     --: .= .-- :=:--::.:=-.                          ..-:   :=
        +.  := :+   ::..            .*  .=- :=+     .+= -:+.:     :=.--.   :--:.                         .=.  --
            :== +=     :.            -:-+:  .::      :: -=+-       :=..--.    .:::::::::::::--==::..      .=. =-
           == +.=-==    --         :-.:=+   =           -==:+   ..::-*   .-::                  .-=.+:       *-=
          =:  =-: ---::  .:     :-=. -:-:..-.         ..==:-::::-:    -.    .-=:.                :++.       +-
          +   -:+:=.=-:-  -.  =-:  .=. :::-=::::::::::.. --: :: :-    .+.      ..-:=.             @:        =
         :=   +.=.= =.-:=.  --: .==:  .+        ..            .= =      +.         ::-=:        .=.       .=
         .=   +.= :-=:-:+.:..  ==:    ==::-:..........::=-:::::--=       +:           -*.       =.        =.
          +:   .=:= -.-=:+   .=-      .+  ........ =:.         --+.       +-           =.     .=        -=
          .*.    :=:=:-:=:  :=        .+::......:::=.:::::::::::=+.       .*:          =      =      .-:.
           .+     .:*--=     -=.      .+  ......  -=.   .   ::.=-+-       := =.        +.    .+    .-.
            .-=     =:.-.     .--:.   .=:-::::::::==:-:::::::::-:-.       =   -.      .=     .=   -:    .:--.
              ::-:   =+ +:       .+    =-         :=           * -=      --    =:     +.      =-  -=    += .-+
                  -   +  :::     -.     +         :=           --=.       =     --   +:        -:  :-:      :*
                  *   :-: *:    +:      -=        :=           .+         +:       --.          :: . .    ::-.
                  .:-.. =.-:   ::        =.       :=           =.        .=       .=.              ::::::::
                    =:=:+.:+  +-       :..*       :+          .+        --       :. =:
                       ..=: +:.      :::  :=      :=          =.     .-:.      -:.   -
                          + :=      =-     =:     :+         -=      +       ..:     *
                         --= .=   --     :-.+.    :+         +      --       -:     .=
                       .=. =- :=...     --  .=    :+        --     .+        .=   .::
                     .=:    =- .+     -=     --   :=        *.:-:..+          * .-..
                  .:-:    .: -: -=  --:       +   :=       --    :-.          *-.
                ::-.    ::-.  +: =-           :+  +.       +                 =-
             .=-.     --.      := +.           .= +.       =.             .:-.
          :--.     .--:.....:.  =- +  .:::      :=:=       .+           -::
      .:=-:.    .--.  ......     =- +..==        .=.+        +         +
      =--::::-=:-.             .:.+ .=.-          -:=        :=       =:
           .=-.         ..::-:::. :+ :=            ++         #=    .+:
          ::-:::::::::::..         -= =:           .+:       .+-: :-:
                                  =--= +:           =:       .+ +:
                                 ::  -: +.          =:       .+  =
                               :+:    +..+          =-       :=  -=
                             .++       + :=         =-       =:   --
                             .-        -* .=.       =-       +     =.
                           .=:          *.  -=      =-      -=      +
                          =-    ..-:-.  +-.:-:      =-      +=:     :-...
                        -+-.::::..      .+: -=+     =-     :+ ==     +=.-= --
                        -:..             .-:=-=-    =:     =   .-:    -..:=.=
                                           :#*..    =:    =-   ..-::.. .  #:
                                             :: --  =:    +    +:  ..:  .=+::
                                            ++*:*:  *.   -=     :*:.:-..=:  :-
                                             .=.::..+    =        .=+-::=   :::
                                              .+.-::+   ==-:.      *:.-:=- .+.+.
                                                +:.-=...+  .+      :.-:.-  :=::
                                              .:+.: ....   :+       --.=.  .+
                                              .:=:-:=:..--*-        =.  .  .+
                                                =+:.....+:.        .*  .  :+:
                                                :.---=-+:          =     -=
                                               -:.::..-=           =...:-.
                                              +-:-*::+-:            ....
                                              :=:::.---:
                                              :+:==:  =-
                                             .:.: .:  -:
                                            :+-     : +:
                                            = --::-:.:=
                                            ==     .=-
                                             :-:::::
'@ -split "`n"

    $bootSteps = @(
        "Inicializando módulos de descompresión NT...",
        "Resolviendo dependencias remotas y APIs...",
        "Inyectando hooks en procesos de memoria...",
        "Sincronizando paleta de colores...",
        "Estableciendo enlace de sistema seguro..."
    )

    for ($i=0; $i -lt 15; $i++) {
        Clear-Host
        $floatSpaces = " " * (2 + ($i % 3))
        $lineNum = 0
        foreach ($line in $furinaAscii) {
            if ($lineNum -ge 12 -and $lineNum -le 24) { $c = "DarkCyan" }
            elseif ($lineNum -gt 24 -and $lineNum -le 48) { $c = "Blue" }
            elseif ($lineNum -gt 48) { $c = "Cyan" }
            else { $c = "DarkBlue" }
            Write-Host ($floatSpaces + $line.TrimEnd()) -ForegroundColor $c
            $lineNum++
        }

        $stepIndex = [math]::Min([math]::Floor($i / 3), $bootSteps.Count - 1)
        Write-Host "`n [Bootloader] $($bootSteps[$stepIndex])" -ForegroundColor Cyan
        
        $pct = [math]::Round((($i + 1) / 15) * 100)
        $barLength = 30
        $filled = [math]::Round(($pct / 100) * $barLength)
        $empty = $barLength - $filled
        $progressBar = "█" * $filled + "▒" * $empty
        
        Write-Host " [System]     $pct% [$progressBar]" -ForegroundColor Magenta
        Start-Sleep -Milliseconds 120
    }
    Write-Host "`n [OK] INTERFAZ LISTA. TODOS LOS MÓDULOS CARGADOS Y SEGUROS.`n" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
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
    Write-Host $banner -ForegroundColor Blue
    Write-Host "                [ ADVANCED FORENSIC SCANNER ]                `n" -ForegroundColor DarkGray
}

function Show-Header {
    param([string]$Subtitle)
    Clear-Host
    Write-Host "`n     ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor DarkBlue
    Write-Host "     ║               EL SOMBRIO IF - FORENSIC SCANNER               ║" -ForegroundColor Cyan
    Write-Host "     ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor DarkBlue
    $pad = [math]::Max(0, [math]::Floor((60 - $Subtitle.Length) / 2))
    $str = ((' ' * $pad) + $Subtitle).PadRight(60, ' ')
    Write-Host ("     ║{0}║" -f $str) -ForegroundColor White
    Write-Host "     ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor DarkBlue
    Write-Host ""
}

function Pause-Scanner {
    Write-Host "`n"
    Invoke-Typewriter "     [ Presiona ENTER para regresar al menú principal ]" -Speed 10 -Color DarkGray
    Read-Host | Out-Null
}

function Show-DetectionBox {
    param([array]$Detections, [string]$Title)
    Write-Host "`n     ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    $pad = [math]::Max(0, [math]::Floor((60 - $Title.Length) / 2))
    $str = ((' ' * $pad) + $Title).PadRight(60, ' ')
    Write-Host "     ║$str║" -ForegroundColor Red
    Write-Host "     ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Red
    if ($Detections.Count -eq 0) {
        Write-Host "     ║ No se detectaron anomalías en este escaneo.                  ║" -ForegroundColor Green
    } else {
        foreach ($item in $Detections) {
            $displayStr = $item
            if ($displayStr.Length -gt 56) { $displayStr = $displayStr.Substring(0, 53) + "..." }
            $itemStr = (" > " + $displayStr).PadRight(60, ' ')
            Write-Host "     ║$itemStr║" -ForegroundColor Yellow
        }
    }
    Write-Host "     ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    
    if ($Detections.Count -gt 0) {
        Write-Host "`n     [LOG COMPLETO DE RUTAS DETECTADAS]" -ForegroundColor DarkGray
        foreach ($item in $Detections) {
            Write-Host "     $item" -ForegroundColor Gray
        }
    }
}

function Test-Administrator { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

# ============================================================
# MÓDULOS DE ESCANEO
# ============================================================
function Start-FullModScan {
    Show-Header "ANÁLISIS AVANZADO DE MODS (MEOW MOD ANALYZER)"
    if (-not (Test-Administrator)) { Write-Host "     [!] Se requiere Administrador."; Pause-Scanner; return }
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
        $url = "https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1"
        $scriptContent = Invoke-RestMethod -Uri $url -UseBasicParsing
        $scriptBlock = [ScriptBlock]::Create($scriptContent)
        & $scriptBlock
    } catch { Write-Host "`n     [!] Error: $($_.Exception.Message)" -ForegroundColor Red }
    Pause-Scanner
}

function Start-DoomsdayMemoryScan {
    Show-Header "DETECCIÓN PROFUNDA (DOOMSDAY DETECTOR)"
    if (-not (Test-Administrator)) { Write-Host "     [!] Se requiere Administrador."; Pause-Scanner; return }
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
        $url = "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1"
        $scriptContent = Invoke-RestMethod -Uri $url -UseBasicParsing
        $scriptBlock = [ScriptBlock]::Create($scriptContent)
        & $scriptBlock
    } catch { Write-Host "`n     [!] Error: $($_.Exception.Message)" -ForegroundColor Red }
    Pause-Scanner
}

function Start-SystemScan {
    Show-Header "INTERVENCIÓN RÁPIDA (PREFETCH / EJECUCIONES DE HOY)"
    if (-not (Test-Administrator)) { Write-Host "     [!] Se requieren privilegios de Administrador para ver Prefetch."; Pause-Scanner; return }
    
    try {
        $pfVal = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -ErrorAction SilentlyContinue
        if ($pfVal -eq 0) { Write-Host "     [*] Motor Prefetch: DESHABILITADO (Sospechoso/Borrado)" -ForegroundColor Red }
        elseif ($pfVal -eq 3) { Write-Host "     [*] Motor Prefetch: HABILITADO (Normal)" -ForegroundColor Green }
        else { Write-Host "     [*] Motor Prefetch: MODIFICADO (Valor: $pfVal)" -ForegroundColor Yellow }
    } catch { Write-Host "     [*] Motor Prefetch: NO SE PUDO LEER ESTADO" -ForegroundColor Yellow }

    $hallazgos = [System.Collections.Generic.List[string]]::new()
    $list = @()
    
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
    if ($pfFiles) {
        $pfFiles | Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-1) } | 
        ForEach-Object { $list += [PSCustomObject]@{ Time = $_.LastWriteTime; Name = $_.Name; FullName = $_.FullName } }
        
        $list = $list | Sort-Object Time -Descending | Select-Object -First 30
        
        foreach ($item in $list) {
            $timeStr = $item.Time.ToString("HH:mm:ss")
            if ($item.Name.ToLower() -match $script:RegexHacks) {
                $hallazgos.Add(">> [ALERTA HACK] [$timeStr] $($item.Name) - TE VAS BAN")
            } else {
                $hallazgos.Add("[$timeStr] $($item.Name)")
            }
        }
    } else {
         $hallazgos.Add("[!] Carpeta Prefetch vacía o bloqueada.")
    }
    
    Show-DetectionBox -Detections $hallazgos -Title "ÚLTIMOS 30 EJECUTADOS (MÁS RECIENTE A ANTIGUO)"
    Pause-Scanner
}

function Start-RecycleBinScan {
    Show-Header "ANÁLISIS DE PAPELERA DE RECICLAJE"
    $hallazgosPapelera = [System.Collections.Generic.List[string]]::new()
    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        foreach ($item in $papelera.Items()) {
            if ($item.Name.ToLower() -match $script:RegexHacks) { 
                $hallazgosPapelera.Add(">> [HACK BORRADO] $($item.Name) - TE VAS BAN") 
            } else {
                $hallazgosPapelera.Add("[ELIMINADO] $($item.Name)")
            }
        }
    } catch {}
    Show-DetectionBox -Detections $hallazgosPapelera -Title "LISTA DE ARCHIVOS ELIMINADOS"
    Pause-Scanner
}

function Start-MacroAudit {
    Show-Header "AUDITORÍA DE MACROS Y PERIFÉRICOS"
    $hallazgosMacros = [System.Collections.Generic.List[string]]::new()
    $pathsToCheck = @(
        "$env:USERPROFILE\AppData\Local\Logitech\Logitech Gaming Software\settings.json",
        "$env:USERPROFILE\AppData\Local\LGHUB\settings.db",
        "C:\Program Files (x86)\Bloody7\Bloody7\Data\Mouse\English\ScriptsMacros\GunLib\"
    )
    foreach ($p in $pathsToCheck) { if (Test-Path $p) { $hallazgosMacros.Add("Detectado: $(Split-Path $p -Leaf) | Ruta: $p") } }
    Show-DetectionBox -Detections $hallazgosMacros -Title "SOFTWARE DE MACROS DETECTADO"
    Pause-Scanner
}

function Start-DiffKiller {
    Show-Header "FINALIZADOR DE PROCESOS OCULTOS (DIFF)"
    $forbidden = @("obs","obs32","obs64","discord","streamlabs","bandicam","sharex","gamebar")
    $detected = @()
    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        if ($forbidden -contains $proc.Name.ToLower()) { $detected += $proc.Name; Write-Host "     [!] Proceso detectado: $($proc.Name)" -ForegroundColor Yellow }
    }
    if ($detected.Count -gt 0 -and (Read-Host "`n     ¿Forzar cierre? (S/N)").ToUpper() -eq "S") {
        foreach ($name in $detected) { Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force }
    }
    Pause-Scanner
}

function Show-WindowsServices {
    Show-Header "ESTADO DE SERVICIOS WINDOWS"
    $hallazgosSvc = [System.Collections.Generic.List[string]]::new()
    foreach ($service in $script:WindowsServices) {
        $output = @(& sc.exe query $service 2>&1) -join "`n"
        if ($output -match 'STOPPED' -and ($service -eq "pcasvc" -or $service -eq "bam" -or $service -eq "sysmain")) {
            $hallazgosSvc.Add("Servicio Apagado: $service")
        }
    }
    Show-DetectionBox -Detections $hallazgosSvc -Title "ALERTAS DE SERVICIOS"
    Pause-Scanner
}

function Start-SSToolsHub {
    Show-Header "HUB DE HERRAMIENTAS SS"
    $tools = @(
        [PSCustomObject]@{ Id=1; Name="System Informer"; Url="https://sourceforge.net/projects/systeminformer/files/latest/download"; Icon="✦" }
        [PSCustomObject]@{ Id=2; Name="JournalTrace"; Url="https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe"; Icon="▶" }
    )
    foreach ($t in $tools) { Write-Host "     [$($t.Id)] $($t.Icon) $($t.Name)" -ForegroundColor White }
    $choice = (Read-Host "`n     [COMANDO] ID (o 0 salir)").Trim()
    if ($choice -ne "0") {
        $sel = $tools | Where-Object { $_.Id.ToString() -eq $choice }
        if ($sel) {
            try {
                $out = "$env:TEMP\$(($sel.Name -replace '\s','_')).exe"
                Invoke-WebRequest -Uri $sel.Url -OutFile $out -UseBasicParsing -TimeoutSec 15
                Start-Process $out -Wait
            } catch { Start-Process $sel.Url }
        }
    }
}

function Start-RemoteScript {
    Show-Header "PAYLOAD HUB (GITHUB)"
    if (-not (Test-Administrator)) { Write-Host "     [!] Se requiere Administrador."; Pause-Scanner; return }
    $payloads = @(
        [PSCustomObject]@{ Id=1; Name="Lilith Services"; Url="https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1" },
        [PSCustomObject]@{ Id=2; Name="Ordiff Kill ScreenRecording"; Url="https://raw.githubusercontent.com/Orbdiff/powershell/refs/heads/main/kill-screen-processes.ps1" }
    )
    foreach ($p in $payloads) { Write-Host "     [$($p.Id)] $($p.Name)" -ForegroundColor White }
    $choice = (Read-Host "`n     [COMANDO] ID (o 0 salir)").Trim()
    if ($choice -ne "0") {
        $sel = $payloads | Where-Object { $_.Id.ToString() -eq $choice }
        if ($sel) {
            try {
                Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
                & ([ScriptBlock]::Create((Invoke-RestMethod -Uri $sel.Url -UseBasicParsing)))
            } catch { Write-Host "     [!] Error: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
    Pause-Scanner
}

function Start-FullDiskScan {
    Show-Header "ANÁLISIS COMPLETO DEL DISCO (MODIFICADOS Y BORRADOS)"
    $hallazgosDisco = [System.Collections.Generic.List[string]]::new()
    
    Write-Host "     [*] Escaneando papelera raíz de todos los discos..." -ForegroundColor DarkGray
    $sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    foreach ($drive in $drives) {
        $recPath = "$drive`$Recycle.Bin\$sid"
        if (Test-Path $recPath) {
            Get-ChildItem -Path $recPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.Name -match $script:RegexHacks) {
                    $hallazgosDisco.Add("[BORRADO-HACK] TE VAS BAN | Ruta: $($_.FullName)")
                } else {
                    $hallazgosDisco.Add("[BORRADO] $($_.Name) | Ruta: $($_.FullName)")
                }
            }
        }
    }

    Write-Host "     [*] Escaneando ejecutables/mods modificados en las últimas 48 hrs..." -ForegroundColor DarkGray
    Get-ChildItem -Path "C:\Users" -Recurse -File -Include "*.jar","*.exe","*.bat" -ErrorAction SilentlyContinue | 
    Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-2) } | ForEach-Object {
        if ($_.Name -match $script:RegexHacks) {
            $hallazgosDisco.Add("[MODIFICADO-HACK] TE VAS BAN | Ruta: $($_.FullName)")
        } else {
            $hallazgosDisco.Add("[MODIFICADO] $($_.Name) | Ruta: $($_.FullName)")
        }
    }

    Show-DetectionBox -Detections $hallazgosDisco -Title "ARCHIVOS MODIFICADOS Y BORRADOS EN DISCO"
    Pause-Scanner
}

function Start-WinRCommands {
    Show-Header "RUTAS DE ANÁLISIS MANUAL (WIN + R)"
    $rutas = @(
        [PSCustomObject]@{ Id=1; Cmd="C:\`$Recycle.bin"; Desc="Papelera" },
        [PSCustomObject]@{ Id=2; Cmd="regedit"; Desc="Registro" },
        [PSCustomObject]@{ Id=3; Cmd="C:\Windows\Prefetch"; Desc="Prefetch" },
        [PSCustomObject]@{ Id=4; Cmd="cmd.exe"; Desc="Consola CMD" }
    )
    foreach ($r in $rutas) { Write-Host "     [$($r.Id)] $($r.Cmd) ➜ $($r.Desc)" -ForegroundColor Yellow }
    $choice = (Read-Host "`n     [COMANDO] ID (o 0 salir)").Trim()
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

function Start-AdvancedAutoclickScan {
    Show-Header "BÚSQUEDA PROFUNDA DE AUTOCLICKERS (TODO EL DISCO)"
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    
    $regexNames = "autoclick|gsautoclick|opautoclicker|forgeclick|speedautoclick|macro|clicker|murgee|tinytask|jitbit|fyre|jclicker|ghostclicker"
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } | Select-Object -ExpandProperty Root
    
    foreach ($drive in $drives) {
        Write-Host "     [*] Rastreando el disco $drive (Esto tomará algo de tiempo)..." -ForegroundColor DarkGray
        Get-ChildItem -Path $drive -Recurse -File -Include "*.exe","*.jar","*.bat","*.ahk","*.vbs","*.py","*.dll" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match $regexNames } | ForEach-Object {
            $hallazgos.Add("[AUTOCLICK DETECTADO] TE VAS BAN | Ruta: $($_.FullName)")
        }
    }
    
    Show-DetectionBox -Detections $hallazgos -Title "AUTOCLICKERS DETECTADOS EN EL SISTEMA"
    Pause-Scanner
}

function Start-ExtremeModScan {
    Show-Header "ANÁLISIS EXTREMO (PROCESOS, INSTANCIAS Y MODS)"
    if (-not (Test-Administrator)) { Write-Host "     [!] Se requiere Administrador."; Pause-Scanner; return }
    
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    $allProcs = Get-Process -ErrorAction SilentlyContinue

    # =========================================================
    # 1. SEPARACIÓN DE PROCESOS (MC vs HACKS vs NORMALES)
    # =========================================================
    Write-Host "`n     [====== SEPARACIÓN DE PROCESOS ======]" -ForegroundColor Cyan
    
    $mcProcs = $allProcs | Where-Object { $_.Name -match "java|javaw|lunarclient|craft" }
    $badProcs = $allProcs | Where-Object { $_.Name -match $script:RegexHacks }
    $otherProcs = $allProcs | Where-Object { $_.Name -notmatch "java|javaw|lunarclient|craft" -and $_.Name -notmatch $script:RegexHacks }

    if ($mcProcs) {
        Write-Host "     [INSTANCIAS DE JUEGO / MC]" -ForegroundColor Green
        foreach ($proc in $mcProcs) {
            Write-Host "     [+] $($proc.Name).exe (PID: $($proc.Id)) - CORRIENDO" -ForegroundColor Green
            try {
                $proc.Modules | Where-Object { $_.FileName -match $script:RegexHacks } | ForEach-Object {
                    Write-Host "         [!] HACK INYECTADO: $($_.ModuleName) - TE VAS BAN" -ForegroundColor Red
                    Write-Host "         [!] Ruta de la inyección: $($_.FileName)" -ForegroundColor Red
                    $hallazgos.Add("[INYECCIÓN EN RAM] $($_.ModuleName) - TE VAS BAN | Ruta: $($_.FileName)")
                }
            } catch {}
        }
    } else {
        Write-Host "     [-] No se detectaron instancias de Minecraft o Java." -ForegroundColor White
    }

    if ($badProcs) {
        Write-Host "`n     [PROCESOS HACK / AUTOCLICKS EXTERNOS]" -ForegroundColor Red
        foreach ($proc in $badProcs) {
            Write-Host "     [!] $($proc.Name).exe (PID: $($proc.Id)) - TE VAS BAN" -ForegroundColor Red
            $hallazgos.Add("[PROCESO HACK] $($proc.Name).exe - TE VAS BAN")
        }
    } else {
        Write-Host "`n     [+] Ningún proceso externo catalogado como Hack." -ForegroundColor White
    }

    Write-Host "`n     [PROCESOS DEL SISTEMA]" -ForegroundColor White
    Write-Host "     [*] Analizando $($otherProcs.Count) procesos normales en segundo plano... (Blancos/Limpios)" -ForegroundColor White


    # =========================================================
    # 2. ESCANEO DE MODS EN CARPETA (LEGALES VS ILEGALES)
    # =========================================================
    Write-Host "`n     [====== ANÁLISIS DE MODS (.JAR) ======]" -ForegroundColor Cyan
    if (Test-Path $script:DefaultModsPath) {
        $modFiles = Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar", "*.zip", "*.dll"
        if ($modFiles.Count -gt 0) {
            foreach ($mod in $modFiles) {
                $isBad = $false
                if ($mod.Name.ToLower() -match $script:RegexHacks) { $isBad = $true }
                if ($mod.LastWriteTime -gt $mod.CreationTime.AddDays(7)) { $isBad = $true }
                if ($mod.Length -lt 15KB) { $isBad = $true }

                if ($isBad) {
                    Write-Host "     [!] MOD ILEGAL O MODIFICADO: $($mod.Name) -> TE VAS BAN" -ForegroundColor Red
                    $hallazgos.Add("[MOD ILEGAL] $($mod.Name) | Ruta: $($mod.FullName)")
                } else {
                    Write-Host "     [+] MOD LEGAL: $($mod.Name) -> Aprobado" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "     [-] La carpeta de mods está vacía." -ForegroundColor White
        }
    } else {
        Write-Host "     [-] No se encontró carpeta de mods en AppData." -ForegroundColor White
    }


    # =========================================================
    # 3. PAPELERA DE RECICLAJE
    # =========================================================
    Write-Host "`n     [====== PAPELERA DE RECICLAJE ======]" -ForegroundColor Cyan
    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        if ($papelera.Items().Count -gt 0) {
            foreach ($item in $papelera.Items()) {
                if ($item.Name.ToLower() -match $script:RegexHacks) {
                    Write-Host "     [!] BORRADO HACK: $($item.Name) -> TE VAS BAN" -ForegroundColor Red
                    $hallazgos.Add("[PAPELERA HACK] $($item.Name) | Ruta Original: $($item.Path)")
                } else {
                    Write-Host "     [-] BORRADO NORMAL: $($item.Name)" -ForegroundColor White
                }
            }
        } else {
            Write-Host "     [-] La papelera de reciclaje está vacía." -ForegroundColor White
        }
    } catch {}

    Show-DetectionBox -Detections $hallazgos -Title "RESULTADOS DE INSTANCIAS, MODS Y PAPELERA"
    Pause-Scanner
}


# ============================================================
# MENÚ PRINCIPAL ESTRUCTURADO Y ALINEADO
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
            Show-Banner
            $menuLines = @(
                "       ╔═══════════════════════════════════════════════════════════════════════╗"
                "       ║                  [ MODULO CENTRAL DE INTERVENCION ]                   ║"
                "       ╚═══════════════════════════════════════════════════════════════════════╝"
                "                                                                                "
                "       [  1  ] Analizar Mods              [  8  ] Hub Herramientas SS       "
                "       [  2  ] Doomsday Detector          [  9  ] Hub Payloads (GitHub)     "
                "       [  3  ] Análisis Prefetch/BAM      [ 10  ] Análisis Completo Disco   "
                "       [  4  ] Análisis Papelera          [ 11  ] Rutas Manuales (Win+R)    "
                "       [  5  ] Auditoría de Macros        [ 12  ] Autoclick Scanner (ALL)   "
                "       [  6  ] Killer Screen (Diff)       [ 13  ] Mod & Instancia Extreme   "
                "       [  7  ] Servicios Windows          [ 14  ] Salir de Framework        "
                "                                                                                "
                "       ─────────────────────────────────────────────────────────────────"
            )

            $leftWidth = 79
            $gap = "    "
            $totalLines = [math]::Max($menuLines.Count, $sideGirl.Count)

            for ($i = 0; $i -lt $totalLines; $i++) {
                if ($i -lt $menuLines.Count) {
                    $left = $menuLines[$i]
                    Write-Host $left.PadRight($leftWidth) -NoNewline -ForegroundColor Blue
                } else {
                    Write-Host (" " * $leftWidth) -NoNewline
                }
                Write-Host $gap -NoNewline

                if ($i -lt $sideGirl.Count) {
                    $girlLine = $sideGirl[$i].TrimEnd()
                    if ($i -ge 12 -and $i -le 24) { Write-Host $girlLine -ForegroundColor DarkCyan } 
                    elseif ($i -gt 24 -and $i -le 48) { Write-Host $girlLine -ForegroundColor Blue } 
                    else { Write-Host $girlLine -ForegroundColor Cyan }
                } else { Write-Host "" }
            }
            Write-Host ""
            $option = (Read-Host "       [ROOT] Selecciona un módulo [1-14]").Trim()

            switch ($option) {
                "1"  { Start-FullModScan }
                "01" { Start-FullModScan }
                "2"  { Start-DoomsdayMemoryScan }
                "02" { Start-DoomsdayMemoryScan }
                "3"  { Start-SystemScan }
                "03" { Start-SystemScan }
                "4"  { Start-RecycleBinScan }
                "04" { Start-RecycleBinScan }
                "5"  { Start-MacroAudit }
                "05" { Start-MacroAudit }
                "6"  { Start-DiffKiller }
                "06" { Start-DiffKiller }
                "7"  { Show-WindowsServices }
                "07" { Show-WindowsServices }
                "8"  { Start-SSToolsHub }
                "08" { Start-SSToolsHub }
                "9"  { Start-RemoteScript }
                "09" { Start-RemoteScript }
                "10" { Start-FullDiskScan }
                "11" { Start-WinRCommands }
                "12" { Start-AdvancedAutoclickScan }
                "13" { Start-ExtremeModScan }
                "14" { 
                    Clear-Host
                    Invoke-Typewriter "`n       [!] CERRANDO CONEXIÓN. HASTA LUEGO, JOAQUÍN.`n" -Color Red
                    return 
                }
                default { 
                    Write-Host "`n       [!] Entrada no reconocida en el sistema." -ForegroundColor Red
                    Start-Sleep -Seconds 1 
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
Show-MainMenu
