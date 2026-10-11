#Requires -Version 5.1
# ============================================================
# MODULO [14] EVASION - EL SOMBRIO IF  (v2: una categoria, detalle expandible)
# Una sola categoria ("Evasion") con 8 secciones + resumen expandible.
# Pegar justo ANTES de la creacion de la ventana (despues de Test-Magic... / Get-SuspiciousAds).
# Usa funciones/variables del script principal: Set-Status, Set-Progress, Invoke-UiPump,
# Test-Administrator, Test-PeSuspicious, Test-MagicMismatch, Test-JarContentSuspicious,
# Find-CheatWindows, $script:RxHacks, $script:RxMacroCritical, $script:RxCheatWindows.
# ============================================================

# --- Configuracion ------------------------------------------
$script:KnownBadHashes = @{
    # "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855" = "Ejemplo"
}
$script:EvasionOnline  = $true    # $true = compara mods con Modrinth (SHA1) y reporta MODIFICADO con detalle
$script:LogEvasion     = [System.Collections.Generic.List[string]]::new()
$script:EvOut          = [System.Collections.Generic.List[string]]::new()
# Estructura para la UI: cada hallazgo puede llevar un bloque de detalle expandible
$script:EvFindings     = [System.Collections.Generic.List[psobject]]::new()
$script:EvNoise        = 'WindowsApps|\\Microsoft\\|\\Packages\\|\\Google\\|\\Discord\\|\\Spotify\\|\\Mozilla\\|\\Code\\|lwjgl|\\JNA\\|\\pip\\|\\npm'

# --- Utilidades ---------------------------------------------
function Add-Ev([string]$Tag, [string]$Name, [string]$Detail, [string]$Path = '', [string[]]$Expand = $null) {
    $d = if ($Path) { "$Detail | Ruta: $Path" } else { $Detail }
    $script:EvOut.Add("[$Tag] $Name | $d")
    # Si hay modificacion o detalle extra, guardar hallazgo estructurado para UI expandible
    if ($Expand -and $Expand.Count -gt 0) {
        $script:EvFindings.Add([pscustomobject]@{
            Tag    = $Tag; Name = $Name; Detail = $d; Path = $Path; Expand = $Expand
        })
        # Sangria en texto plano: abre mas espacio cuando hay modificacion
        foreach ($x in $Expand) { $script:EvOut.Add("      > $x") }
    }
}
function Add-EvHeader([string]$Text) { $script:EvOut.Add("====== $Text ======") }
function Get-EvUserDirs {
    @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:APPDATA", "$env:LOCALAPPDATA\Temp") |
        Select-Object -Unique | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
}
function Get-PeStamp([string]$Path) {
    try {
        $fs = [IO.File]::OpenRead($Path)
        try {
            $br = New-Object IO.BinaryReader($fs)
            if ($br.ReadUInt16() -ne 0x5A4D) { return $null }
            $fs.Position = 0x3C; $pe = $br.ReadInt32()
            $fs.Position = $pe
            if ($br.ReadUInt32() -ne 0x4550) { return $null }
            $fs.Position = $pe + 8
            return [uint32]$br.ReadUInt32()
        } finally { $fs.Dispose() }
    } catch { return $null }
}
function Test-CompiledScript([string]$Path) {
    try {
        $enc = [Text.Encoding]::GetEncoding(28591)
        $s = $enc.GetString([IO.File]::ReadAllBytes($Path))
        if ($s.IndexOf('AutoHotkey', [StringComparison]::OrdinalIgnoreCase) -ge 0) { return 'AutoHotkey' }
        $u = $enc.GetString([Text.Encoding]::Unicode.GetBytes('>AUTOHOTKEY SCRIPT<'))
        if ($s.IndexOf($u, [StringComparison]::Ordinal) -ge 0) { return 'AutoHotkey (script compilado)' }
        if ($s.IndexOf('AU3!EA06', [StringComparison]::Ordinal) -ge 0) { return 'AutoIt compilado' }
    } catch { }
    return $null
}
function ConvertFrom-Rot13([string]$s) {
    -join ($s.ToCharArray() | ForEach-Object {
        $c = [int]$_
        if ($_ -ge 65 -and $_ -le 90)      { [char](($_ - 65 + 13) % 26 + 65) }
        elseif ($_ -ge 97 -and $_ -le 122) { [char](($_ - 97 + 13) % 26 + 97) }
        else { $_ }
    })
}
function Get-DeviceMap {
    $map = @{}
    if (-not ([System.Management.Automation.PSTypeName]'Sombrio.Dos').Type) {
        try { Add-Type -Namespace Sombrio -Name Dos -MemberDefinition '[DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint QueryDosDevice(string lpDeviceName, System.Text.StringBuilder lpTargetPath, int ucchMax);' } catch { return $map }
    }
    foreach ($l in [char[]](65..90)) {
        $sb = New-Object System.Text.StringBuilder 260
        if ([Sombrio.Dos]::QueryDosDevice("${l}:", $sb, 260) -gt 0) { $map[$sb.ToString()] = "${l}:" }
    }
    return $map
}
function Convert-DevicePath([string]$P, $Map) {
    foreach ($k in $Map.Keys) { if ($P.StartsWith($k, [StringComparison]::OrdinalIgnoreCase)) { return $Map[$k] + $P.Substring($k.Length) } }
    return $P
}
# Nuevo: captura hash/firma/fechas para el bloque expandible de modificaciones
function Get-EvFileFacts([System.IO.FileInfo]$File, [string]$PathOverride = '') {
    $facts = [System.Collections.Generic.List[string]]::new()
    $p = if ($PathOverride) { $PathOverride } else { $File.FullName }
    try {
        $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash
        $facts.Add("SHA256: $h")
    } catch { }
    try {
        $s1 = (Get-FileHash -LiteralPath $p -Algorithm SHA1 -ErrorAction Stop).Hash
        $facts.Add("SHA1:   $s1")
    } catch { }
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $p -ErrorAction Stop
        $facts.Add("Firma:  $($sig.Status)" + $(if ($sig.SignerCertificate) { " - $($sig.SignerCertificate.Subject)" }))
    } catch { }
    try { $facts.Add("Tamano: $([math]::Round($File.Length/1KB,1)) KB") } catch { }
    try { $facts.Add("Creado: $($File.CreationTime) | Modificado: $($File.LastWriteTime)") } catch { }
    $ts = Get-PeStamp $p
    if ($null -ne $ts) { $facts.Add("PE timestamp: $(([datetime]'1970-01-01').AddSeconds($ts))") }
    return $facts
}

