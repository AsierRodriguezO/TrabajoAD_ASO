<#
.SYNOPSIS
    Script para crear estructura de Active Directory personalizada por grupo
.DESCRIPCION
    Crea UOs, grupos de seguridad y usuarios en AD con nomenclatura oficial.
    Estructura mínima: OU principal, OU Usuarios, OU Equipos, OU Grupos, 2 grupos de seguridad y 6 usuarios.
.EXAMPLE
    .\usuarios.ps1 -NumeroGrupo 4
.NOTES
    Autor: Jaime Portilla (adaptado y corregido)
    Fecha: 07/01/2026
    Versión: 1.2 - Comillas corregidas y mejoras de robustez
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$NumeroGrupo,
   
    [Parameter(Mandatory=$false)]
    [string]$DominioDN = $null,
   
    [Parameter(Mandatory=$false)]
    [string]$RutaCSV = $null
)

# Cargar módulo ActiveDirectory
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Error "El módulo 'ActiveDirectory' no está disponible. Ejecuta en un DC o instala RSAT. Detalle: $_"
    exit 1
}

# Obtener DN del dominio si no se proporciona
if (-not $DominioDN) {
    try {
        $DominioDN = (Get-ADDomain).DistinguishedName
    }
    catch {
        Write-Error "No se pudo obtener el nombre del dominio Active Directory: $_"
        exit 1
    }
}

# Ruta del CSV por defecto
if (-not $RutaCSV) {
    $RutaCSV = Join-Path -Path $PSScriptRoot -ChildPath "Usuarios_Grupo$NumeroGrupo.csv"
}

# ============================================================================
# VARIABLES DE CONFIGURACIÓN (Nomenclatura OFICIAL)
# ============================================================================
$NombreGrupo = "Grupo$NumeroGrupo"
$ContrasenaBase = "Admin_1234"
$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "CrearAD_Grupo$NumeroGrupo.log"

$OUGeneral = "OUGrupo$NumeroGrupo"
$OUUsuarios = "OUGrupo${NumeroGrupo}_Usuarios"
$OUEquipos = "OUGrupo${NumeroGrupo}_Equipos"
$OUGrupos = "OUGrupo${NumeroGrupo}_Grupos"

$GrupoAdmins = "GGGrupo${NumeroGrupo}_Admins"
$GrupoEmpleados = "GGGrupo${NumeroGrupo}_Empleados"

