# 📄 Documentación de Tarea: Script de automatización con CSV
## Autor: Jaime Portilla Pérez
## Fecha: 10/01/2026

# 1. Objetivo
Crear un script que realice las siguientes tareas:
- Recibir rutas de CSV como parámetros.
- Importar datos desde CSV.
- Crear UOs (Unidades Organizativas), grupos y usuarios solo si no existen.
- Asignar usuarios a grupos según el CSV.
- Utilizar funciones para mejorar la modularidad.
- Incluir una cabecera profesional (autor, versión, fecha).
- Evitar datos hardcodeados; lectura únicamente desde CSV.
- Realizar comprobaciones básicas de validez.
- Generar un archivo de logs con información relevante del proceso.

# 2. Desarrollo del Script
El script está desarrollado en PowerShell y cumple los requisitos indicados en el objetivo. A continuación se describen sus principales características y funcionalidades:

- **Parámetros de entrada**: Acepta rutas de archivos CSV como parámetros, facilitando su personalización y reutilización.
- **Importación de datos**: Utiliza `Import-Csv` para leer los datos desde los archivos CSV.
- **Creación de objetos**: Implementa funciones para crear Unidades Organizativas (UOs), grupos y usuarios en Active Directory, comprobando previamente si ya existen para evitar duplicados.
- **Funciones modulares**: Estructurado en funciones para mejorar la legibilidad y facilitar el mantenimiento.
- **Comprobaciones básicas**: Valida los datos antes de realizar las operaciones.
- **Generación de logs**: Crea un archivo de registro (log) que documenta las acciones realizadas y los errores encontrados.
- **Asignación de usuarios a grupos**: Asigna usuarios a los grupos correspondientes según los datos del CSV.

![Estructura de ejemplo](img/image5.png)

![Proceso y resultados](img/image6.png)





--- 

# 3. Ejecución del Script
Requisitos: PowerShell con privilegios de administrador y el módulo `ActiveDirectory` (RSAT) instalado.

Para ejecutar el script, abre PowerShell como Administrador y usa el siguiente comando (reemplaza las rutas de los archivos CSV según corresponda):

```powershell
.\ScriptAutomatizacion.ps1 "C:\ruta\UOs.csv"
```

![Captura de ejecución](img/image7.png)

Una vez finalizada la ejecución, revisa el archivo de logs generado para verificar que todas las operaciones se realizaron correctamente.

![Resumen de logs](img/image-2.png)

Las siguientes imágenes muestran ejemplos de la estructura de los archivos CSV utilizados:

![Ejemplo CSV](img/image9.png)

Se puede comprobar en Active Directory que las UOs, grupos y usuarios se crearon según lo especificado en los CSV.

Se crearon las siguientes UOs:
![UOs creadas](img/image.png)

Se crearon los siguientes grupos:
![Grupos creados](img/image0.png)

Los siguientes usuarios fueron creados y asignados a sus respectivos grupos:

![Usuarios creados y asignados](img/image-1.png)

Cada usuario fue asignado al grupo indicado en el CSV.

![Resultado final](img/image-3.png)

--- 

# 4. Conclusión
El script desarrollado cumple todos los requisitos establecidos en el objetivo inicial. ✅

La automatización de la creación de UOs, grupos y usuarios a partir de archivos CSV facilita la gestión administrativa y reduce errores humanos. Su estructura modular y la generación de logs permiten un mantenimiento sencillo y una auditoría clara de las acciones realizadas. En resumen, es una herramienta eficaz para la administración de Active Directory en entornos empresariales.

---# 5. Referencias
- Documentación oficial de PowerShell: https://docs.microsoft.com/en-us/powershell/
- IA Grok para asistencia en la generación de scripts y resolución de problemas.