# --- Revision de un mod (usada en seccion 6), ahora con detalle expandible ---
function Test-ModFile($File) {
    $n = $File.Name
    if ($script:RxHacks.IsMatch($n)) {
        Add-Ev 'SOSPECHOSO' $n 'Nombre coincide con palabra clave de cheat' $File.FullName (Get-EvFileFacts $File)
    }
    $inner = Test-JarContentSuspicious $File.FullName
    if ($inner) {
        Add-Ev 'RENOMBRADO' $n "Contenido interno delata cheat: $inner" $File.FullName (Get-EvFileFacts $File)
    }
    $modId = $null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [IO.Compression.ZipFile]::OpenRead($File.FullName)
        try {
            $meta = $zip.GetEntry('fabric.mod.json')
            if ($meta) {
                $sr = New-Object IO.StreamReader($meta.Open()); try { $txt = $sr.ReadToEnd() } finally { $sr.Dispose() }
                $m = [regex]::Match($txt, '"id"\s*:\s*"([^"]+)"')
                if ($m.Success) {
                    $modId = $m.Groups[1].Value
                    $id = ($modId.ToLower() -replace '[^a-z0-9]', '')
                    $fn = ($File.BaseName.ToLower() -replace '[^a-z0-9]', '')
                    $pre = $id.Substring(0, [math]::Min(5, $id.Length))
                    if ($id -and -not ($fn.Contains($pre) -or $id.Contains($fn.Substring(0, [math]::Min(5, $fn.Length))))) {
                        Add-Ev 'SOSPECHOSO' $n "mod_id '$modId' no coincide con el nombre del archivo" $File.FullName (Get-EvFileFacts $File)
                    }
                }
            } elseif (-not ($zip.GetEntry('META-INF/mods.toml') -or $zip.GetEntry('META-INF/neoforge.mods.toml') -or $zip.GetEntry('quilt.mod.json') -or $zip.GetEntry('mcmod.info'))) {
                Add-Ev 'SOSPECHOSO' $n 'Mod sin metadatos (fabric/forge/quilt)' $File.FullName (Get-EvFileFacts $File)
            }
        } finally { $zip.Dispose() }
    } catch { }
    if ($script:EvasionOnline) {
        try {
            $sha1 = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA1).Hash.ToLower()
            $r = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$sha1" -UserAgent 'ElSombrioIF/2.0' -TimeoutSec 8 -ErrorAction Stop
            if ($r) {
                # Coincide con Modrinth: informar version oficial como referencia anti-modificacion
                Add-Ev 'INFO' $n "Verificado en Modrinth: $($r.project_id) $($r.version_number)" $File.FullName @(
                    "Hash oficial SHA1: $($r.files[0].hashes.sha1)",
                    "Fecha de publicacion oficial: $($r.date_published)",
                    "Este archivo coincide byte a byte con la version oficial (sin modificaciones)"
                )
            }
        } catch {
            $code = $null
            try { $code = [int]$_.Exception.Response.StatusCode } catch { }
            if ($code -eq 404 -or "$($_.Exception.Message)" -match '\b404\b') {
                Add-Ev 'RENOMBRADO' $n 'MODIFICADO: hash no existe en Modrinth' $File.FullName (Get-EvFileFacts $File + @(
                    'Comparacion: el SHA1 de este archivo NO existe en Modrinth',
                    'Conclusion: mod modificado, renombrado o descargado de otra fuente',
                    $(if ($modId) { "mod_id declarado: $modId" })
                ))
            }
        }
    }
}

# ============================================================
# 1. ARCHIVOS RENOMBRADOS / DISFRAZADOS
# ============================================================
function Invoke-Ev1 {
    Add-EvHeader "1. ARCHIVOS RENOMBRADOS / DISFRAZADOS"
    Set-Status "Evasion 1/8: hashes, firmas y contenedores anidados..."
    $now = Get-Date; $sigCount = 0; $hits = 0
    foreach ($d in (Get-EvUserDirs)) {
        if ($script:CancelRequested) { return }
        $files = Get-ChildItem -LiteralPath $d -Recurse -File -Depth 2 -Include *.exe, *.dll, *.jar, *.zip -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $now.AddDays(-60) -and $_.Length -lt 150MB -and $_.FullName -notmatch $script:EvNoise } |
            Select-Object -First 250
        foreach ($f in $files) {
            Invoke-UiPump
            $ext = $f.Extension.ToLower()
            if ($script:KnownBadHashes.Count -gt 0) {
                $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
                if ($h -and $script:KnownBadHashes.ContainsKey($h)) {
                    Add-Ev 'CRITICO' $f.Name "Hash SHA256 coincide con cliente conocido: $($script:KnownBadHashes[$h])" $f.FullName (Get-EvFileFacts $f); $hits++; continue
                }
            }
            $mm = Test-MagicMismatch $f.FullName $ext
            if ($mm) {
                Add-Ev 'CRITICO' $f.Name "EXTENSION FALSA: $mm" $f.FullName (Get-EvFileFacts $f); $hits++
            }
            if ($ext -in '.exe', '.dll') {
                $pe = Test-PeSuspicious $f.FullName
                if ($pe) { Add-Ev 'RENOMBRADO' $f.Name "Metadatos PE delatan: $pe" $f.FullName (Get-EvFileFacts $f); $hits++ }
                if ($sigCount -lt 120) {
                    $sigCount++
                    $sig = Get-AuthenticodeSignature -LiteralPath $f.FullName -ErrorAction SilentlyContinue
                    if ($sig.Status -eq 'HashMismatch') {
                        Add-Ev 'CRITICO' $f.Name 'ARCHIVO MODIFICADO: firma digital invalida (manipulado tras firmar)' $f.FullName (Get-EvFileFacts $f); $hits++
                    } elseif ($sig.Status -eq 'NotSigned') {
                        Add-Ev 'SOSPECHOSO' $f.Name 'Ejecutable sin firma digital' $f.FullName (Get-EvFileFacts $f); $hits++
                    }
                }
                $ts = Get-PeStamp $f.FullName
                if ($null -ne $ts) {
                    $dt = ([datetime]'1970-01-01').AddSeconds($ts)
                    if ($ts -eq 0 -or $dt -gt $now -or $dt.Year -lt 2000) {
                        Add-Ev 'SOSPECHOSO' $f.Name "Fecha de compilacion PE anomala ($dt)" $f.FullName (Get-EvFileFacts $f); $hits++
                    }
                }
            }
            if ($ext -in '.zip', '.jar' -and $f.Length -lt 40MB) {
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                    $zip = [IO.Compression.ZipFile]::OpenRead($f.FullName)
                    try {
                        foreach ($e in $zip.Entries) {
                            $en = $e.FullName.ToLower()
                            if ($en -match '\.exe$' -or ($ext -eq '.zip' -and $en -match '\.jar$')) {
                                Add-Ev 'SOSPECHOSO' $f.Name "Archivo anidado dentro del contenedor: $($e.FullName)" $f.FullName @(
                                    "Entrada anidada: $($e.FullName) ($([math]::Round($e.Length/1KB,1)) KB comprimidos)",
                                    "Archivo contenedor modificado el $($f.LastWriteTime)"
                                ); $hits++; break
                            }
                        }
                    } finally { $zip.Dispose() }
                } catch { }
            }
        }
    }
    if ($hits -eq 0) { Add-Ev 'OK' 'Sin hallazgos' 'Ningun archivo disfrazado o sin firma en carpetas del usuario' }
}

