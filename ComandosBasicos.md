# Comandos Básicos de Active Directory

## 🏷️ 1. Nombre del dominio y detalles básicos

Muestra el nombre DNS (DNSRoot), nombre NetBIOS (NetBIOSName), controladores de dominio, modo funcional, etc.

```powershell
Get-ADDomain
```

Para solo el nombre DNS:

```powershell
(Get-ADDomain).DNSRoot
# Ejemplo: grupo4.local
```

## 👥 2. Usuarios

Ver todos los usuarios:

```powershell
Get-ADUser -Filter *
```

Ver usuarios con nombre y cuenta:

```powershell
Get-ADUser -Filter * | Select Name, SamAccountName
```

Buscar un usuario específico:

```powershell
Get-ADUser -Identity "nombre.usuario"
# o por parte del nombre:
Get-ADUser -Filter "Name -like '*Asier*'"
```

Ver propiedades extendidas (correo, OU, etc.):

```powershell
Get-ADUser -Identity "usuario" -Properties EmailAddress, DistinguishedName, Enabled
```

## 📁 3. Unidades Organizativas (OU)

Listar todas las OUs:

```powershell
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName
```

Buscar una OU específica:

```powershell
Get-ADOrganizationalUnit -Filter "Name -eq 'Empleados'"
```

## 👥 4. Grupos

Ver todos los grupos de seguridad:

```powershell
Get-ADGroup -Filter {GroupCategory -eq "Security"} | Select Name, GroupScope
```

Buscar grupos con nombre específico (ej. GGGrupo4_*):

```powershell
Get-ADGroup -Filter "Name -like 'GGGrupo4_*'"
```

Ver miembros de un grupo:

```powershell
Get-ADGroupMember -Identity "GGGrupo4_Admins" | Select Name, ObjectClass
```

## 🔍 5. Buscar cualquier objeto en AD

Buscar usuarios, grupos o equipos:

```powershell
Get-ADObject -Filter "Name -like 'GGGrupo4_*'" | Select Name, ObjectClass, DistinguishedName
```

## 🖥️ 6. Equipos (computers) unidos al dominio

```powershell
Get-ADComputer -Filter * | Select Name, DistinguishedName
```

## 🧭 7. Ver la estructura completa de una OU

Ver todos los objetos (usuarios + grupos) dentro de una OU:

```powershell
Get-ADObject -SearchBase "OU=Empleados,DC=grupo4,DC=local" -Filter *
```