# ============================================================================
# FUNCIONES
# ============================================================================
function Escribir-Log {
    param(
        [string]$Mensaje,
        [ValidateSet("INFO", "ADVERTENCIA", "ERROR")]
        [string]$Tipo = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $MensajeFinal = "[$Timestamp] [$Tipo] $Mensaje"
    Write-Host $MensajeFinal
    Add-Content -Path $LogFile -Value $MensajeFinal -Encoding UTF8
}

function Crear-UO {
    param([string]$Nombre, [string]$RutaPadre)
    try {
        $OU = Get-ADOrganizationalUnit -Filter "Name -eq '$Nombre'" -SearchBase $RutaPadre -ErrorAction SilentlyContinue
        if ($OU) {
            Escribir-Log "La OU '$Nombre' ya existe." "ADVERTENCIA"
            return $OU.DistinguishedName
        }
        New-ADOrganizationalUnit -Name $Nombre -Path $RutaPadre -ErrorAction Stop
        Escribir-Log "OU '$Nombre' creada exitosamente."
        return "OU=$Nombre,$RutaPadre"
    }
    catch {
        Escribir-Log "Error al crear OU '$Nombre': $_" "ERROR"
        return $null
    }
}

function Crear-Grupo {
    param([string]$Nombre, [string]$RutaPadre, [string]$Descripcion)
    try {
        $Grupo = Get-ADGroup -Filter "Name -eq '$Nombre'" -ErrorAction SilentlyContinue
        if ($Grupo) {
            Escribir-Log "El grupo '$Nombre' ya existe." "ADVERTENCIA"
            return $Grupo.DistinguishedName
        }
        New-ADGroup -Name $Nombre -GroupScope Global -GroupCategory Security -Path $RutaPadre -Description $Descripcion -ErrorAction Stop
        Escribir-Log "Grupo de seguridad '$Nombre' creado exitosamente."
        return "CN=$Nombre,$RutaPadre"
    }
    catch {
        Escribir-Log "Error al crear grupo '$Nombre': $_" "ERROR"
        return $null
    }
}

function Crear-Usuario {
    param(
        [string]$NombreUsuario,
        [string]$Nombre,
        [string]$Apellido,
        [string]$Puesto,
        [string]$RutaPadre,
        [securestring]$Contrasena
    )
    try {
        $Usuario = Get-ADUser -Filter "SamAccountName -eq '$NombreUsuario'" -ErrorAction SilentlyContinue
        if ($Usuario) {
            Escribir-Log "El usuario '$NombreUsuario' ya existe." "ADVERTENCIA"
            return $Usuario.DistinguishedName
        }
        $NombreCompleto = "$Nombre $Apellido"
        New-ADUser -SamAccountName $NombreUsuario `
                   -UserPrincipalName "$NombreUsuario@$([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name)" `
                   -Name $NombreCompleto `
                   -GivenName $Nombre `
                   -Surname $Apellido `
                   -DisplayName $NombreCompleto `
                   -Title $Puesto `
                   -Path $RutaPadre `
                   -AccountPassword $Contrasena `
                   -Enabled $true `
                   -ChangePasswordAtLogon $false `
                   -ErrorAction Stop
        Escribir-Log "Usuario '$NombreUsuario' ($NombreCompleto) creado exitosamente."
        return "CN=$NombreCompleto,$RutaPadre"
    }
    catch {
        Escribir-Log "Error al crear usuario '$NombreUsuario': $_" "ERROR"
        return $null
    }
}

function Agregar-UsuarioAlGrupo {
    param([string]$NombreUsuario, [string]$NombreGrupo)
    try {
        Add-ADGroupMember -Identity $NombreGrupo -Members $NombreUsuario -ErrorAction Stop
        Escribir-Log "Usuario '$NombreUsuario' agregado al grupo '$NombreGrupo'."
    }
    catch {
        Escribir-Log "Error al agregar usuario '$NombreUsuario' al grupo '$NombreGrupo': $_" "ERROR"
    }
}

# ============================================================================
# CARGA OBLIGATORIA DEL CSV (con control de errores)
# ============================================================================
if (-not (Test-Path $RutaCSV)) {
    Escribir-Log "ERROR: No se encuentra el archivo CSV en $RutaCSV" "ERROR"
    Write-Error "Archivo CSV no encontrado. Debe existir 'Usuarios_Grupo$NumeroGrupo.csv' en la misma carpeta del script."
    exit 1
}

try {
    $Usuarios = Import-Csv -Path $RutaCSV -Delimiter "," -Encoding UTF8
    if ($Usuarios.Count -lt 6) {
        Escribir-Log "ADVERTENCIA: Se encontraron $($Usuarios.Count) usuarios en el CSV. Se recomiendan exactamente 6." "ADVERTENCIA"
    }
    Escribir-Log "CSV cargado correctamente desde $RutaCSV : $($Usuarios.Count) usuarios encontrados."
}
catch {
    Escribir-Log "ERROR al leer el CSV: $_" "ERROR"
    Write-Error "No se pudo leer el CSV. Verifica que esté guardado como 'CSV (delimitado por comas)' y con columnas: Nombre,Apellido,Usuario,Puesto"
    exit 1
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================
Escribir-Log "=== Iniciando creación de estructura AD para $NombreGrupo ==="

# Crear/log archivo de log
if (Test-Path $LogFile) { Remove-Item $LogFile }
New-Item -Path $LogFile -ItemType File | Out-Null

# 1. Crear OU principal
$OUDN = Crear-UO -Nombre $OUGeneral -RutaPadre $DominioDN
if (-not $OUDN) { exit 1 }

# 2. Crear OUs secundarias
$OUUsuariosDN = Crear-UO -Nombre $OUUsuarios -RutaPadre $OUDN
$OUEquiposDN = Crear-UO -Nombre $OUEquipos -RutaPadre $OUDN
$OUGruposDN = Crear-UO -Nombre $OUGrupos -RutaPadre $OUDN

# 3. Crear grupos de seguridad
$AdminsDN = Crear-Grupo -Nombre $GrupoAdmins -RutaPadre $OUGruposDN -Descripcion "Grupo de Administradores para $NombreGrupo"
$EmpleadosDN = Crear-Grupo -Nombre $GrupoEmpleados -RutaPadre $OUGruposDN -Descripcion "Grupo de Empleados para $NombreGrupo"

# 4. Crear usuarios
Escribir-Log "Creando Usuarios..."
$ContrasenaSegura = ConvertTo-SecureString -String $ContrasenaBase -AsPlainText -Force
$UsuariosCreados = @()

foreach ($usuario in $Usuarios) {
    $UsuarioDN = Crear-Usuario -NombreUsuario $usuario.Usuario `
                                -Nombre $usuario.Nombre `
                                -Apellido $usuario.Apellido `
                                -Puesto $usuario.Puesto `
                                -RutaPadre $OUUsuariosDN `
                                -Contrasena $ContrasenaSegura
    if ($UsuarioDN) {
        $UsuariosCreados += $usuario
    }
}

# 5. Asignar usuarios a grupos
Escribir-Log "Asignando usuarios a grupos..."
if ($UsuariosCreados.Count -ge 1) {
    Agregar-UsuarioAlGrupo -NombreUsuario $UsuariosCreados[0].Usuario -NombreGrupo $GrupoAdmins
    for ($i = 1; $i -lt $UsuariosCreados.Count; $i++) {
        Agregar-UsuarioAlGrupo -NombreUsuario $UsuariosCreados[$i].Usuario -NombreGrupo $GrupoEmpleados
    }
}

# 6. Generar CSV de salida
Escribir-Log "Creando archivo CSV con datos de usuarios..."
$RutaSalidaCSV = Join-Path -Path $PSScriptRoot -ChildPath "Usuarios_Generados_Grupo$NumeroGrupo.csv"
try {
    $UsuariosCSV = foreach ($usuario in $UsuariosCreados) {
        [PSCustomObject]@{
            NombreUsuario = $usuario.Usuario
            NombreCompleto = "$($usuario.Nombre) $($usuario.Apellido)"
            Puesto = $usuario.Puesto
            Grupo = if ($usuario.Usuario -eq $UsuariosCreados[0].Usuario) { $GrupoAdmins } else { $GrupoEmpleados }
            Contrasena = $ContrasenaBase
            FechaCreacion = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    $UsuariosCSV | Export-Csv -Path $RutaSalidaCSV -Encoding UTF8 -NoTypeInformation -Force
    Escribir-Log "Archivo CSV de salida creado en: $RutaSalidaCSV"
}
catch {
    Escribir-Log "Error al crear CSV de salida: $_" "ERROR"
}

# ============================================================================
# RESUMEN FINAL
# ============================================================================
Escribir-Log "=== RESUMEN DE LA EJECUCION ==="
Escribir-Log "Grupo: $NombreGrupo"
Escribir-Log "UOs creadas: $OUGeneral, $OUUsuarios, $OUEquipos, $OUGrupos"
Escribir-Log "Grupos de seguridad: $GrupoAdmins, $GrupoEmpleados"
Escribir-Log "Usuarios creados: $($UsuariosCreados.Count)"
Escribir-Log "Archivo CSV entrada: $RutaCSV"
Escribir-Log "Archivo CSV salida: $RutaSalidaCSV"
Escribir-Log "Log completo: $LogFile"
Escribir-Log "=== FIN DEL SCRIPT ==="