# ============================================================
# 2. BORRADO DE EVIDENCIAS
# ============================================================
function Invoke-Ev2 {
    Add-EvHeader "2. BORRADO DE EVIDENCIAS"
    Set-Status "Evasion 2/8: logs, Prefetch, Papelera, historial..."
    $hits = 0
    foreach ($q in @(@{ L = 'Security'; I = 1102; T = 'Log de SEGURIDAD limpiado' }, @{ L = 'System'; I = 104; T = 'Log de SISTEMA limpiado' })) {
        try {
            foreach ($e in (Get-WinEvent -FilterHashtable @{ LogName = $q.L; Id = $q.I } -MaxEvents 3 -ErrorAction Stop)) {
                $tag = if ($e.TimeCreated -gt (Get-Date).AddDays(-7)) { 'CRITICO' } else { 'SOSPECHOSO' }
                Add-Ev $tag $q.T "ID $($q.I) el $($e.TimeCreated)" '' @(
                    "Evento $($q.L)/$($q.I) registrado el $($e.TimeCreated)",
                    $(if ($e.Message) { "Mensaje: $($e.Message.Substring(0, [math]::Min(200, $e.Message.Length)))" })
                ); $hits++
            }
        } catch { }
    }
    try {
        $pf = @(Get-ChildItem "$env:windir\Prefetch" -Filter *.pf -ErrorAction Stop)
        if ($pf.Count -lt 20) {
            Add-Ev 'SOSPECHOSO' 'Prefetch casi vacio' "Solo $($pf.Count) archivos .pf (equipo en uso normal tiene cientos)" '' @(
                "Archivos .pf encontrados: $($pf.Count)",
                $(if ($pf) { "Mas reciente: $(($pf | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name)" })
            ); $hits++
        }
        $wipe = '(?i)CCLEANER|BLEACHBIT|ERASER|SDELETE|HARDWIPE|EVIDENCE'
        foreach ($p in ($pf | Where-Object { $_.Name -match $wipe })) {
            Add-Ev 'CRITICO' $p.Name 'Herramienta de borrado seguro ejecutada (Prefetch)' $p.FullName @(
                "Ejecutado segun Prefetch: $($p.LastWriteTime)",
                "El .pf sobrevive al propio borrado: evidencia de ejecucion"
            ); $hits++
        }
    } catch { Add-Ev 'SOSPECHOSO' 'Prefetch inaccesible' 'No se pudo leer la carpeta (sin admin o borrada?)'; $hits++ }
    try {
        $ep = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' -ErrorAction Stop).EnablePrefetcher
        if ($ep -eq 0) { Add-Ev 'CRITICO' 'Prefetch DESACTIVADO' 'EnablePrefetcher = 0 (evidencia de ejecucion deshabilitada)'; $hits++ }
    } catch { }
    foreach ($rk in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        Get-ItemProperty $rk -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '(?i)CCleaner|BleachBit|Eraser|Privazer|Wise Disk|File Shredder' } |
            ForEach-Object { Add-Ev 'SOSPECHOSO' $_.DisplayName 'Software de limpieza/borrado instalado'; $hits++ }
    }
    try {
        foreach ($rb in (Get-ChildItem 'C:\$Recycle.Bin' -Force -Directory -ErrorAction Stop)) {
            $cnt = @(Get-ChildItem -LiteralPath $rb.FullName -Force -ErrorAction SilentlyContinue).Count
            if ($rb.LastWriteTime -gt (Get-Date).AddHours(-2) -and $cnt -eq 0) {
                Add-Ev 'SOSPECHOSO' 'Papelera vaciada hace poco' "Ultima modificacion $($rb.LastWriteTime) y esta vacia" '' @(
                    "Ultimo cambio en C:\`$Recycle.Bin: $($rb.LastWriteTime)",
                    "Contenido actual: $cnt elementos",
                    "Vaciamiento dentro de las ultimas 2 horas del escaneo"
                ); $hits++
            }
        }
    } catch { }
    $hist = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (-not (Test-Path -LiteralPath $hist)) {
        Add-Ev 'SOSPECHOSO' 'Historial de PowerShell ausente' 'ConsoleHost_history.txt no existe (borrado o nunca usado)'; $hits++
    } else {
        $hi = Get-Item -LiteralPath $hist
        if ($hi.Length -lt 50) {
            Add-Ev 'SOSPECHOSO' 'Historial de PowerShell vacio' "Tamano $($hi.Length) bytes" $hist @(
                "Tamano real: $($hi.Length) bytes",
                "Ultima escritura: $($hi.LastWriteTime)"
            ); $hits++
        } elseif ($hi.LastWriteTime -lt (Get-Date).AddDays(-60)) {
            Add-Ev 'INFO' 'Historial de PowerShell antiguo' "Ultima escritura $($hi.LastWriteTime)" $hist
        }
    }
    if ($hits -eq 0) { Add-Ev 'OK' 'Sin hallazgos' 'No hay senales de limpieza de evidencias' }
}

