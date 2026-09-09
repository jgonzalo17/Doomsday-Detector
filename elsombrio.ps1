#Requires -Version 5.1
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# EL SOMBRIO IF - FORENSIC SCANNER (MASTER V42 - TROLL REALISTA)
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
        Write-Host "`n       [Bootloader] $($bootSteps[$stepIndex])" -ForegroundColor Cyan
        
        $pct = [math]::Round((($i + 1) / 15) * 100)
        $barLength = 40
        $filled = [math]::Round(($pct / 100) * $barLength)
        $empty = $barLength - $filled
        $progressBar = "█" * $filled + "▒" * $empty
        
        Write-Host "       [System]     $pct% [$progressBar]" -ForegroundColor Magenta
        Start-Sleep -Milliseconds 120
    }
    Write-Host "`n       [OK] INTERFAZ LISTA. TODOS LOS MÓDULOS CARGADOS Y SEGUROS.`n" -ForegroundColor Green
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
    Write-Host "                   [ ADVANCED FORENSIC SCANNER ]                `n" -ForegroundColor DarkGray
}

function Show-Header {
    param([string]$Subtitle)
    Clear-Host
    Write-Host "`n       ╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkBlue
    Write-Host "       ║                  EL SOMBRIO IF - FORENSIC SCANNER                     ║" -ForegroundColor Cyan
    Write-Host "       ╠═══════════════════════════════════════════════════════════════════════╣" -ForegroundColor DarkBlue
    $pad = [math]::Max(0, [math]::Floor((71 - $Subtitle.Length) / 2))
    $str = ((' ' * $pad) + $Subtitle).PadRight(71, ' ')
    Write-Host ("       ║{0}║" -f $str) -ForegroundColor White
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor DarkBlue
}

function Pause-Scanner {
    Write-Host "`n       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Invoke-Typewriter "       [ Presiona ENTER para regresar al menú principal ]" -Speed 10 -Color DarkGray
    Read-Host | Out-Null
}

function Show-DetectionBox {
    param([array]$Detections, [string]$Title, [bool]$IsDanger = $false)
    $borderColor = if ($IsDanger -or ($Detections | Where-Object { $_ -match "HACK|TE VAS BAN|ILEGAL" })) { "Red" } else { "DarkGray" }
    
    Write-Host "`n       ╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $borderColor
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
            $itemStr = (" > " + $displayStr).PadRight(71, ' ')
            
            $textColor = "Yellow"
            if ($item -match "HACK|TE VAS BAN|ILEGAL|PELIGRO") { $textColor = "Red" }
            elseif ($item -match "\[JAVA\]|java\.exe|javaw\.exe|lunarclient") { $textColor = "Cyan" }
            elseif ($item -match "\[NORMAL\]|\[ELIMINADO\]|APROBADO") { $textColor = "Green" }
            
            Write-Host "       ║$itemStr║" -ForegroundColor $textColor
        }
    }
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $borderColor
    
    if ($Detections.Count -gt 0) {
        Write-Host "`n       [ ❖ ] LOG DETALLADO Y RUTAS:" -ForegroundColor Cyan
        Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($item in $Detections) { 
            $textColor = "Gray"
            if ($item -match "HACK|TE VAS BAN|ILEGAL|PELIGRO") { $textColor = "Red" }
            elseif ($item -match "\[JAVA\]|java\.exe|javaw\.exe|lunarclient") { $textColor = "Cyan" }
            elseif ($item -match "\[NORMAL\]|\[ELIMINADO\]|APROBADO") { $textColor = "Green" }
            Write-Host "       -> $item" -ForegroundColor $textColor 
        }
    }
}

function Test-Administrator { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

# ============================================================
# MÓDULOS DE ESCANEO
# ============================================================
function Start-FullModScan {
    Show-Header "ANÁLISIS AVANZADO DE MODS (MEOW MOD ANALYZER)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
        $url = "https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1"
        $scriptContent = Invoke-RestMethod -Uri $url -UseBasicParsing
        $scriptBlock = [ScriptBlock]::Create($scriptContent)
        & $scriptBlock
    } catch { Write-Host "`n       [!] Error: $($_.Exception.Message)" -ForegroundColor Red }
    Pause-Scanner
}

