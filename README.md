
# ================================================================================================
#   PowerScript Optimizador LEVIATÁN v11.0 - Edición Extrema y Avanzada
#   Objetivo: Limpieza, aceleración, optimización, actualización y diagnóstico total del sistema.
#   ADVERTENCIA: EJECUTAR SIEMPRE COMO ADMINISTRADOR.
# ================================================================================================

#region VALIDACIÓN ADMINISTRADOR
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script requiere privilegios de Administrador. Por favor, reinicia la terminal como Administrador."
    Start-Sleep -Seconds 10
    Exit
}
#endregion

#region VARIABLES Y LOG
$logFile = "$env:USERPROFILE\Desktop\Optimizador-Leviatan-Log-v11.0.txt"
Function Write-Log { param ([string]$Message, [string]$Color = 'Gray')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
    Add-Content -Path $logFile -Value "[$timestamp] $Message"
}
#endregion

#region LIMPIEZA BÁSICA Y AVANZADA
Write-Log "Iniciando limpieza de archivos temporales..."
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\WER\*" -Recurse -Force -ErrorAction SilentlyContinue
Cleanmgr /sagerun:1

Write-Log "Limpiando cachés del sistema..."
ipconfig /flushdns
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
del "$env:SystemRoot\SoftwareDistribution\Download\*" -Force -Recurse -ErrorAction SilentlyContinue
del "$env:SystemRoot\Logs\CBS\*" -Force -Recurse -ErrorAction SilentlyContinue
#endregion

#region OPTIMIZACIÓN DE RED
Write-Log "Reiniciando adaptadores de red..."
Get-NetAdapter | Restart-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
#endregion

#region OPTIMIZACIÓN DE MEMORIA
Write-Log "Liberando memoria RAM..."
[System.GC]::Collect()
#endregion

#region DESACTIVACIÓN DE SERVICIOS INNECESARIOS
Write-Log "Deteniendo servicios innecesarios..."
$servicios = @("DiagTrack", "dmwappushservice", "XblGameSave", "WMPNetworkSvc", "MapsBroker")
foreach ($svc in $servicios) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled
}
#endregion

#region DIAGNÓSTICO Y REPARACIÓN
Write-Log "Ejecutando diagnóstico de sistema..."
sfc /scannow
DISM /Online /Cleanup-Image /RestoreHealth
chkdsk C: /scan
#endregion

Write-Log "✅ Optimización finalizada. Revisa el archivo de log en tu escritorio." "Green"
Pause