# ============================================================
# 3. MANIPULACION DEL TIEMPO
# ============================================================
function Invoke-Ev3 {
    Add-EvHeader "3. MANIPULACION DEL TIEMPO"
    Set-Status "Evasion 3/8: hora del sistema, uptime, fechas..."
    $hits = 0; $now = Get-Date
    try {
        foreach ($e in (Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4616; StartTime = $now.AddDays(-7) } -MaxEvents 50 -ErrorAction Stop)) {
            $proc = [string]$e.Properties[7].Value
            if ($proc -notmatch 'svchost\.exe$') {
                Add-Ev 'CRITICO' 'Cambio de hora del sistema' "Evento 4616 el $($e.TimeCreated) por $proc" '' @(
                    "Evento 4616 registrado el $($e.TimeCreated)",
                    "Proceso que cambio la hora: $proc",
                    "Hora anterior reportada por el evento: $($e.Properties[5].Value) -> $($e.Properties[4].Value)"
                ); $hits++
            }
        }
    } catch { }
    try {
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $up = $now - $boot
        $txt = "Ultimo arranque: $boot ($([math]::Round($up.TotalMinutes)) min de actividad)"
        if ($up.TotalMinutes -lt 30) {
            Add-Ev 'SOSPECHOSO' 'Uptime muy bajo' "$txt - reinicio justo antes del control" '' @(
                "Ultimo arranque: $boot",
                "Minutos de actividad: $([math]::Round($up.TotalMinutes))",
                "Un reinicio inmediatamente anterior al control puede ocultar procesos inyectados"
            ); $hits++
        } else { Add-Ev 'INFO' 'Uptime' $txt }
    } catch { }
    try {
        $w32 = (& w32tm /query /status 2>$null) -join ' '
        if ($w32 -match 'Last Successful Sync Time:\s*([^\r\n]+?)\s{2,}|Ultima hora de sincronizacion correcta:\s*([^\r\n]+)') { Add-Ev 'INFO' 'Servicio de hora' 'Sincronizacion registrada, compara con la hora real' }
    } catch { }
    foreach ($d in @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:APPDATA\.minecraft\mods")) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        Get-ChildItem -LiteralPath $d -File -Recurse -Depth 1 -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $now.AddMinutes(5) -or $_.CreationTime -gt $now.AddMinutes(5) } | Select-Object -First 20 |
            ForEach-Object {
                Add-Ev 'CRITICO' $_.Name "Fecha FUTURA (mod. $($_.LastWriteTime), creado $($_.CreationTime))" $_.FullName @(
                    "Creacion: $($_.CreationTime)",
                    "Ultima modificacion: $($_.LastWriteTime)",
                    "Hora actual del sistema: $now",
                    "Fecha futura = manipulacion de timestamp para esconder el archivo"
                ); $hits++
            }
    }
    if ($hits -eq 0) { Add-Ev 'OK' 'Sin hallazgos' 'Sin cambios de hora ni fechas incoherentes' }
}

# ============================================================
# 4. EJECUCION SIN RASTRO EN DISCO
# ============================================================
function Invoke-Ev4 {
    Add-EvHeader "4. EJECUCION SIN RASTRO EN DISCO"
    Set-Status "Evasion 4/8: argumentos de Java, DLL, USB, VM..."
    $hits = 0
    foreach ($p in (Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" -ErrorAction SilentlyContinue)) {
        $cl = [string]$p.CommandLine
        foreach ($m in [regex]::Matches($cl, '-javaagent:[^\s"]+|-Xbootclasspath[^\s"]*|-agentpath:[^\s"]+|-agentlib:[^\s"]+|-Xrunjdwp[^\s"]*|-noverify|-XX:\+DisableAttachMechanism')) {
            Add-Ev 'SOSPECHOSO' "Argumento de Java (PID $($p.ProcessId))" "Parametro peligroso: $($m.Value)" '' @(
                "PID: $($p.ProcessId) | Proceso: $($p.Name)",
                "Linea de comandos completa: $cl",
                "Parametro detectado: $($m.Value)"
            ); $hits++
        }
        try {
            $proc = Get-Process -Id $p.ProcessId -ErrorAction Stop; $n = 0
            foreach ($mod in $proc.Modules) {
                $fn = $mod.FileName
                if ($fn -match '(?i)\\Windows\\|\\Program Files|\\\.minecraft\\|\\runtime\\|lwjgl|jna|glfw|openal|jemalloc') { continue }
                if ($fn -notmatch '\.dll$') { continue }
                if (++$n -gt 40) { break }
                $sig = Get-AuthenticodeSignature -LiteralPath $fn -ErrorAction SilentlyContinue
                if ($sig.Status -ne 'Valid') {
                    Add-Ev 'CRITICO' "DLL cargada en Java (PID $($p.ProcessId))" "Sin firma valida: $($mod.ModuleName)" $fn @(
                        "Modulo: $($mod.ModuleName)",
                        "Ruta completa: $fn",
                        "Estado de firma: $($sig.Status)",
                        "DLL inyectada en el proceso de Minecraft (inyeccion clasica de cheats)"
                    ); $hits++
                }
            }
        } catch { }
    }
    $skip = '^(Idle|System|Registry|Memory Compression|Secure System|smss|csrss|wininit|MsMpEng|vmmem|NisSrv)$'
    foreach ($pr in (Get-Process -ErrorAction SilentlyContinue | Where-Object { -not $_.Path -and $_.Name -notmatch $skip } | Select-Object -First 15)) {
        Add-Ev 'INFO' "Proceso sin archivo visible: $($pr.Name)" "PID $($pr.Id) - revisar a mano (puede ser protegido o inyeccion)"
    }
    try {
        foreach ($u in (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*\*' -ErrorAction Stop | Where-Object { $_.FriendlyName })) {
            Add-Ev 'INFO' 'USB conectado alguna vez' $u.FriendlyName
        }
    } catch { }
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        if (("$($cs.Manufacturer) $($cs.Model)") -match '(?i)vmware|virtualbox|virtual machine|qemu|kvm|xen|parallels') {
            Add-Ev 'CRITICO' 'Maquina virtual' "$($cs.Manufacturer) $($cs.Model)" '' @(
                "Fabricante: $($cs.Manufacturer) | Modelo: $($cs.Model)",
                "El cheat puede correr en la VM mientras Minecraft esta en el host"
            ); $hits++
        }
    } catch { }
    $rx = '(?i)^(vmtoolsd|vmware.*|vboxservice|vboxtray|anydesk|teamviewer.*|parsec.*|rustdesk|ultraviewer.*|quicksupport|rdpclip|remoting_host)$'
    foreach ($pr in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $rx })) {
        Add-Ev 'SOSPECHOSO' "Escritorio remoto / VM: $($pr.Name)" "PID $($pr.Id)" $pr.Path @(
            "Proceso: $($pr.Name) (PID $($pr.Id))",
            $(if ($pr.Path) { "Ruta: $($pr.Path)" }),
            "Posible control del PC desde otro equipo durante el escaneo"
        ); $hits++
    }
    if ($hits -eq 0) { Add-Ev 'OK' 'Sin hallazgos' 'Java sin agentes ni DLL sospechosas, sin VM ni escritorio remoto' }
}