function Start-DoomsdayMemoryScan {
    Show-Header "DETECCIÓN PROFUNDA (DOOMSDAY DETECTOR)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
        $url = "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1"
        $scriptContent = Invoke-RestMethod -Uri $url -UseBasicParsing
        $scriptBlock = [ScriptBlock]::Create($scriptContent)
        & $scriptBlock
    } catch { Write-Host "`n       [!] Error: $($_.Exception.Message)" -ForegroundColor Red }
    Pause-Scanner
}

function Start-SystemScan {
    Show-Header "INTERVENCIÓN RÁPIDA (PREFETCH Y BAM)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador para leer Prefetch."; Pause-Scanner; return }
    Write-Host "       [ ❖ ] ESTADO DEL MOTOR PREFETCH" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    try {
        $pfVal = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -ErrorAction SilentlyContinue
        if ($pfVal -eq 0) { Write-Host "       [!] ESTADO: DESHABILITADO (Altamente Sospechoso / Evidencia Borrada)" -ForegroundColor Red }
        elseif ($pfVal -eq 3) { Write-Host "       [+] ESTADO: HABILITADO (Normal y Funcionando)" -ForegroundColor Green }
        else { Write-Host "       [*] ESTADO: MODIFICADO (Valor inusual: $pfVal)" -ForegroundColor Yellow }
    } catch { Write-Host "       [*] ESTADO: NO SE PUDO LEER" -ForegroundColor Yellow }
    Write-Host ""
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    $list = @()
    $pfFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue
    if ($pfFiles) {
        $pfFiles | Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-1) } | 
        ForEach-Object { $list += [PSCustomObject]@{ Time = $_.LastWriteTime; Name = $_.Name } }
        $list = $list | Sort-Object Time -Descending | Select-Object -First 30
        foreach ($item in $list) {
            $timeStr = $item.Time.ToString("HH:mm:ss")
            if ($script:RxHacks.IsMatch($item.Name)) {
                $hallazgos.Add("[HACK - TE VAS BAN] HORA: $timeStr -> $($item.Name)")
            } elseif ($script:RxMcProcess.IsMatch($item.Name)) {
                $hallazgos.Add("[JAVA] HORA: $timeStr -> $($item.Name)")
            } else {
                $hallazgos.Add("[NORMAL] HORA: $timeStr -> $($item.Name)")
            }
        }
    } else {
         $hallazgos.Add("[!] La carpeta Prefetch está completamente vacía o el acceso fue denegado.")
    }
    Show-DetectionBox -Detections $hallazgos -Title "ÚLTIMAS 30 EJECUCIONES (MÁS RECIENTES)"
    Pause-Scanner
}

function Start-RecycleBinScan {
    Show-Header "ANÁLISIS DE PAPELERA DE RECICLAJE"
    $hallazgosPapelera = [System.Collections.Generic.List[string]]::new()
    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        foreach ($item in $papelera.Items()) {
            if ($script:RxHacks.IsMatch($item.Name)) { 
                $hallazgosPapelera.Add("[HACK BORRADO - TE VAS BAN] $($item.Name) | Ruta: $($item.Path)") 
            } else {
                $hallazgosPapelera.Add("[ELIMINADO] $($item.Name)")
            }
        }
    } catch {}
    Show-DetectionBox -Detections $hallazgosPapelera -Title "LISTA DE ARCHIVOS ELIMINADOS"
    Pause-Scanner
}

