
# 🐲 PowerScript Optimizador LEVIATÁN v11.0

**LEVIATÁN** es un script de PowerShell ⚡ diseñado para realizar una limpieza 🧹, optimización 🚀 y reparación 🛠️ **profunda** del sistema operativo Windows. Ideal para usuarios exigentes, técnicos y entusiastas que desean mantener su equipo funcionando al máximo.

> ⚠️ **Advertencia:** Ejecutar SIEMPRE como **Administrador** 🧑‍💻. Este script realiza cambios sensibles en el sistema operativo.

---

## ✨ Funciones Principales

| Categoría        | Descripción |
|------------------|-------------|
| 🧼 Limpieza Profunda | Elimina archivos temporales, registros, cachés del sistema, restos de actualizaciones, WER logs, logs de CBS, etc. |
| 🚀 Aceleración del Sistema | Libera memoria RAM, aplica configuración de energía máxima, optimiza red y DNS, desactiva servicios innecesarios. |
| 🗑️ Eliminación de Bloatware | Detiene/desactiva servicios como Xbox, Cortana, Telemetría, WMP, entre otros. |
| 🛠️ Reparación Automática | Ejecuta `SFC`, `DISM`, `CHKDSK` y verifica la integridad del sistema. |
| 🔒 Privacidad & Seguridad | Desactiva funciones de recopilación de datos y limpia certificados caducados. |
| 📜 Registro de Actividades | Crea un archivo de log detallado en el escritorio del usuario. |

---

## 📦 ¿Qué Limpia?

🧹 Directorios y cachés limpiados:

- `C:\Windows\Temp`
- `%TEMP%`
- `SoftwareDistribution\Download`
- `Logs\CBS`
- Cachés de DNS
- Papelera de reciclaje 🗑️
- Registros de errores de Windows (WER)
- Aplicaciones preinstaladas innecesarias

---

## ⚙️ Requisitos

- 💻 Windows 10 o superior (x64)
- 🧩 PowerShell ≥ 5.1
- 🧑‍💻 Ejecutar como **Administrador**

---

## 🚀 ¿Cómo usarlo?

1. Haz clic derecho sobre el archivo `.ps1` y selecciona **"Ejecutar con PowerShell como Administrador"** ⚡
2. Espera a que finalice el proceso ⏳
3. Revisa el archivo `Optimizador-Leviatan-Log-v11.0.txt` en tu Escritorio 📝

---

## 🔍 Diagnóstico Incluido

🔧 El script ejecuta automáticamente:

- `sfc /scannow`
- `DISM /Online /Cleanup-Image /RestoreHealth`
- `chkdsk C: /scan`

---

## 🕓 Log de Cambios

- **v11.0** (2025): Limpieza más profunda, desactivación de más servicios, reinicio de red, liberación de RAM, limpieza WER y CBS.
- **v10.2**: Inclusión de log de ejecución y mejoras visuales.
- **v9.0**: Soporte extendido para más versiones de Windows.
- **v8.3**: Versión base pública.

---

## 👨‍💻 Autor

**Martín Alonso Candil**  
📎 [GitHub](https://github.com/candilmartinalonso) | 📧 `candilmartinalonso@gmail.com`

---

## 📝 Licencia

Este script se distribuye bajo la licencia **MIT**.  
Úsalo bajo tu propia responsabilidad ⚠️
