# CruzContigo · Frontend iOS

CruzContigo es una app para personas cuidadoras. Permite consultar la información de sus familiares, organizar medicamentos y recordatorios, y acceder a esas pantallas por texto o voz con Frida.

## Funciones disponibles

- **Inicio de sesión.** Acceso con número de teléfono y código de verificación. La sesión se guarda en el Keychain de iOS.
- **Personas y ficha médica.** Registro y consulta de familiares. La ficha permite editar datos como alergias, padecimientos, tipo de sangre y contactos médicos.
- **Medicamentos.** Alta, consulta, edición y eliminación de tratamientos por familiar. El formulario guarda dosis, unidad, frecuencia, fechas, existencias y umbral de resurtido. Los tratamientos finalizados aparecen en **Anteriores**.
- **Lectura de recetas.** En iOS 27 con Apple Intelligence disponible, el formulario permite seleccionar una foto de una receta y extraer datos del medicamento. Puedes revisar y corregir los campos antes de guardar. La captura manual está disponible.
- **Recordatorios.** Puedes crear, editar, completar y eliminar avisos de una sola vez para un familiar. Se guardan en la API. El dispositivo donde se guarda el aviso programa la notificación local si tiene permiso.
- **Accesibilidad.** Ajustes de tamaño y grosor del texto, tipografía OpenDyslexic, contraste, apariencia, movimiento y vibración. La interfaz incluye etiquetas para VoiceOver.

## Frida

Desde **Inicio**, abre **Habla con Frida**. Puedes escribir una consulta o dictarla y revisar la transcripción antes de enviarla.

- «¿Qué medicamentos toma mi mamá hoy?»
- «¿Qué recordatorios tengo mañana?»
- «Llévame a Recordatorios»

Frida consulta los datos registrados en la API y puede abrir la pantalla correspondiente. Los cambios se guardan desde las pantallas de Medicamentos y Recordatorios. El dictado requiere permisos de micrófono y reconocimiento de voz, además de disponibilidad de reconocimiento en español en el dispositivo.

## Ejecutar el proyecto

1. Usa macOS con Xcode y el SDK de iOS 27 para compilar la versión actual. El proyecto tiene iOS 26 como mínimo de ejecución. La lectura de recetas requiere iOS 27.
2. Configura `CruzContigo_Backend` con su `.env` y ejecuta `npm ci` y `npm run dev` desde ese repositorio.
3. Abre `CruzContigo.xcodeproj`, selecciona el esquema `CruzContigo` y ejecuta con **⌘R**.
4. En Debug, el simulador usa `http://localhost:3000`. Para usar otra URL, configura `CRUZ_API_URL` en **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**. En un iPhone físico, usa una dirección del backend accesible desde el dispositivo.
5. Ingresa tu número de teléfono. En desarrollo, el código de verificación aparece en la terminal del backend.

La app se conecta a MySQL a través de la API. Las credenciales de la base de datos y el certificado de Aiven se configuran en el backend.

## Pruebas

El target `CruzContigoTests` incluye **9 pruebas unitarias con Swift Testing**. Cinco cubren modelos y validaciones de familiares, una cubre la validación del teléfono y tres cubren las consultas de Frida. Ejecútalas en Xcode con **Product → Test** o **⌘U**.

Para una prueba manual, registra un familiar, agrega un medicamento y un recordatorio, vuelve a abrir sus pantallas para comprobar que se guardaron y consulta ambos desde Frida.

## Estado actual

Red de cuidado sigue pendiente como función de la app. Los familiares antiguos sin vínculo admiten recordatorios privados para la cuenta que los crea. Los avisos recurrentes y las alertas automáticas de resurtido quedan pendientes.