function Start-MacroAutoclickScan {
    Show-Header "AUDITORÍA UNIFICADA: MACROS Y AUTOCLICKERS"
    $hallazgos = [System.Collections.Generic.List[string]]::new()

    Write-Host "       [ ❖ ] FASE 1: SOFTWARE DE MACROS/PERIFÉRICOS INSTALADO" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $knownPaths = @(
        @{ Path = "$env:USERPROFILE\AppData\Local\Logitech\Logitech Gaming Software\settings.json"; Name = "Logitech Gaming Software" },
        @{ Path = "$env:USERPROFILE\AppData\Local\LGHUB\settings.db"; Name = "Logitech G HUB" },
        @{ Path = "C:\Program Files (x86)\Bloody7\Bloody7\Data\Mouse\English\ScriptsMacros\GunLib\"; Name = "Bloody Macro Suite" },
        @{ Path = "$env:ProgramFiles\Razer\Synapse3\Config"; Name = "Razer Synapse 3" },
        @{ Path = "${env:ProgramFiles(x86)}\Razer\Synapse2\Config"; Name = "Razer Synapse 2" },
        @{ Path = "$env:ProgramFiles\Corsair\CORSAIR iCUE Software"; Name = "Corsair iCUE" },
        @{ Path = "${env:ProgramFiles(x86)}\SteelSeries\SteelSeries Engine 3"; Name = "SteelSeries Engine" },
        @{ Path = "$env:APPDATA\AutoHotkey"; Name = "AutoHotkey (config/scripts)" },
        @{ Path = "$env:USERPROFILE\Documents\Pulover's Macro Creator"; Name = "Pulover's Macro Creator" },
        @{ Path = "$env:LOCALAPPDATA\TinyTask"; Name = "TinyTask" }
    )
    foreach ($kp in $knownPaths) {
        if (Test-Path $kp.Path) {
            $hallazgos.Add("[SOFTWARE MACRO INSTALADO] $($kp.Name) | Ruta: $($kp.Path)")
            Write-Host "       [!] Detectado: $($kp.Name)" -ForegroundColor Yellow
        }
    }
    Write-Host "       [*] Fase 1 completa.`n" -ForegroundColor White

    Write-Host "       [ ❖ ] FASE 2: PROCESOS ACTIVOS EN MEMORIA" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $activeProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $script:RxMacroCritical.IsMatch($_.Name) }
    if ($activeProcs) {
        foreach ($proc in $activeProcs) {
            Write-Host "       [!] Proceso activo: $($proc.Name).exe (PID: $($proc.Id)) - TE VAS BAN" -ForegroundColor Red
            $hallazgos.Add("[PROCESO ACTIVO - TE VAS BAN] $($proc.Name).exe (PID: $($proc.Id)) | Ruta: Memoria (Activo)")
        }
    } else {
        Write-Host "       [+] Ningún proceso de macro/autoclick corriendo actualmente." -ForegroundColor Green
    }
    Write-Host "       [*] Fase 2 completa.`n" -ForegroundColor White

    Write-Host "       [ ❖ ] FASE 3: ESCANEO PROFUNDO DE DISCO" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } | Select-Object -ExpandProperty Root

    $allDirs = @()
    foreach ($drive in $drives) {
        $allDirs += Get-ChildItem -Path $drive -Directory -ErrorAction SilentlyContinue
    }
    $totalDirs = $allDirs.Count
    $dirCount = 0

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
            elseif (-not $script:RxPathWhitelist.IsMatch($_.FullName) -and $script:RxMacroSuspect.IsMatch($_.Name)) {
                $hallazgos.Add("[ARCHIVO SOSPECHOSO - REVISAR] $($_.Name) | Ruta: $($_.FullName)")
            }
        }
    }
    Write-Host "`n       [*] Fase 3 completa.`n" -ForegroundColor White

    Show-DetectionBox -Detections $hallazgos -Title "RESULTADOS: MACROS Y AUTOCLICKERS (COMPLETO)"
    Pause-Scanner
}

