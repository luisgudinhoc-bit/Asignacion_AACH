# Guía de Configuración: Google Cloud Platform & Google Sheets API

Esta guía detalla paso a paso cómo aprovisionar y vincular el proyecto **"Asignación AACH"** con los servicios de Google Cloud (Google Sign-In y Google Sheets API v4), habilitando la arquitectura serverless y costo cero de backend.

---

## 1. Crear o Seleccionar un Proyecto en Google Cloud Console

1. Ingrese a [Google Cloud Console](https://console.cloud.google.com/).
2. En la barra superior, haga clic en el selector de proyectos y seleccione **"Nuevo proyecto"**.
3. Nombre sugerido: `asignacion-aach-despacho`.
4. Haga clic en **Crear**.

---

## 2. Habilitar la API de Google Sheets

1. En el menú de navegación lateral (hamburguesa), vaya a **APIs y servicios** > **Biblioteca**.
2. En la barra de búsqueda escriba: `Google Sheets API`.
3. Seleccione el resultado correspondiente y haga clic en **Habilitar**.

---

## 3. Configurar la Pantalla de Consentimiento de OAuth

1. Diríjase a **APIs y servicios** > **Pantalla de consentimiento de OAuth**.
2. Seleccione el tipo de usuario:
   - **Externo** (recomendado para cuentas personales o de correos corporativos sin Google Workspace Enterprise).
3. Complete los datos básicos:
   - **Nombre de la aplicación:** `Asignación AACH`
   - **Correo de asistencia al usuario:** su correo de administrador.
   - **Datos de contacto del desarrollador:** su correo electrónico.
4. En la sección **Permisos (Scopes)**, agregue:
   - `.../auth/spreadsheets` (Ver, editar, crear y borrar tus hojas de cálculo de Google Sheets).
   - `.../auth/drive.file` (Opcional, para crear hojas nuevas si no existe una predefinida).
5. En **Usuarios de prueba** (Test users):
   - Agregue las cuentas de Google `@gmail.com` de los coordinadores y administradores del despacho que iniciarán sesión en la app.

---

## 4. Crear Credenciales OAuth 2.0 para Android

Para que el inicio de sesión nativo de Google funcione en dispositivos Android, se debe registrar el `applicationId` y la huella digital `SHA-1` del certificado de firma.

### 4.1 Obtener la Huella Digital SHA-1 de Desarrollo
Ejecute el siguiente comando en su terminal:

```bash
# En Windows (usando keytool del JDK):
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copie el valor hexadecimal que aparece en la línea `SHA1: XX:XX:XX:...`.

### 4.2 Registrar el Cliente Android en Google Cloud
1. Vaya a **APIs y servicios** > **Credenciales**.
2. Haga clic en **Crear credenciales** > **ID de cliente de OAuth**.
3. Seleccione **Tipo de aplicación:** `Android`.
4. Nombre: `Asignación AACH Android Debug`.
5. **Nombre del paquete:** `com.aach.asignacionsiniestros` (debe coincidir exactamente con el configurado en `android/app/build.gradle.kts`).
6. **Huella digital del certificado SHA-1:** Pegue la huella obtenida en el paso 4.1.
7. Haga clic en **Crear**.

---

## 5. Preparar la Hoja Maestra de Google Sheets

1. Ingrese a [Google Sheets](https://sheets.google.com/) y cree una nueva hoja de cálculo en blanco.
2. Titule el documento: `CONTROL_OPERATIVO_AACH_2026`.
3. Copie el **Spreadsheet ID** desde la barra de direcciones del navegador:
   ```
   https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   ```
4. En la app móvil, ingrese este ID en la pantalla de **Ajustes > Configuración de Hoja Maestra**.

> **Nota:** La aplicación cuenta con inicialización automática (`autoInitTabs`). Si la hoja está vacía, creará automáticamente las pestañas operativas:
> - `SINIESTROS` (Columnas: ID, Folio, Aseguradora, Ajustador, Estatus, Tipo Evento, Ubicación, Asegurado, Teléfono, Placas, Fecha Asignación, Tipo Cierre, Observaciones, Sincronizado El).
> - `AJUSTADORES` (Catálogo de ajustadores activos y teléfonos).
> - `CATALOGO_ASEGURADORAS` (Lista normalizada de aseguradoras y prefijos de folios).

---

## 6. Sincronización y Modo Offline-First

- **Sin Conexión:** Todos los registros, cambios de estatus y asignaciones se almacenan localmente en la base de datos **Hive** del dispositivo.
- **Conexión Disponible:** La cola de sincronización (`SyncQueueManager`) detecta conectividad activa y transmite los registros pendientes a Google Sheets sin interrumpir la operación del ajustador o coordinador.
