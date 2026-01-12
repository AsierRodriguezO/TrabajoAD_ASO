<#
.SYNOPSIS
 Script para configurar un Windows Server Core como Controlador de Dominio (AD DS) y verificar la instalación.
.Autor
Elias Halloumi El Amraoui

.NOTES
 Ejecutar en una sesión PowerShell elevada (run as Administrator).
#>


# Nombre deseado del servidor
$NewComputerName = "SRVGrupo4-DC01"

# Configuración de red (si usas DHCP deja $UseDHCP = $true)
$UseDHCP = $false

# Si $UseDHCP = $false, configura:
$InterfaceAlias = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).Name
$IPv4Address = "192.168.1.10"      # <-- poner la IP deseada
$PrefixLength = 24                 # <-- /24 => 255.255.255.0
$Gateway = "192.168.1.1"           # <-- Puerta de enlace
$DnsServers = @("192.168.1.10")    # <-- pointer local a si mismo (recomendado antes de promoción) o el DNS corporativo

# Dominio que vas a crear (nuevo bosque)
$DomainName = "grupo4.local"
$NetBIOSName = "GRUPO4"              # NetBIOS corto para el dominio

# Rutas de carpetas de base de datos, logs y SYSVOL. Ajusta si quieres ubicaciones diferentes.
$ADDSDatabasePath = "C:\NTDS"
$ADDSLogPath      = "C:\NTDS\Logs"
$SYSVOLPath       = "C:\SYSVOL"

# Snap shot/log
$LogFile = "C:\ADSetup\ADInstall_$(Get-Date -Format yyyyMMdd_HHmmss).log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force | Out-Null

# ---------------------------
# Inicio del script
# ---------------------------
Start-Transcript -Path $LogFile -Force

Write-Host "Inicio: configuración de servidor e instalación AD DS" -ForegroundColor Green

# 1) Configurar red (si no se usa DHCP)
if (-not $UseDHCP) {

    Write-Host "Reconfigurando IP en la interfaz: $InterfaceAlias" -ForegroundColor Cyan

    # QUITAR cualquier IP v4 anterior
    $oldIPs = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($oldIPs) {
        foreach ($ip in $oldIPs) {
            Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    # QUITAR cualquier Default Gateway anterior
    $oldGW = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias | Select-Object -ExpandProperty IPv4DefaultGateway -ErrorAction SilentlyContinue
    if ($oldGW) {
        Write-Host "Eliminando gateway anterior: $($oldGW.NextHop)" -ForegroundColor Yellow
        Remove-NetRoute -InterfaceAlias $InterfaceAlias -NextHop $oldGW.NextHop -Confirm:$false -ErrorAction SilentlyContinue
    }

    # AGREGAR nueva IP + gateway
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPv4Address -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop

    # Configurar DNS
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServers -ErrorAction Stop

    Write-Host "IP configurada correctamente: $IPv4Address Gateway: $Gateway DNS: $($DnsServers -join ', ')" -ForegroundColor Green
}


# 2) Renombrar equipo (si ya tiene el nombre diferente)
$CurrentName = (Get-CimInstance Win32_ComputerSystem).Name
if ($CurrentName -ne $NewComputerName) {
    Write-Host "Renombrando equipo $CurrentName -> $NewComputerName" -ForegroundColor Cyan
    Rename-Computer -NewName $NewComputerName -Force -PassThru
    Write-Host "Reiniciando para aplicar nuevo nombre..." -ForegroundColor Yellow
    Restart-Computer -Force
    # El script se detendrá aquí por el reinicio. Después del reinicio, vuelve a ejecutar la siguiente sección.
    # Para facilitar ejecución unattended, podrías usar tareas programadas o ejecutar manualmente la segunda mitad.
    Stop-Transcript
    exit
} else {
    Write-Host "El equipo ya tiene el nombre correcto: $CurrentName" -ForegroundColor Green
}

# Desde aquí el equipo ya debería tener el nombre SRVGrupoX-DC01 (si hubo reinicio, vuelve a ejecutar).

# 3) Actualizaciones opcionales (PSWindowsUpdate)

try {
    Write-Host "Intentando instalar módulo PSWindowsUpdate y buscar/instalar actualizaciones (opcional)..." -ForegroundColor Cyan
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
    Install-Module -Name PSWindowsUpdate -Force -AllowClobber -ErrorAction Stop
    Import-Module PSWindowsUpdate -ErrorAction Stop
    # Instalar actualizaciones y reiniciar si es necesario
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot
} catch {
    Write-Host "Actualización automática con PSWindowsUpdate falló o no disponible. Puedes usar 'sconfig' manualmente." -ForegroundColor Yellow
}

# 4) Instalar rol AD DS
Write-Host "Instalando rol AD-Domain-Services..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop

# Importar módulo de despliegue AD
Import-Module ADDSDeployment -ErrorAction Stop

# 5) Pedir contraseña DSRM de forma segura
Write-Host "Introduce la contraseña para el Modo de Restauración de Servicios de Directorio (DSRM)." -ForegroundColor Cyan
$DSRMCred = Read-Host -AsSecureString "DSRM Password"

# 6) Promoción a controlador de dominio - crear nuevo bosque
Write-Host "Promoviendo este servidor a Controlador de Dominio (nuevo bosque)..." -ForegroundColor Cyan

Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetBIOSName `
    -SafeModeAdministratorPassword $DSRMCred `
    -DatabasePath $ADDSDatabasePath `
    -LogPath $ADDSLogPath `
    -SysvolPath $SYSVOLPath `
    -InstallDns `
    -CreateDnsDelegation:$false `
    -NoRebootOnCompletion:$false `
    -Force:$true -ErrorAction Stop

# Install-ADDSForest reiniciará el servidor al finalizar (NoRebootOnCompletion:$false)

# NOTA: Después del reinicio, vuelve a iniciar sesión y ejecuta las comprobaciones a continuación.

Stop-Transcript