# ============================================================
# 5. PROGRAMAS ESCONDIDOS Y HUELLAS DE EJECUCION
# ============================================================
function Invoke-Ev5 {
    Add-EvHeader "5. PROGRAMAS ESCONDIDOS / HUELLAS DE EJECUCION"
    Set-Status "Evasion 5/8: ventanas, BAM, UserAssist, autoarranque..."
    $hits = 0; $now = Get-Date
    foreach ($pr in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -and $script:RxCheatWindows.IsMatch($_.MainWindowTitle) })) {
        Add-Ev 'CRITICO' 'VENTANA CHEAT (incluye minimizadas)' "$($pr.MainWindowTitle) - $($pr.Name)" $pr.Path @(
            "Titulo de ventana: $($pr.MainWindowTitle)",
            "Proceso: $($pr.Name) (PID $($pr.Id))",
            $(if ($pr.Path) { "Ruta: $($pr.Path)" }),
            "Estado de la ventana: minimizada/oculta tambien cuenta"
        ); $hits++
    }
    try { foreach ($t in (Find-CheatWindows)) { Add-Ev 'CRITICO' 'VENTANA CHEAT visible' $t; $hits++ } } catch { }
    $sysOk = @{ 'svchost.exe' = 'System32'; 'csrss.exe' = 'System32'; 'lsass.exe' = 'System32'; 'winlogon.exe' = 'System32'; 'services.exe' = 'System32'; 'smss.exe' = 'System32'; 'wininit.exe' = 'System32'; 'explorer.exe' = '' }
    foreach ($pr in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        $n = $pr.Name.ToLower()
        if ($sysOk.ContainsKey($n) -and $pr.ExecutablePath) {
            $exp = if ($sysOk[$n]) { "$env:windir\$($sysOk[$n])\$n" } else { "$env:windir\$n" }
            if ($pr.ExecutablePath -ine $exp) {
                Add-Ev 'CRITICO' "Proceso con nombre de sistema falso: $n" "Corre desde ruta distinta a la oficial (PID $($pr.ProcessId))" $pr.ExecutablePath @(
                    "Nombre del proceso: $n",
                    "Ruta esperada: $exp",
                    "Ruta real: $($pr.ExecutablePath)",
                    "Linea de comandos: $($pr.CommandLine)"
                ); $hits++
            }
        } elseif ($n -match '^(svch0st|scvhost|svhost|lsas|csrs|expl0rer|winlog0n)\.exe$') {
            Add-Ev 'CRITICO' "Nombre imitando proceso de sistema: $n" "PID $($pr.ProcessId)" $pr.ExecutablePath @(
                "Nombre del proceso: $n",
                "Ruta: $($pr.ExecutablePath)",
                "Linea de comandos: $($pr.CommandLine)"
            ); $hits++
        }
    }
    # BAM: que se ejecuto (incluso si ya no esta en disco)
    try {
        $map = Get-DeviceMap; $gone = 0
        $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings'
        foreach ($sid in (Get-ChildItem $base -ErrorAction Stop)) {
            foreach ($vn in $sid.GetValueNames()) {
                if ($vn -notlike '\Device\*') { continue }
                $bytes = $sid.GetValue($vn)
                $when = try { [datetime]::FromFileTimeUtc([BitConverter]::ToInt64($bytes, 0)).ToLocalTime() } catch { $null }
                $real = Convert-DevicePath $vn $map
                $leaf = [IO.Path]::GetFileName($real)
                if ($script:RxMacroCritical.IsMatch($leaf) -or $script:RxHacks.IsMatch($leaf)) {
                    Add-Ev 'CRITICO' "BAM: ejecutado $leaf" "Ultima ejecucion: $when" $real @(
                        "Registrado en BAM: $real",
                        "Ultima ejecucion: $when",
                        "BAM sobrevive al cierre y borrado del programa"
                    ); $hits++
                } elseif ($when -and $when -gt $now.AddDays(-3) -and $real -match '(?i)\\Users\\.*\.(exe|jar|dll)$' -and -not (Test-Path -LiteralPath $real) -and $gone -lt 25) {
                    $gone++
                    Add-Ev 'SOSPECHOSO' "BAM: ELIMINADO SOSPECHOSO $leaf" "Ejecutado el $when y ya no existe en disco" $real @(
                        "Ruta registrada: $real",
                        "Ejecutado el: $when",
                        "Estado: ARCHIVO BORRADO (ejecutado y eliminado = patron clasico de evasion)"
                    ); $hits++
                }
            }
        }
    } catch { Add-Ev 'INFO' 'BAM no disponible' 'Requiere administrador / Windows 10 1809+' }
    # UserAssist
    try {
        foreach ($k in (Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist' -ErrorAction Stop)) {
            $c = Get-Item -LiteralPath "$($k.PSPath)\Count" -ErrorAction SilentlyContinue
            if (-not $c) { continue }
            foreach ($vn in $c.GetValueNames()) {
                $dec = ConvertFrom-Rot13 $vn
                $leaf = [IO.Path]::GetFileName($dec)
                if ($script:RxMacroCritical.IsMatch($leaf) -or $script:RxHacks.IsMatch($leaf)) {
                    $data = $c.GetValue($vn); $when = $null
                    if ($data.Length -ge 68) { try { $when = [datetime]::FromFileTime([BitConverter]::ToInt64($data, 60)) } catch { } }
                    Add-Ev 'SOSPECHOSO' "UserAssist: $leaf" "Ejecutado via Explorer. Ultima vez: $when" $dec @(
                        "Entrada UserAssist: $dec",
                        "Ultima ejecucion via Explorer: $when",
                        "UserAssist registra doble clic, aunque el archivo ya no exista"
                    ); $hits++
                }
            }
        }
    } catch { }
    if (Test-Path "$env:windir\appcompat\Programs\Amcache.hve") {
        Add-Ev 'INFO' 'Amcache.hve presente' "Modificado $((Get-Item "$env:windir\appcompat\Programs\Amcache.hve" -Force).LastWriteTime) - analizar con AmcacheParser"
    }
    # Autoarranque
    foreach ($rk in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce') {
        $props = Get-ItemProperty $rk -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($pp in $props.PSObject.Properties) {
            if ($pp.Name -like 'PS*') { continue }
            $v = [string]$pp.Value
            if ($script:RxMacroCritical.IsMatch($v) -or $script:RxHacks.IsMatch($v) -or $v -match '(?i)\\Temp\\|\\Downloads\\') {
                Add-Ev 'CRITICO' "AUTOARRANQUE: $($pp.Name)" "$rk -> $v" '' @(
                    "Clave: $rk",
                    "Entrada: $($pp.Name)",
                    "Comando: $v"
                ); $hits++
            }
        }
    }
    foreach ($sd in "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp") {
        Get-ChildItem -LiteralPath $sd -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } |
            ForEach-Object { $t = if ($script:RxMacroCritical.IsMatch($_.Name) -or $_.Extension -in '.ahk', '.vbs', '.bat', '.scr') { 'CRITICO' } else { 'INFO' }
                Add-Ev $t "Carpeta de Inicio: $($_.Name)" 'Archivo en carpeta de Inicio' $_.FullName @(
                    "Archivo: $($_.FullName)",
                    "Modificado el: $($_.LastWriteTime)"
                ); if ($t -eq 'CRITICO') { $hits++ } }
    }
    try {
        foreach ($tk in (Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })) {
            foreach ($a in $tk.Actions) {
                $cmd = "$($a.Execute) $($a.Arguments)"
                if ($script:RxMacroCritical.IsMatch($cmd) -or $script:RxHacks.IsMatch($cmd) -or $cmd -match '(?i)\\Temp\\|\\Downloads\\|\\AppData\\') {
                    Add-Ev 'SOSPECHOSO' "Tarea programada: $($tk.TaskName)" $cmd '' @(
                        "Tarea: $($tk.TaskPath)$($tk.TaskName)",
                        "Accion: $($a.Execute)",
                        "Argumentos: $($a.Arguments)",
                        "Estado: $($tk.State) | Usuario: $($tk.Principal.UserId)"
                    ); $hits++
                }
            }
        }
    } catch { }
    try {
        Get-CimInstance Win32_Service -ErrorAction Stop | Where-Object { $_.PathName -match '(?i)\\Users\\|\\Temp\\|\\AppData\\' } |
            ForEach-Object {
                Add-Ev 'SOSPECHOSO' "Servicio fuera de rutas del sistema: $($_.Name)" $_.PathName '' @(
                    "Servicio: $($_.Name) ($($_.DisplayName))",
                    "Ruta: $($_.PathName)",
                    "Estado: $($_.State) | Inicio: $($_.StartMode)"
                ); $hits++
            }
    } catch { }
    if ($hits -eq 0) { Add-Ev 'OK' 'Sin hallazgos' 'Sin ventanas ni huellas de ejecucion sospechosas' }
}

