#Requires -Version 5.1
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V31)
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

$script:DoomsdayStrings = @(
    "lYgKfQhaCkHofBf", "?WHt4Y", "!hi!kGD@<nS", "%#ksghCP$NIS7$EQuX", "jnativehook"
)

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

function Get-SafeBytes {
    param([string]$Path)
    try { $bytes = [System.IO.File]::ReadAllBytes($Path) } 
    catch {
        try {
            $tempFile = "$env:TEMP\sombrio_scan_$([guid]::NewGuid()).tmp"
            Copy-Item -Path $Path -Destination $tempFile -Force -ErrorAction Stop
            $bytes = [System.IO.File]::ReadAllBytes($tempFile)
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } catch { return $null }
    }
    
    if ($null -ne $bytes -and $bytes.Length -ge 8) {
        if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x41 -and $bytes[2] -eq 0x4D) {
            if (([System.Management.Automation.PSTypeName]'SombrioDecompressor').Type) {
                $decomp = [SombrioDecompressor]::Decompress($bytes)
                if ($null -ne $decomp) { return $decomp }
            }
        }
    }
    return $bytes
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
            if ($item.Length -gt 56) { $item = $item.Substring(0, 53) + "..." }
            $itemStr = (" > " + $item).PadRight(60, ' ')
            Write-Host "     ║$itemStr║" -ForegroundColor Yellow
        }
    }
    Write-Host "     ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
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
    Show-Header "INTERVENCIÓN RÁPIDA (PREFETCH Y BAM)"
    if (-not (Test-Administrator)) { Write-Host "     [!] Se requieren privilegios de Administrador para leer BAM."; Pause-Scanner; return }
    $hallazgosAlertas = [System.Collections.Generic.List[string]]::new()
    $bamPath = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\*"
    foreach ($entry in (Get-ItemProperty $bamPath -ErrorAction SilentlyContinue)) {
        foreach ($p in ($entry.psobject.properties | Where-Object { $_.Name -match "^[a-zA-Z]:\\" })) {
            if ($p.Name.ToLower() -match "click|autoclick|macro|jclicker|ghostclicker|meteor|totem|autototem") {
                $hallazgosAlertas.Add("BAM Oculto: $(Split-Path $p.Name -Leaf)")
            }
        }
    }
    Show-DetectionBox -Detections $hallazgosAlertas -Title "ALERTAS CRÍTICAS EN PREFETCH Y BAM"
    Pause-Scanner
}

function Start-RecycleBinScan {
    Show-Header "ANÁLISIS DE PAPELERA DE RECICLAJE"
    $hallazgosPapelera = [System.Collections.Generic.List[string]]::new()
    try {
        $shell = New-Object -ComObject Shell.Application
        foreach ($item in $shell.NameSpace(10).Items()) {
            if ($item.Name.ToLower() -match "click|macro|ghost|meteor|totem|vape") { $hallazgosPapelera.Add("HACK BORRADO: $($item.Name)") }
        }
    } catch {}
    Show-DetectionBox -Detections $hallazgosPapelera -Title "HACKS DETECTADOS EN LA PAPELERA"
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
    foreach ($p in $pathsToCheck) { if (Test-Path $p) { $hallazgosMacros.Add("Detectado: $(Split-Path $p -Leaf)") } }
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

function Start-DllScan {
    Show-Header "ANÁLISIS DE DLLs MODIFICADAS"
    if (-not (Test-Administrator)) { Write-Host "     [!] Se requiere Administrador."; Pause-Scanner; return }
    $hallazgosDLL = [System.Collections.Generic.List[string]]::new()
    foreach ($file in (Get-ChildItem -Path "$env:SystemRoot\System32" -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-30) })) {
        if ((Get-AuthenticodeSignature $file.FullName -ErrorAction SilentlyContinue).Status -ne 'Valid') {
            $hallazgosDLL.Add("$($file.Name) (Sin Firma)")
        }
    }
    Show-DetectionBox -Detections $hallazgosDLL -Title "DLLs ANÓMALAS (ÚLTIMO MES)"
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
    Show-Header "ANÁLISIS COMPLETO DEL DISCO"
    $hallazgosDisco = [System.Collections.Generic.List[string]]::new()
    foreach ($f in (Get-ChildItem -Path "C:\Users" -Recurse -File -Include "*.jar","*.exe","*.dll" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "clicker|autoclick|ghost|meteor|wurst|vape|raven|dooms" })) {
        $hallazgosDisco.Add("$($f.Name) | Carpeta: $($f.Directory.Name)")
    }
    Show-DetectionBox -Detections $hallazgosDisco -Title "ARCHIVOS SOSPECHOSOS EN DISCO"
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

# ============================================================
# MENÚ PRINCIPAL
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
        "                                                          .:=---::::.   -=+:  .  .--.=."
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
                "       [  1  ] Analizar Mods            [  8  ] Análisis DLLs (1 MES)     "
                "       [  2  ] Doomsday Detector        [  9  ] Hub Herramientas SS       "
                "       [  3  ] Análisis Prefetch/BAM      [ 10  ] Hub Payloads (GitHub)     "
                "       [  4  ] Análisis Papelera          [ 11  ] Análisis Completo Disco   "
                "       [  5  ] Auditoría de Macros        [ 12  ] Rutas Manuales (Win+R)    "
                "       [  6  ] Killer Screen (Diff)       [ 13  ] Salir de Framework        "
                "       [  7  ] Servicios Windows                                      "
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

                    if ($i -ge 12 -and $i -le 24) {
                        Write-Host $girlLine -ForegroundColor DarkCyan
                    } elseif ($i -gt 24 -and $i -le 48) {
                        Write-Host $girlLine -ForegroundColor Blue
                    } else {
                        Write-Host $girlLine -ForegroundColor Cyan
                    }
                } else {
                    Write-Host ""
                }
            }

            Write-Host ""
            $option = (Read-Host "       [ROOT] Selecciona un módulo [1-13]").Trim()

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
                "8"  { Start-DllScan }
                "08" { Start-DllScan }
                "9"  { Start-SSToolsHub }
                "09" { Start-SSToolsHub }
                "10" { Start-RemoteScript }
                "11" { Start-FullDiskScan }
                "12" { Start-WinRCommands }
                "13" { 
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
