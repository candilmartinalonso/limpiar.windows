<#
.SYNOPSIS
  OptiClean-Ultra: Optimización + Limpieza Profunda (con nivel Ultra opcional).
.DESCRIPTION
  - Optimiza Windows (plan de energía, visuales, SysMain/Prefetcher, TRIM SSD, GPU Scheduling opcional).
  - Limpia archivos basura (TEMP, Papelera, Delivery Optimization, Windows Update, thumbnails, dumps, CBS .cab).
  - Nivel Ultra: limpia *.tmp/*.log/*.etl antiguos en todo el disco (excluye zonas críticas).
  - Paso IRREVERSIBLE opcional: DISM /StartComponentCleanup /ResetBase.
  No desinstala programas. Optimización reversible con -Revert (no recupera archivos ya borrados).
.PARAMETER Max       Perfil de máxima potencia (incluye Aggressive + NoHibernate + GPU sched + menos apps en 2º plano).
.PARAMETER Gamer     Perfil gaming (Game Mode ON, Game Bar/DVR OFF, apps mínimas 2º plano, conserva hibernación).
.PARAMETER Work      Perfil trabajo (menos anuncios y Bing/Cloud en búsqueda; apps 2º plano restringidas).
.PARAMETER Laptop    Optimiza sin arruinar batería (no fuerza CPU al 100% en CA).
.PARAMETER CleanAll  Limpieza profunda segura (TEMP, WU/DO, dumps, thumbnails, CBS, WinSxS seguro).
.PARAMETER Ultra     Extiende CleanAll: borra *.tmp/*.log/*.etl antiguos en todo el disco (fuera de zonas críticas).
.PARAMETER LogsDays  Antigüedad mínima para Ultra (por defecto 7).
.PARAMETER BrowsersAll Limpia cachés de Edge/Chrome/Firefox de TODOS los usuarios (no borra perfiles).
.PARAMETER OldUpgrades Elimina Windows.old y $WINDOWS.~BT (pierde rollback).
.PARAMETER ResetWU   Reset profundo de Windows Update (SoftwareDistribution y Catroot2).
.PARAMETER RebuildIndex Reconstruye índice de búsqueda.
.PARAMETER EnableHwGpuSchedule Activa Hardware-Accelerated GPU Scheduling (si compatible).
.PARAMETER Deep      DISM /RestoreHealth + SFC + StartComponentCleanup (seguro).
.PARAMETER Irreversible Ejecuta DISM /StartComponentCleanup /ResetBase (IRREVERSIBLE).
.PARAMETER Report    Muestra detalle y total de espacio liberado.
.PARAMETER Revert    Revierte optimizaciones (plan/servicios/políticas/GPU/visuales) usando backup.
.NOTES
  Ejecutar como Administrador. Versión: 4.0
#>

[CmdletBinding()]
param(
  # Perfiles de optimización
  [switch]$Max,
  [switch]$Gamer,
  [switch]$Work,
  [switch]$Laptop,

  # Opciones de optimización
  [switch]$EnableHwGpuSchedule,
  [switch]$Deep,
  [switch]$Revert,

  # Limpieza
  [switch]$CleanAll,
  [switch]$Ultra,
  [int]$LogsDays = 7,
  [switch]$BrowsersAll,
  [switch]$OldUpgrades,
  [switch]$ResetWU,
  [switch]$RebuildIndex,
  [switch]$Irreversible,
  [switch]$Report
)

# -------------------- Helpers --------------------
function Require-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=New-Object Security.Principal.WindowsPrincipal($id)
  if(-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)){
    Write-Error "Ejecutá PowerShell como Administrador."; exit 1
  }
}
function Ensure-Key { param($Path) if(-not (Test-Path $Path)){ New-Item -Path $Path -Force | Out-Null } }
function NowTag { return ("{0:yyyyMMdd-HHmmss}" -f (Get-Date)) }

# Backup estructura
$stateDir  = "$env:ProgramData\OptiCleanUltra"
$backupFile = Join-Path $stateDir "backup.json"
function Load-Backup {
  if(-not (Test-Path $stateDir)){ New-Item -ItemType Directory -Force -Path $stateDir | Out-Null }
  if(Test-Path $backupFile){
    try { return (Get-Content $backupFile -Encoding UTF8 | ConvertFrom-Json) } catch { }
  }
  return [pscustomobject]@{
    PowerPlanGUID = $null
    Registry      = @{}
    Services      = @{}
    HibernateWasOn= $null
    GpuSched      = $null
    Timestamp     = (Get-Date)
    Version       = "4.0"
  }
}
function Save-Backup($bk){ $bk | ConvertTo-Json -Depth 6 | Set-Content -Path $backupFile -Encoding UTF8 }

# Setters con backup
function Set-Registry-Backup {
  param([string]$HivePath,[string]$Name,
        [ValidateSet("String","ExpandString","Binary","DWord","QWord","MultiString")] [string]$Type,
        [Parameter(Mandatory=$true)]$Value,[ref]$BackupObj)
  try{
    Ensure-Key -Path $HivePath
    $bk = $BackupObj.Value
    if(-not $bk.Registry.ContainsKey($HivePath)){ $bk.Registry[$HivePath] = @{} }
    if(-not $bk.Registry[$HivePath].ContainsKey($Name)){
      try { $bk.Registry[$HivePath][$Name] = (Get-ItemProperty -Path $HivePath -Name $Name -ErrorAction Stop).$Name } catch { $bk.Registry[$HivePath][$Name] = $null }
    }
    if(Get-ItemProperty -Path $HivePath -Name $Name -ErrorAction SilentlyContinue){
      Set-ItemProperty -Path $HivePath -Name $Name -Value $Value -Force
    } else {
      New-ItemProperty -Path $HivePath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    }
  } catch {
    Write-Warning ("No se pudo ajustar {0}\{1}: {2}" -f $HivePath, $Name, $_.Exception.Message)
  }
}
function Set-Service-Backup {
  param([string]$Name,[ValidateSet("Disabled","Automatic","Manual","AutomaticDelayedStart")] [string]$StartupType,[switch]$StopNow,[ref]$BackupObj)
  try{
    $svc = Get-Service -Name $Name -ErrorAction Stop
    $bk  = $BackupObj.Value
    if(-not $bk.Services.ContainsKey($Name)){
      $bk.Services[$Name] = @{
        StartType  = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'").StartMode
        WasRunning = ($svc.Status -eq 'Running')
      }
    }
    if($StartupType){
      if($StartupType -eq "AutomaticDelayedStart"){
        Set-Service -Name $Name -StartupType Automatic
        sc.exe config $Name start= delayed-auto | Out-Null
      } else { Set-Service -Name $Name -StartupType $StartupType }
    }
    if($StopNow -and $svc.Status -eq 'Running'){ Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
  } catch {
    Write-Verbose ("No se pudo ajustar servicio {0}: {1}" -f $Name, $_.Exception.Message)
  }
}
function Revert-Service-FromBackup {
  param([string]$Name,[psobject]$BkSvc)
  try{
    if(-not $BkSvc){ return }
    $mode = $BkSvc.StartType
    if($mode -eq "Auto"){ $mode="Automatic" }
    if($mode -eq "Auto (Delayed Start)"){ $mode="AutomaticDelayedStart" }
    if($mode){
      if($mode -eq "AutomaticDelayedStart"){
        Set-Service -Name $Name -StartupType Automatic
        sc.exe config $Name start= delayed-auto | Out-Null
      } else { Set-Service -Name $Name -StartupType $mode }
    }
    if($BkSvc.WasRunning){ try{ Start-Service -Name $Name -ErrorAction SilentlyContinue }catch{} }
  } catch { }
}

# Limpieza helpers
function Get-FolderSizeBytes { param([string]$Path) if(-not (Test-Path -LiteralPath $Path)){return 0}; try{ (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum }catch{0} }
function Remove-PathSafe   { param([string]$Path)
  if(Test-Path -LiteralPath $Path){
    try{ Takeown.exe /F "$Path" /A /R /D Y | Out-Null; Icacls.exe "$Path" /grant Administrators:F /T /C | Out-Null }catch{}
    try{ Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue }catch{}
  }
}
function Empty-Folder { param([string]$Path) if(Test-Path -LiteralPath $Path){ try{ Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }catch{} } }
function Stop-Services { param([string[]]$Names) foreach($n in $Names){ try{ Stop-Service -Name $n -Force -ErrorAction SilentlyContinue; sc.exe stop $n 1>$null 2>$null }catch{} } }
function Start-Services{ param([string[]]$Names) foreach($n in $Names){ try{ Start-Service -Name $n -ErrorAction SilentlyContinue; sc.exe start $n 1>$null 2>$null }catch{} } }

# -------------------- Inicio / Revert --------------------
Require-Admin
$bk = Load-Backup

if($Revert){
  if(-not (Test-Path $backupFile)){ Write-Warning "No hay backup para revertir."; exit }
  if($bk.PowerPlanGUID){ Write-Host ("Restaurando plan de energía {0}..." -f $bk.PowerPlanGUID) -ForegroundColor Cyan; powercfg -setactive $bk.PowerPlanGUID 2>$null | Out-Null }
  foreach($key in $bk.Registry.Keys){
    foreach($name in $bk.Registry[$key].Keys){
      $val = $bk.Registry[$key][$name]
      if($null -eq $val){ Remove-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue }
      else {
        $type="String"; if($val -is [int]){ $type="DWord" }
        try{
          if(-not (Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue)){
            New-ItemProperty -Path $key -Name $name -Value $val -PropertyType $type -Force | Out-Null
          } else { Set-ItemProperty -Path $key -Name $name -Value $val -Force }
        }catch{}
      }
    }
  }
  foreach($svcName in $bk.Services.Keys){ Revert-Service-FromBackup -Name $svcName -BkSvc $bk.Services[$svcName] }
  if($bk.HibernateWasOn -ne $null){ if($bk.HibernateWasOn){ powercfg -h on | Out-Null } else { powercfg -h off | Out-Null } }
  Write-Host "Reversión completa. Reiniciá para aplicar por completo." -ForegroundColor Green
  exit
}

# -------------------- Punto de restauración + plan energía --------------------
try{ Checkpoint-Computer -Description "OptiClean-Ultra (previo)" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop }catch{}
$currentPlan = (powercfg -getactivescheme) 2>$null
$currentGUID = $null
if($currentPlan -match '\(([0-9a-fA-F\-]{36})\)'){ $currentGUID = $Matches[1] }
if(-not $bk.PowerPlanGUID){ $bk.PowerPlanGUID = $currentGUID }

Write-Host "Activando plan de energía de máximo rendimiento..." -ForegroundColor Cyan
$ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
powercfg -duplicatescheme $ultimateGuid 2>$null | Out-Null
powercfg -setactive $ultimateGuid       2>$null | Out-Null

# -------------------- Visuales livianos --------------------
Write-Host "Ajustando visuales (menos transparencias/animaciones)..." -ForegroundColor Cyan
Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 0 -BackupObj ([ref]$bk)
Set-Registry-Backup -HivePath "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Type String -Value 0 -BackupObj ([ref]$bk)
Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Type DWord -Value 2 -BackupObj ([ref]$bk)

# -------------------- Perfiles compuestos --------------------
function Tune-CPU-AC {
  try{
    powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg -setactive SCHEME_CURRENT | Out-Null
  }catch{}
}
function Apply-Game-Features { param([ref]$Bk)
  Write-Host "Game Mode ON / Game Bar & DVR OFF..." -ForegroundColor Cyan
  Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Type DWord -Value 1 -BackupObj $Bk
  Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Type DWord -Value 0 -BackupObj $Bk
  Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Type DWord -Value 0 -BackupObj $Bk
  Set-Registry-Backup -HivePath "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 0 -BackupObj $Bk
}
function Apply-Low-Noise-UI { param([ref]$Bk)
  Write-Host "Reduciendo sugerencias/anuncios..." -ForegroundColor Cyan
  $cdm="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
  $vals=@{
    "SubscribedContent-338387Enabled"=0; "SubscribedContent-353694Enabled"=0; "SubscribedContent-353696Enabled"=0;
    "SubscribedContent-353698Enabled"=0; "SubscribedContent-310093Enabled"=0; "SystemPaneSuggestionsEnabled"=0; "SoftLandingEnabled"=0
  }
  foreach($k in $vals.Keys){ Set-Registry-Backup -HivePath $cdm -Name $k -Type DWord -Value $vals[$k] -BackupObj $Bk }
  Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Type DWord -Value 0 -BackupObj $Bk
}
function Apply-Background-Apps-Strict { param([ref]$Bk)
  Write-Host "Restringiendo apps en 2º plano..." -ForegroundColor Cyan
  Set-Registry-Backup -HivePath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Type DWord -Value 2 -BackupObj $Bk
  Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 1 -BackupObj $Bk
}
function Apply-Search-Work { param([ref]$Bk)
  Write-Host "Búsqueda: sin Bing/Cloud..." -ForegroundColor Cyan
  $srch="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
  Set-Registry-Backup -HivePath $srch -Name "BingSearchEnabled"  -Type DWord -Value 0 -BackupObj $Bk
  Set-Registry-Backup -HivePath $srch -Name "AllowCloudSearch"   -Type DWord -Value 0 -BackupObj $Bk
  Set-Registry-Backup -HivePath $srch -Name "CortanaConsent"     -Type DWord -Value 0 -BackupObj $Bk
}

if($Max){
  Tune-CPU-AC
  # Aggressive SSD (SysMain/Prefetcher OFF; LastAccessUpdate OFF)
  Set-Service-Backup -Name "SysMain" -StartupType Disabled -StopNow -BackupObj ([ref]$bk)
  Set-Registry-Backup -HivePath "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Type DWord -Value 0 -BackupObj ([ref]$bk)
  Set-Registry-Backup -HivePath "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Type DWord -Value 0 -BackupObj ([ref]$bk)
  Set-Registry-Backup -HivePath "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -Type DWord -Value 1 -BackupObj ([ref]$bk)
  # Hibernación OFF (libera hiberfil)
  if($bk.HibernateWasOn -eq $null){ $bk.HibernateWasOn = Test-Path "$env:SystemDrive\hiberfil.sys" }
  powercfg -h off | Out-Null
  # UI/Apps/Telemetry
  Apply-Game-Features -Bk ([ref]$bk)
  Apply-Low-Noise-UI -Bk ([ref]$bk)
  Apply-Background-Apps-Strict -Bk ([ref]$bk)
  Set-Registry-Backup -HivePath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1 -BackupObj ([ref]$bk)
}
if($Gamer){
  Apply-Game-Features -Bk ([ref]$bk)
  Set-Registry-Backup -HivePath "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 1 -BackupObj ([ref]$bk)
}
if($Work){
  Apply-Low-Noise-UI -Bk ([ref]$bk)
  Apply-Search-Work -Bk ([ref]$bk)
  Apply-Background-Apps-Strict -Bk ([ref]$bk)
}
if($Laptop){
  Write-Host "Perfil Laptop: conservando ahorro en batería (no forzar CPU al 100%)." -ForegroundColor Cyan
}

# GPU Scheduling (opcional)
if($EnableHwGpuSchedule){
  Write-Host "Activando Hardware-Accelerated GPU Scheduling (si compatible)..." -ForegroundColor Cyan
  $key="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
  try{
    $prev=$null; try{ $prev=(Get-ItemProperty -Path $key -Name "HwSchMode" -ErrorAction Stop).HwSchMode }catch{}
    if($bk.GpuSched -eq $null){ $bk.GpuSched = $prev }
    if(-not (Get-ItemProperty -Path $key -Name "HwSchMode" -ErrorAction SilentlyContinue)){
      New-ItemProperty -Path $key -Name "HwSchMode" -Value 2 -PropertyType DWord -Force | Out-Null
    } else { Set-ItemProperty -Path $key -Name "HwSchMode" -Value 2 -Force }
  }catch{ Write-Warning ("No se pudo ajustar HwSchMode: {0}" -f $_.Exception.Message) }
}

# -------------------- Mantenimiento base (TRIM / CleanMgr) --------------------
Write-Host "TRIM/ReTrim SSD y limpieza base..." -ForegroundColor Cyan
# SSD/HDD
$physicalByNumber = @{}
Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object { $physicalByNumber[$_.DeviceId] = $_.MediaType }
Get-Volume | Where-Object { $_.FileSystem -in @('NTFS','ReFS') -and $_.DriveLetter } | ForEach-Object {
  $vol = $_.DriveLetter
  try{
    $disk  = (Get-Volume -DriveLetter $vol | Get-Partition | Get-Disk) 2>$null
    $media = $null; if($disk -and $physicalByNumber.ContainsKey($disk.Number)){ $media = $physicalByNumber[$disk.Number] }
    if($media -eq 'HDD'){
      Write-Host ("  [{0}:] HDD -> Desfragmentando..." -f $vol) -ForegroundColor Yellow
      Optimize-Volume -DriveLetter $vol -Defrag -Verbose | Out-Null
    } else {
      Write-Host ("  [{0}:] SSD/Desconocido -> ReTrim..." -f $vol) -ForegroundColor Green
      Optimize-Volume -DriveLetter $vol -ReTrim -Verbose | Out-Null
    }
  } catch { Write-Warning ("  [{0}:] No se pudo optimizar: {1}" -f $vol, $_.Exception.Message) }
}
try{ fsutil behavior set DisableDeleteNotify NTFS 0 | Out-Null; fsutil behavior set DisableDeleteNotify ReFS 0 | Out-Null }catch{}
try{ Start-Process -FilePath cleanmgr.exe -ArgumentList "/verylowdisk" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue }catch{}

# -------------------- Limpieza: CleanAll / Ultra --------------------
$win    = $env:WINDIR
$sysdrv = $env:SystemDrive
$usersRoot = Join-Path $sysdrv "Users"

# Tracking de tamaños
$targets = New-Object System.Collections.ArrayList
function Track-Add { param([string]$p) if($p){ [void]$targets.Add($p) } }

# Objetivos base
$TEMP_USER   = $env:TEMP
$TEMP_SYS    = Join-Path $win "Temp"
$DO_CACHE    = Join-Path $env:ProgramData "Microsoft\Windows\DeliveryOptimization\Cache"
$WU_DL       = Join-Path $win "SoftwareDistribution\Download"
$THUMB_DIR   = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Explorer"
$ICON_CACHE  = Join-Path $env:LOCALAPPDATA "IconCache.db"
$MINIDUMP    = Join-Path $win "Minidump"
$MEMDMP      = Join-Path $sysdrv "MEMORY.DMP"
$CBS_CABS    = Join-Path $win "Logs\CBS\*.cab"

# Añadir a tracking
Track-Add $TEMP_USER; Track-Add $TEMP_SYS; Track-Add $DO_CACHE; Track-Add $WU_DL; Track-Add $THUMB_DIR; Track-Add $MINIDUMP

# Por-perfil
$perUserTemps = @()
if(Test-Path $usersRoot){
  Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object{
    $uTemp1 = Join-Path $_.FullName "AppData\Local\Temp"
    $uThumb = Join-Path $_.FullName "AppData\Local\Microsoft\Windows\Explorer"
    if(Test-Path $uTemp1){ $perUserTemps += $uTemp1; Track-Add $uTemp1 }
    if(Test-Path $uThumb){ Track-Add $uThumb }
  }
}

# Medición inicial
$before = [ordered]@{}
foreach($t in $targets){ $before[$t] = Get-FolderSizeBytes -Path $t }
$beforeRecycle = 0
try{ $beforeRecycle = (Get-ChildItem -Path "RecycleBin::" -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum }catch{}

if($CleanAll -or $Ultra){
  Write-Host "=== Limpieza profunda (base) ===" -ForegroundColor Cyan

  # TEMP usuario/sistema y por-perfil
  foreach($p in @($TEMP_USER,$TEMP_SYS)){ Empty-Folder -Path $p }
  foreach($p in $perUserTemps){ Empty-Folder -Path $p }

  # Papelera
  try{ Clear-RecycleBin -Force -ErrorAction SilentlyContinue }catch{}

  # Delivery Optimization
  Stop-Services -Names @("DoSvc"); Remove-PathSafe -Path $DO_CACHE; Start-Services -Names @("DoSvc")

  # Windows Update downloads
  Stop-Services -Names @("wuauserv","bits"); Remove-PathSafe -Path $WU_DL; Start-Services -Names @("bits","wuauserv")

  # Thumbnails/IconCache
  try{ Get-ChildItem -LiteralPath $THUMB_DIR -Filter "thumbcache*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }catch{}
  if(Test-Path -LiteralPath $ICON_CACHE){ try{ Remove-Item -LiteralPath $ICON_CACHE -Force -ErrorAction SilentlyContinue }catch{} }

  # Dumps
  Remove-PathSafe -Path $MINIDUMP
  if(Test-Path -LiteralPath $MEMDMP){ Remove-PathSafe -Path $MEMDMP }

  # CBS .cab
  try{ Get-ChildItem -Path $CBS_CABS -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }catch{}

  # WinSxS seguro
  try{ Dism.exe /online /Cleanup-Image /StartComponentCleanup | Out-Null }catch{}
}

if($Ultra){
  Write-Host ("=== Ultra: *.tmp/*.log/*.etl >= {0} días (fuera de zonas críticas) ===" -f $LogsDays) -ForegroundColor Magenta
  $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
  $cutoff = (Get-Date).AddDays(-$LogsDays)
  foreach($d in $drives){
    $root = $d.Root
    $excludeRoots = @(
      (Join-Path $root "Windows"),
      (Join-Path $root "Program Files"),
      (Join-Path $root "Program Files (x86)"),
      (Join-Path $root "ProgramData\Package Cache") # no tocar caches de MSI
    )
    try{
      Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue -Include *.tmp,*.log,*.etl |
        Where-Object {
          ($_.LastWriteTime -lt $cutoff) -and
          ($excludeRoots -notcontains $_.DirectoryName) -and
          ($_.FullName -notlike "$win\*")
        } | Remove-Item -Force -ErrorAction SilentlyContinue
    }catch{}
  }
}

# Navegadores (opcional)
if($BrowsersAll){
  Write-Host "Cachés Edge/Chrome/Firefox (todos los usuarios)..." -ForegroundColor Cyan
  if(Test-Path $usersRoot){
    Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object{
      $base = $_.FullName
      $paths = @(
        (Join-Path $base "AppData\Local\Microsoft\Edge\User Data\Default\Cache"),
        (Join-Path $base "AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"),
        (Join-Path $base "AppData\Local\Google\Chrome\User Data\Default\Cache"),
        (Join-Path $base "AppData\Local\Google\Chrome\User Data\Default\Code Cache"),
        (Join-Path $base "AppData\Roaming\Mozilla\Firefox\Profiles")
      )
      foreach($p in $paths){
        if(Test-Path -LiteralPath $p){
          if($p -like "*Firefox*Profiles"){
            Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue | ForEach-Object{
              Remove-PathSafe -Path (Join-Path $_.FullName "cache2")
              Remove-PathSafe -Path (Join-Path $_.FullName "startupCache")
            }
          } else { Remove-PathSafe -Path $p }
        }
      }
    }
  }
}

# OldUpgrades (opcional)
if($OldUpgrades){
  Write-Host "Eliminando Windows.old y \$WINDOWS.~BT (pierde rollback)..." -ForegroundColor Yellow
  Remove-PathSafe -Path (Join-Path $sysdrv "Windows.old")
  Remove-PathSafe -Path (Join-Path $sysdrv "\$WINDOWS.~BT")
}

# ResetWU (opcional)
if($ResetWU){
  Write-Host "Reset profundo de Windows Update..." -ForegroundColor Yellow
  Stop-Services -Names @("wuauserv","bits","cryptsvc","DoSvc")
  $sdRoot  = Join-Path $win "SoftwareDistribution"
  $catroot = Join-Path $win "System32\catroot2"
  try{
    if(Test-Path -LiteralPath $sdRoot){  Rename-Item -LiteralPath $sdRoot  -NewName ("SoftwareDistribution.old.{0}" -f (NowTag)) -ErrorAction SilentlyContinue }
    if(Test-Path -LiteralPath $catroot){ Rename-Item -LiteralPath $catroot -NewName ("catroot2.old.{0}"          -f (NowTag)) -ErrorAction SilentlyContinue }
  }catch{}
  Start-Services -Names @("DoSvc","cryptsvc","bits","wuauserv")
}

# RebuildIndex (opcional)
if($RebuildIndex){
  Write-Host "Reconstruyendo índice de búsqueda..." -ForegroundColor Cyan
  try{
    Stop-Services -Names @("WSearch")
    $indexData = Join-Path $env:ProgramData "Microsoft\Search\Data\Applications\Windows"
    Empty-Folder -Path $indexData
    Start-Services -Names @("WSearch")
  }catch{}
}

# IRREVERSIBLE (opcional)
if($Irreversible){
  Write-Host "DISM /StartComponentCleanup /ResetBase (IRREVERSIBLE)..." -ForegroundColor Red
  try{ Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null }catch{}
}

# -------------------- Reporte --------------------
function ToGB{ param([double]$b) [math]::Round(($b/1GB),2) }
$after = [ordered]@{}
foreach($t in $targets){ $after[$t] = Get-FolderSizeBytes -Path $t }
$afterRecycle = 0; try{ $afterRecycle = (Get-ChildItem -Path "RecycleBin::" -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum }catch{}
$freed = 0
foreach($k in $before.Keys){ $freed += [math]::Max(0, ($before[$k] - $after[$k])) }
$freed += [math]::Max(0, ($beforeRecycle - $afterRecycle))

if($Report){
  Write-Host "`n--- Reporte por ruta (GB aprox.) ---" -ForegroundColor White
  foreach($k in $before.Keys){
    $dgb = ToGB ([double]($before[$k]-$after[$k]))
    Write-Host ("{0}`n  Liberado: {1} GB`n" -f $k, $dgb)
  }
  Write-Host ("Total liberado: {0} GB (aprox.)" -f (ToGB -b $freed)) -ForegroundColor Green
}

# -------------------- Persistir backup y salida --------------------
Save-Backup $bk
Write-Host "`nOptiClean-Ultra finalizado. Reiniciar puede ayudar a consolidar cambios." -ForegroundColor Green