# ============================================================
# 6. MODS QUE PARECEN LEGALES
# ============================================================
function Invoke-Ev6 {
    Add-EvHeader "6. MODS QUE PARECEN LEGALES"
    Set-Status "Evasion 6/8: mods, carpetas inesperadas, launchers..."
    $hits0 = $script:EvOut.Count
    $mc = "$env:APPDATA\.minecraft"
    if (Test-Path "$mc\mods") {
        Get-ChildItem "$mc\mods" -Filter *.jar -File -ErrorAction SilentlyContinue | Select-Object -First 300 | ForEach-Object { Invoke-UiPump; Test-ModFile $_ }
    }
    foreach ($sub in 'versions', 'resourcepacks', 'shaderpacks', 'config', 'saves') {
        $dir = Join-Path $mc $sub
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        Get-ChildItem -LiteralPath $dir -Recurse -File -Depth 3 -Include *.jar, *.dll, *.exe -ErrorAction SilentlyContinue | Where-Object {
            -not ($sub -eq 'versions' -and ($_.BaseName -eq $_.Directory.Name -or $_.FullName -match '\\natives\\'))
        } | Select-Object -First 30 | ForEach-Object {
            Add-Ev 'SOSPECHOSO' $_.Name "Archivo ejecutable en carpeta '$sub' (no corresponde)" $_.FullName (Get-EvFileFacts $_)
        }
        if ($sub -in 'resourcepacks', 'shaderpacks') {
            Get-ChildItem -LiteralPath $dir -File -Filter *.zip -ErrorAction SilentlyContinue | Select-Object -First 60 | ForEach-Object {
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                    $z = [IO.Compression.ZipFile]::OpenRead($_.FullName)
                    try {
                        $cls = @($z.Entries | Where-Object { $_.FullName -match '\.class$' } | Select-Object -First 3)
                        if ($cls.Count -gt 0) {
                            Add-Ev 'RENOMBRADO' $_.Name "Pack de $sub que contiene clases Java" $_.FullName (@(
                                "Clases detectadas: $($cls[0].FullName)$(if ($cls.Count -gt 1) { " (+$($cls.Count - 1) mas)" })",
                                "Un $sub legitimo no lleva bytecode: es un mod disfrazado"
                            ) + [string[]](Get-EvFileFacts $_))
                        }
                    } finally { $z.Dispose() }
                } catch { }
            }
        }
    }
    $launchers = @{
        'Prism Launcher' = "$env:APPDATA\PrismLauncher"; 'MultiMC' = "$env:APPDATA\MultiMC"; 'TLauncher' = "$env:APPDATA\.tlauncher"
        'ATLauncher' = "$env:APPDATA\ATLauncher"; 'Modrinth App' = "$env:APPDATA\com.modrinth.theseus"; 'CurseForge' = "$env:USERPROFILE\curseforge\minecraft\Instances"
        'GDLauncher' = "$env:APPDATA\gdlauncher_next"
    }
    foreach ($ln in $launchers.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $ln.Value)) { continue }
        Add-Ev 'INFO' "Launcher alternativo: $($ln.Key)" 'Instalado - se revisan sus carpetas mods' $ln.Value
        Get-ChildItem -LiteralPath $ln.Value -Recurse -File -Depth 5 -Filter *.jar -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\mods\\' } | Select-Object -First 200 | ForEach-Object { Invoke-UiPump; Test-ModFile $_ }
    }
    if ($script:EvOut.Count -eq $hits0) { Add-Ev 'OK' 'Sin hallazgos' 'Mods y carpetas de Minecraft sin anomalias' }
}