function Start-DiffKiller {
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


# ------------------------------------------------------------
# EASTER EGG: EL DOXEO TROLL MEJORADO (CUADROS E IPs)
# ------------------------------------------------------------
function Invoke-Screamer {
    $origBG = $Host.UI.RawUI.BackgroundColor
    $origFG = $Host.UI.RawUI.ForegroundColor

    # Pantalla roja de alerta inicial
    for ($i = 0; $i -lt 4; $i++) {
        $Host.UI.RawUI.BackgroundColor = if ($i % 2 -eq 0) { "Red" } else { "Black" }
        Clear-Host
        try { [console]::Beep(1000, 80) } catch {}
        Start-Sleep -Milliseconds 80
    }

    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    Clear-Host

    # Adaptar variables para no deformar el cuadro
    $uName = $env:USERNAME
    if ($uName.Length -gt 25) { $uName = $uName.Substring(0, 22) + "..." }
    $osName = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($osName.Length -gt 45) { $osName = $osName.Substring(0, 42) + "..." }

    Write-Host "       ╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "       ║               [!] BYPASS DE SEGURIDAD COMPLETADO [!]                  ║" -ForegroundColor Red
    Write-Host "       ╠═══════════════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host ("       ║ > OBJETIVO   : " + $uName).PadRight(79) + "║" -ForegroundColor Green
    Write-Host ("       ║ > SISTEMA    : " + $osName).PadRight(79) + "║" -ForegroundColor Green
    Write-Host ("       ║ > PRIVILEGIOS: NT AUTHORITY\SYSTEM (ESCALADO)").PadRight(79) + "║" -ForegroundColor Green
    Write-Host ("       ║ > ESTADO     : EXTRACCIÓN DE DATOS EN CURSO...").PadRight(79) + "║" -ForegroundColor Green
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Start-Sleep -Seconds 1
    Write-Host "`n       [+] INICIANDO VOLCADO DE RED Y ARCHIVOS..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 500

    Write-Host "       ╔════ [ TRÁFICO DE RED E INTERCEPTACIÓN DE PAQUETES ] ══════════════════╗" -ForegroundColor DarkGray
    for ($i = 0; $i -lt 55; $i++) {
        $randIP = "$((Get-Random -Min 11 -Max 255)).$((Get-Random -Min 0 -Max 255)).$((Get-Random -Min 0 -Max 255)).$((Get-Random -Min 1 -Max 255))"
        $randHex = -join ((48..57) + (65..70) | Get-Random -Count 12 | % {[char]$_})
        $file = @("chrome_logins.db", "discord_token.ldb", "sys_passwords.txt", "sam_dump.hive", "wallet.dat") | Get-Random
        
        $str = "       ║ [DATA] IP: $randIP -> EXTRACCIÓN: $file | HASH: $randHex"
        Write-Host $str.PadRight(79) + "║" -ForegroundColor Green
        Start-Sleep -Milliseconds 25
    }
    Write-Host "       ╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkGray

    Start-Sleep -Milliseconds 500

    Write-Host "`n       [!] EJECUTANDO PROTOCOLO DE DESTRUCCIÓN LOCAL..." -ForegroundColor Red
    for ($i = 1; $i -le 100; $i+=3) {
        $fileStr = -join ((97..122) | Get-Random -Count 8 | % {[char]$_})
        $pct = $i
        if ($pct -gt 100) { $pct = 100 }
        $barLength = 30
        $filled = [math]::Round(($pct / 100) * $barLength)
        $pBar = "█" * $filled + "▒" * ($barLength - $filled)
        
        Write-Host "`r       [ELIMINANDO System32] [$pBar] $pct% (Borrando: $fileStr.dll)   " -NoNewline -ForegroundColor Red
        Start-Sleep -Milliseconds 45
    }
    
    Write-Host "`n       [!] SISTEMA CORRUPTO. REINICIO INMINENTE.`n" -ForegroundColor Red
    Start-Sleep -Seconds 1

    # PANTALLAZO ROJO CON LA CALAVERA GIGANTE
    $Host.UI.RawUI.BackgroundColor = "Red"
    $Host.UI.RawUI.ForegroundColor = "Black"
    Clear-Host

    try { [console]::Beep(800, 400); [console]::Beep(600, 600) } catch {}

    Write-Host @"

                   uuuuuuu
               uu$$$$$$$$$$$uu
            uu$$$$$$$$$$$$$$$$$uu
           u$$$$$$$$$$$$$$$$$$$$$u
          u$$$$$$$$$$$$$$$$$$$$$$$u
         u$$$$$$$$$$$$$$$$$$$$$$$$$u
         u$$$$$$$$$$$$$$$$$$$$$$$$$u
         u$$$$$$"   "$$$"   "$$$$$$u
         "$$$$"      u$u       $$$$"
          $$$u       u$u       u$$$
          $$$u      u$$$u      u$$$
           "$$$$uu$$$   $$$uu$$$$"
            "$$$$$$$"   "$$$$$$$"
              u$$$$$$$u$$$$$$$u
               u$"$"$"$"$"$"$u
    uuu        $$u$ $ $ $ $u$$       uuu
   u$$$$        $$$$$u$u$u$$$       u$$$$
    $$$$$uu      "$$$$$$$$$"     uu$$$$$$
  u$$$$$$$$$$$uu    """""    uuuu$$$$$$$$$$
  $$$$"""$$$$$$$$$$uuu   uu$$$$$$$$$"""$$$"
   """      ""$$$$$$$$$$$uu ""$"""
             uuuu ""$$$$$$$$$$uuu
    u$$$uuu$$$$$$$$$uu ""$$$$$$$$$$$uuu$$$
    $$$$$$$$$$"""           ""$$$$$$$$$$$"
     "$$$$$"                      ""$$$$""
       $$$"                         $$$$"

        ████████████████████████████████████████████████
        █              ¡TE VOY A HACKEAR!              █
        █     TODOS TUS DATOS HAN SIDO COMPROMETIDOS   █
        ████████████████████████████████████████████████

"@

    Start-Sleep -Seconds 3

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
    Show-Header "ESTADO DE SERVICIOS WINDOWS"
    Write-Host "       [ ❖ ] TABLA DE SERVICIOS MONITOREADOS" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ("       {0,-14} {1,-16} {2,-10}" -f "SERVICIO", "ESTADO", "CRÍTICO") -ForegroundColor White
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    $tabla = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($service in $script:WindowsServices) {
        $esCritico = ($service -eq "pcasvc" -or $service -eq "bam" -or $service -eq "sysmain")
        try {
            $estado = (Get-Service -Name $service -ErrorAction Stop).Status.ToString()
        } catch {
            $estado = "NO ENCONTRADO"
        }
        $tabla.Add([PSCustomObject]@{ Servicio = $service; Estado = $estado; Critico = if ($esCritico) { "SI" } else { "NO" } })
    }

    foreach ($row in $tabla) {
        $color = switch ($row.Estado) {
            "Running" { "Green" }
            "Stopped" { "Red" }
            default   { "Yellow" }
        }
        Write-Host ("       {0,-14} {1,-16} {2,-10}" -f $row.Servicio, $row.Estado, $row.Critico) -ForegroundColor $color
    }
    Write-Host ""

    $hallazgosSvc = [System.Collections.Generic.List[string]]::new()
    foreach ($service in $script:WindowsServices) {
        $output = @(& sc.exe query $service 2>&1) -join "`n"
        if ($output -match 'STOPPED' -and ($service -eq "pcasvc" -or $service -eq "bam" -or $service -eq "sysmain")) {
            $hallazgosSvc.Add("SERVICIO APAGADO CRÍTICO: $service")
        }
    }
    Show-DetectionBox -Detections $hallazgosSvc -Title "ALERTAS DE SERVICIOS MODIFICADOS"
    Pause-Scanner
}

function Start-SSToolsHub {
    Show-Header "HUB DE HERRAMIENTAS SS"
    $tools = @(
        [PSCustomObject]@{ Id=1; Name="System Informer"; Url="https://sourceforge.net/projects/systeminformer/files/latest/download"; Icon="✦" }
        [PSCustomObject]@{ Id=2; Name="JournalTrace"; Url="https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe"; Icon="▶" }
    )
    Write-Host "       [ ❖ ] LISTA DE APLICACIONES FORENSES DISPONIBLES" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($t in $tools) { Write-Host "       [ $($t.Id) ] $($t.Icon) $($t.Name)" -ForegroundColor White }
    $choice = (Read-Host "`n       [COMANDO] Ingresa el ID para lanzar (o 0 para salir)").Trim()
    if ($choice -ne "0") {
        $sel = $tools | Where-Object { $_.Id.ToString() -eq $choice }
        if ($sel) {
            Write-Host "       [*] Ejecutando $($sel.Name)..." -ForegroundColor Yellow
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
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    $payloads = @(
        [PSCustomObject]@{ Id=1; Name="Lilith Services"; Url="https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1" },
        [PSCustomObject]@{ Id=2; Name="Ordiff Kill ScreenRecording"; Url="https://raw.githubusercontent.com/Orbdiff/powershell/refs/heads/main/kill-screen-processes.ps1" }
    )
    Write-Host "       [ ❖ ] SCRIPTS REMOTOS (PAYLOADS)" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($p in $payloads) { Write-Host "       [ $($p.Id) ] $($p.Name)" -ForegroundColor White }
    $choice = (Read-Host "`n       [COMANDO] Ingresa el ID para lanzar (o 0 para salir)").Trim()
    if ($choice -ne "0") {
        $sel = $payloads | Where-Object { $_.Id.ToString() -eq $choice }
        if ($sel) {
            Write-Host "       [*] Inyectando payload en memoria..." -ForegroundColor Yellow
            try {
                Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
                & ([ScriptBlock]::Create((Invoke-RestMethod -Uri $sel.Url -UseBasicParsing)))
            } catch { Write-Host "       [!] Error: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
    Pause-Scanner
}

function Start-FullDiskScan {
    Show-Header "ANÁLISIS COMPLETO (MODIFICADOS Y BORRADOS)"
    $hallazgosDisco = [System.Collections.Generic.List[string]]::new()
    Write-Host "       [ ❖ ] FASE 1: ESCANEANDO PAPELERA EN TODOS LOS DISCOS LÓGICOS..." -ForegroundColor Cyan
    $sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    $dTotal = $drives.Count
    $dCount = 0
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
    Write-Host "`n"
    Write-Host "       [ ❖ ] FASE 2: BUSCANDO EJECUTABLES Y MODS RECIENTEMENTE MODIFICADOS..." -ForegroundColor Cyan
    $userDirs = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    $uTotal = $userDirs.Count
    $uCount = 0
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
    Write-Host "`n"
    Show-DetectionBox -Detections $hallazgosDisco -Title "MODIFICADOS Y BORRADOS EN DISCO"
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

function Start-ExtremeModScan {
    Show-Header "ANÁLISIS EXTREMO (PROCESOS, INSTANCIAS Y MODS)"
    if (-not ($script:IsAdmin)) { Write-Host "       [!] Se requiere Administrador."; Pause-Scanner; return }
    $hallazgos = [System.Collections.Generic.List[string]]::new()
    $allProcs = Get-Process -ErrorAction SilentlyContinue

    Write-Host "       [ ❖ ] SEPARACIÓN DE PROCESOS (MEMORIA RAM EN TIEMPO REAL)" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $mcProcs = $allProcs | Where-Object { $script:RxMcProcess.IsMatch($_.Name) }
    $badProcs = $allProcs | Where-Object { $script:RxHacks.IsMatch($_.Name) }
    $otherProcs = $allProcs | Where-Object { -not $script:RxMcProcess.IsMatch($_.Name) -and -not $script:RxHacks.IsMatch($_.Name) }

    if ($mcProcs) {
        Write-Host "       [ INSTANCIAS DE JUEGO / MC ]" -ForegroundColor DarkGray
        foreach ($proc in $mcProcs) {
            Write-Host "       [+] INSTANCIA ACTIVA : $($proc.Name).exe (PID: $($proc.Id))" -ForegroundColor Green
            try {
                $proc.Modules | Where-Object { $script:RxHacks.IsMatch($_.FileName) } | ForEach-Object {
                    Write-Host "           -> [!] INYECCIÓN DETECTADA : $($_.ModuleName) - TE VAS BAN" -ForegroundColor Red
                    Write-Host "           -> [!] RUTA DEL HACK       : $($_.FileName)" -ForegroundColor Red
                    $hallazgos.Add("[INYECCIÓN EN RAM - TE VAS BAN] $($_.ModuleName) | Ruta: $($_.FileName)")
                }
            } catch {}
        }
    } else {
        Write-Host "       [-] INSTANCIAS: No se detectó Minecraft ni Java en ejecución." -ForegroundColor White
    }

    Write-Host ""
    if ($badProcs) {
        Write-Host "       [ PROCESOS EXTERNOS PROHIBIDOS ]" -ForegroundColor DarkGray
        foreach ($proc in $badProcs) {
            Write-Host "       [!] PROCESO HACK     : $($proc.Name).exe (PID: $($proc.Id)) - TE VAS BAN" -ForegroundColor Red
            $hallazgos.Add("[PROCESO EXTERNO - TE VAS BAN] $($proc.Name).exe (PID: $($proc.Id)) | Ruta: Memoria (Activo)")
        }
    } else {
        Write-Host "       [+] EXTERNOS: Ningún proceso catalogado como Hack está abierto." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "       [ PROCESOS DEL SISTEMA (SEGUNDO PLANO) ]" -ForegroundColor DarkGray
    Write-Host "       [*] Sistema Limpio   : $($otherProcs.Count) procesos normales analizados." -ForegroundColor White

    Write-Host "`n       [ ❖ ] ANÁLISIS DE CARPETA DE MODS (.JAR)" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    if (Test-Path $script:DefaultModsPath) {
        $modFiles = Get-ChildItem -Path $script:DefaultModsPath -Recurse -File -Include "*.jar", "*.zip", "*.dll"
        if ($modFiles.Count -gt 0) {
            foreach ($mod in $modFiles) {
                $isBad = $false
                if ($script:RxHacks.IsMatch($mod.Name)) { $isBad = $true }
                if ($mod.LastWriteTime -gt $mod.CreationTime.AddDays(7)) { $isBad = $true }
                if ($mod.Length -lt 15KB) { $isBad = $true }
                if ($isBad) {
                    Write-Host "       [!] MOD ILEGAL O MODIFICADO : $($mod.Name) - TE VAS BAN" -ForegroundColor Red
                    $hallazgos.Add("[MOD ILEGAL - TE VAS BAN] $($mod.Name) | Ruta: $($mod.FullName)")
                } else {
                    Write-Host "       [+] MOD LEGAL APROBADO      : $($mod.Name)" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "       [-] La carpeta de mods está vacía." -ForegroundColor White
        }
    } else {
        Write-Host "       [-] No se encontró carpeta de mods en AppData." -ForegroundColor White
    }

    Write-Host "`n       [ ❖ ] ESTADO DE LA PAPELERA DE RECICLAJE" -ForegroundColor Cyan
    Write-Host "       ─────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.NameSpace(10)
        if ($papelera.Items().Count -gt 0) {
            foreach ($item in $papelera.Items()) {
                if ($script:RxHacks.IsMatch($item.Name)) {
                    Write-Host "       [!] HACK BORRADO : $($item.Name) - TE VAS BAN" -ForegroundColor Red
                    $hallazgos.Add("[PAPELERA HACK - TE VAS BAN] $($item.Name) | Ruta: $($item.Path)")
                } else {
                    Write-Host "       [-] ARCHIVO NORMAL : $($item.Name)" -ForegroundColor White
                }
            }
        } else {
            Write-Host "       [-] La papelera de reciclaje se encuentra vacía." -ForegroundColor White
        }
    } catch {}

    Show-DetectionBox -Detections $hallazgos -Title "RESULTADOS DE ALERTAS DE AUDITORÍA"
    Pause-Scanner
}

# ============================================================
# MENÚ PRINCIPAL (13 MÓDULOS - MACRO/AUTOCLICK UNIFICADO)
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
                "       [  5  ] Macros & Autoclick (ALL)   [ 12  ] Mod & Instancia Extreme   "
                "       [  6  ] Killer Screen (Diff)       [ 13  ] ⚠ NO TOCAR ⚠             "
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
                "5"  { Start-MacroAutoclickScan }
                "05" { Start-MacroAutoclickScan }
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
                "12" { Start-ExtremeModScan }
                "13" { Invoke-Screamer }
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
$script:IsAdmin = Test-Administrator
Show-MainMenu
