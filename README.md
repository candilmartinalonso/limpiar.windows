🌊 PowerScript Optimizador LEVIATÁN v15.0 - Edición Extrema
LEVIATÁN v15.0 es la versión más potente y agresiva de este script de PowerShell ⚡. Está diseñado para realizar una limpieza, optimización, y actualización del sistema operativo Windows de forma interactiva y profunda. Ideal para conseguir el máximo rendimiento.

⚠️ Advertencia: Ejecutar SIEMPRE como Administrador 🧑‍💻. Este script realiza cambios sensibles en el sistema y aplica tweaks extremos en el registro para mejorar la velocidad.

✨ Novedades y Funciones Extr-mas
Categoría

Descripción

Opción del Menú

🔄 Actualización COMPLETA

Instala todas las actualizaciones de Windows (incluyendo drivers) usando el módulo PSWindowsUpdate y actualiza todos los programas instalados usando Winget.

6

🧼 Limpieza PROFUNDA

Limpieza estándar + cachés de navegadores (Chrome, Edge, Firefox), cachés de miniaturas, MSI Installer Cache y ejecución extrema de Cleanmgr /sagerun:65535.

1

🚀 Tweaks de Registro

Aplica ajustes extremos en el Registro: Deshabilita PagingExecutive, Network Throttling, Power Throttling y acelera el apagado del sistema.

9

🗑️ Servicios/Bloatware

Lista de servicios innecesarios ampliada (incluye Telemetría, Xbox, WSearch, etc.). Eliminación forzada de más aplicaciones preinstaladas de la Store.

4 y 5

🔒 Privacidad/Diagnóstico

Opción dedicada para deshabilitar toda la Telemetría y Diagnóstico de Windows a través de Servicios y Registro.

10

🛠️ Reparación

Ejecuta sfc /scannow, DISM /RestoreHealth y chkdsk C: /scan.

13

💻 ¿Cómo Usar el Menú Interactivo?
Asegúrate de ejecutar PowerShell como Administrador.

Ejecuta el script.

El script te mostrará un MENÚ con 14 opciones.

Ingresa el número de la opción que deseas ejecutar (ej: 1 para Limpieza Profunda) o 14 para ejecutar todas las optimizaciones de forma forzada.

Revisa el archivo de log generado en tu escritorio: Optimizador-Leviatan-Log-v15.0.txt 📝

⚠️ Puntos Clave
Punto de Restauración: El script siempre intenta crear un punto de restauración antes de hacer cualquier cambio (especialmente con la Opción 14).

Actualizaciones: La Opción 6 y 14 requieren permisos de administrador y pueden tardar mucho tiempo si hay muchas actualizaciones pendientes.

Reinicio: Se recomienda encarecidamente reiniciar el sistema después de una ejecución completa (Opción 14) para que todos los cambios en el registro y servicios surtan efecto.

👨‍💻 Autor
Martín Alonso Candil  
📎 GitHub | 📧 candilmartinalonso@gmail.com

📝 Licencia
Este script se distribuye bajo la licencia MIT.  
Úsalo bajo tu propia responsabilidad ⚠️