# ============================================================
# 7. AUTOCLICKERS Y SOFTWARE DE PERIFERICOS
# ============================================================
function Invoke-Ev7 {
    Add-EvHeader "7. AUTOCLICKERS / PERFILES DE PERIFERICOS"
    Set-Status "Evasion 7/8: perfiles de perifericos y scripts compilados..."
    $hits = 0
    $profiles = @("$env:APPDATA\Razer", "$env:LOCALAPPDATA\Razer", "$env:ProgramData\Razer", "$env:APPDATA\Corsair", "$env:LOCALAPPDATA\LGHub", "$env:APPDATA\Logitech",
        "$env:APPDATA\SteelSeries", "$env:ProgramData\SteelSeries", "$env:APPDATA\Bloody7", "$env:APPDATA\A4Tech", "$env:LOCALAPPDATA\Redragon")
    foreach ($pd in $profiles) {
        if (-not (Test-Path -LiteralPath $pd)) { continue }
        $newest = Get-ChildItem -LiteralPath $pd -Recurse -File -Depth 4 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newest) { Add-Ev 'INFO' "Perfil de periferico: $(Split-Path $pd -Leaf)" "Ultimo cambio $($newest.LastWriteTime): $($newest.Name)" $pd }
        Get-ChildItem -LiteralPath $pd -Recurse -File -Depth 4 -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)macro|autoclick|click' } | Select-Object -First 10 |
            ForEach-Object {
                Add-Ev 'SOSPECHOSO' $_.Name "Archivo de perfil con nombre sospechoso (mod. $($_.LastWriteTime))" $_.FullName @(
                    "Archivo de perfil: $($_.FullName)",
                    "Modificado el: $($_.LastWriteTime)",
                    "Tamano: $($_.Length) bytes"
                ); $hits++
            }
    }
    $now = Get-Date; $n = 0
    foreach ($d in (Get-EvUserDirs)) {
        foreach ($f in (Get-ChildItem -LiteralPath $d -Recurse -File -Depth 2 -Filter *.exe -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 12MB -and $_.LastWriteTime -gt $now.AddDays(-90) -and $_.FullName -notmatch $script:EvNoise } | Select-Object -First 100)) {
            if ($n++ -gt 250) { break }
            Invoke-UiPump
            $k = Test-CompiledScript $f.FullName
            if ($k) {
                Add-Ev 'CRITICO' $f.Name "Script compilado en .exe: $k" $f.FullName (Get-EvFileFacts $f + @(
                    "Motor detectado en el binario: $k",
                    "Firmas AHK/AU3 encontradas dentro del ejecutable"
                )); $hits++
            }
        }
    }
    foreach ($d in (Get-EvUserDirs)) {
        Get-ChildItem -LiteralPath $d -Recurse -File -Depth 2 -Include *.ahk, *.au3 -ErrorAction SilentlyContinue | Select-Object -First 20 |
            ForEach-Object {
                Add-Ev 'CRITICO' $_.Name 'Script AutoHotkey/AutoIt en disco' $_.FullName @(
                    "Script: $($_.FullName)",
                    "Modificado el: $($_.LastWriteTime)"
                ); $hits++
            }
    }
    Add-Ev 'INFO' 'Aviso' 'Las configuraciones guardadas en el firmware del mouse no se ven en disco: pedir pantalla compartida y revisar el software que las programo'
    if ($hits -eq 0) { Add-Ev 'OK' 'Sin hallazgos' 'Sin scripts compilados ni perfiles sospechosos' }
}

# ============================================================
# 8. PROTECCION DE LA PROPIA HERRAMIENTA / DEFENSAS DEL SISTEMA
# ============================================================
function Invoke-Ev8 {
    Add-EvHeader "8. INTEGRIDAD DE LA HERRAMIENTA Y DEFENSAS"
    Set-Status "Evasion 8/8: integridad, Defender, servicios clave..."
    $hits = 0
    if (Test-Administrator) { Add-Ev 'OK' 'Permisos de administrador' 'Escaneo con privilegios completos' }
    else { Add-Ev 'CRITICO' 'SIN ADMINISTRADOR' 'Varias comprobaciones (Security log, BAM, modulos) quedan incompletas'; $hits++ }
    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
        $h = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
        $hf = Join-Path $env:APPDATA 'ElSombrio\selfhash.txt'
        if (Test-Path -LiteralPath $hf) {
            $saved = (Get-Content -LiteralPath $hf -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
            if ($saved -eq $h) {
                Add-Ev 'OK' 'Script integro' "SHA256 coincide con el guardado ($($h.Substring(0,16))...)"
            } else {
                Add-Ev 'CRITICO' 'SCRIPT MODIFICADO' "SHA256 actual $($h.Substring(0,16))... difiere del guardado" $PSCommandPath @(
                    "Hash guardado:    $saved",
                    "Hash actual:      $h",
                    "El script cambio desde la ultima ejecucion: posible manipulacion de la herramienta"
                ); $hits++
            }
        } else {
            Add-Ev 'INFO' 'Hash del script' "SHA256 $h - guardalo en $hf para detectar modificaciones"
        }
    } else { Add-Ev 'INFO' 'Script en memoria (irm | iex)' 'No hay archivo local que verificar' }
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if (-not $mp.AntivirusEnabled)           { Add-Ev 'CRITICO' 'Antivirus DESACTIVADO' 'Defender: AntivirusEnabled = False'; $hits++ }
        if (-not $mp.RealTimeProtectionEnabled)  { Add-Ev 'SOSPECHOSO' 'Proteccion en tiempo real apagada' 'Defender: RealTimeProtectionEnabled = False'; $hits++ }
        $pref = Get-MpPreference -ErrorAction Stop
        foreach ($x in @($pref.ExclusionPath))      { if ($x) { Add-Ev 'CRITICO' 'Exclusion de Defender (ruta)' $x '' @("El cheat suele vivir dentro de esta exclusion: $x"); $hits++ } }
        foreach ($x in @($pref.ExclusionProcess))   { if ($x) { Add-Ev 'CRITICO' 'Exclusion de Defender (proceso)' $x '' @("Proceso excluido del escaneo: $x"); $hits++ } }
        foreach ($x in @($pref.ExclusionExtension)) { if ($x) { Add-Ev 'SOSPECHOSO' 'Exclusion de Defender (extension)' $x; $hits++ } }
    } catch { Add-Ev 'INFO' 'Defender no consultable' 'Puede haber otro antivirus activo o faltar permisos' }
    foreach ($sn in $script:WindowsServices) {
        try {
            $s = Get-CimInstance Win32_BaseService -Filter "Name='$sn'" -ErrorAction Stop
            if (-not $s) { Add-Ev 'SOSPECHOSO' "Servicio $sn" 'No encontrado'; $hits++; continue }
            if ($s.StartMode -eq 'Disabled') {
                Add-Ev 'CRITICO' "Servicio $sn DESHABILITADO" "Modo de inicio: $($s.StartMode)" '' @(
                    "Servicio: $sn",
                    "Inicio: $($s.StartMode) | Estado: $($s.State)",
                    "Servicio deshabilitado = fuente de evidencia apagada"
                ); $hits++
            } elseif ($s.State -ne 'Running' -and $sn -in 'dps', 'eventlog', 'sysmain', 'pcasvc') {
                Add-Ev 'SOSPECHOSO' "Servicio $sn detenido" "Estado: $($s.State), inicio: $($s.StartMode)"; $hits++
            }
        } catch { }
    }
    if ($hits -eq 0) { Add-Ev 'OK' 'Sin hallazgos' 'Herramienta integra y defensas del sistema activas' }
}

# ============================================================
# EJECUTOR: devuelve la lista completa con RESUMEN al inicio.
# $script:EvFindings queda disponible para la UI como lista
# estructurada (Tag/Name/Detail/Path/Expand) -> render expandible.
# ============================================================
function Invoke-EvasionScan {
    $script:EvOut = [System.Collections.Generic.List[string]]::new()
    $script:EvFindings = [System.Collections.Generic.List[psobject]]::new()
    $steps = @(${function:Invoke-Ev1}, ${function:Invoke-Ev2}, ${function:Invoke-Ev3}, ${function:Invoke-Ev4}, ${function:Invoke-Ev5}, ${function:Invoke-Ev6}, ${function:Invoke-Ev7}, ${function:Invoke-Ev8})
    $i = 0
    foreach ($s in $steps) {
        if ($script:CancelRequested) { break }
        $i++
        Set-Progress ([int](($i - 1) / $steps.Count * 100))
        try { & $s } catch { Add-Ev 'INFO' "Seccion $i interrumpida" $_.Exception.Message }
    }
    # Resumen: cuenta alertas por seccion
    $sum = [System.Collections.Generic.List[string]]::new()
    $sum.Add("====== 0. RESUMEN DE ALERTAS ======")
    $cur = ''; $crit = @{}; $sus = @{}; $order = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $script:EvOut) {
        if ($l -match '^=+\s*(.*?)\s*=+$') { $cur = $Matches[1]; $order.Add($cur); $crit[$cur] = 0; $sus[$cur] = 0; continue }
        if ($l -match '^\[(CRITICO|RENOMBRADO)\]') { $crit[$cur]++ } elseif ($l -match '^\[SOSPECHOSO\]') { $sus[$cur]++ }
    }
    foreach ($k in $order) {
        $tag = if ($crit[$k] -gt 0) { 'CRITICO' } elseif ($sus[$k] -gt 0) { 'SOSPECHOSO' } else { 'OK' }
        $sum.Add("[$tag] $k | $($crit[$k]) criticos, $($sus[$k]) sospechosos")
    }
    $final = [System.Collections.Generic.List[string]]::new()
    $final.AddRange($sum); $final.AddRange($script:EvOut)
    Add-ToLog $script:LogEvasion @($script:EvOut)
    return $final
}

# ============================================================
# OPCION DE MENU [14]: llamarla desde el boton del menu lateral
# ============================================================
function Invoke-EvasionOption {
    Start-ScanSession "Analisis anti-evasion (8 secciones)..." -ShowPanel
    try {
        $items = Invoke-EvasionScan
        $script:CatData['Evasion'] = $items
        $script:ActiveCat = 'Evasion'
        # Los hallazgos con Expand (modificaciones) estan en $script:EvFindings para UI expandible
        Show-Results
        Show-Category 'Evasion'
        Set-Progress 100
        Set-Status "Anti-evasion completado. ($($script:EvFindings.Count) hallazgos con detalle expandible)"
    } finally { Stop-ScanSession }
}
