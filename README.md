# CruzContigo · Frontend iOS

CruzContigo es una app para personas cuidadoras. Permite consultar la información de sus familiares, organizar medicamentos y recordatorios, y acceder a esas pantallas por texto o voz con Frida.

## Funciones disponibles

- **Inicio de sesión.** Acceso con número de teléfono y código de verificación. La sesión se guarda en el Keychain de iOS.
- **Personas y ficha médica.** Registro y consulta de familiares. La ficha se llena en cuatro pasos cortos (tipo de sangre, alergias, enfermedades y detalles opcionales), con respuestas de Sí/No y sugerencias para tocar. Al consultarla, el tipo de sangre y las alergias peligrosas aparecen primero y el resto queda plegado.
- **Ficha de emergencia sin conexión.** Desde **Inicio → Emergencia → Ficha de emergencia** (dos toques) se ve un resumen con sangre, alergias, enfermedades, medicamentos activos y contactos. La app guarda una copia protegida en el teléfono, así que también abre en modo avión. Se actualiza al cargar la lista de familiares o al editar la ficha, y se borra al cerrar sesión o al perder el acceso. El código QR solo aparece si la persona titular o su responsable lo permitieron, y el permiso queda registrado.
- **Accesos a la ficha.** Desde la ficha, la persona titular o su responsable pueden autorizar a otra cuenta por su teléfono (cocuidador, solo lectura o profesional de salud) y retirar el acceso en cualquier momento. Para autorizar hay que aceptar el aviso de privacidad, y su versión queda guardada como evidencia. Un profesional bajo convenio solo consulta la ficha, por tiempo limitado, y cada consulta queda registrada. Si te retiran un acceso, la ficha deja de mostrarse en la siguiente consulta.
- **Medicamentos.** Alta, consulta, edición y eliminación de tratamientos por familiar. El formulario guarda dosis, unidad, frecuencia, fechas, existencias y umbral de resurtido. Los tratamientos finalizados aparecen en **Anteriores**.
- **Lectura de recetas.** En iOS 27 con Apple Intelligence disponible, el formulario permite seleccionar una foto de una receta y extraer datos del medicamento. Puedes revisar y corregir los campos antes de guardar. La captura manual está disponible.
- **Recordatorios.** Puedes crear, editar, completar y eliminar avisos de una sola vez para un familiar. Se guardan en la API. El dispositivo donde se guarda el aviso programa la notificación local si tiene permiso.
- **Accesibilidad.** Ajustes de tamaño y grosor del texto, tipografía OpenDyslexic, contraste, apariencia, movimiento y vibración. La interfaz incluye etiquetas para VoiceOver.

## Frida

Desde **Inicio**, abre **Habla con Frida**. Puedes escribir una consulta o dictarla y revisar la transcripción antes de enviarla.

- «¿Qué medicamentos toma mi mamá hoy?»
- «¿Qué recordatorios tengo mañana?»
- «Llévame a Recordatorios»
- «¿A quién puedo avisarle si le pasa algo a mi mamá?»

Para los contactos de emergencia, Frida usa el modelo de similitud semántica
en español de `NaturalLanguage` en el dispositivo. También puedes pedir
«Ver contactos de emergencia» directamente. Frida resuelve el familiar y
muestra un botón que abre la pantalla de contactos.

Frida consulta los datos registrados en la API y puede abrir la pantalla correspondiente. Los cambios se guardan desde las pantallas de Medicamentos y Recordatorios. El dictado requiere permisos de micrófono y reconocimiento de voz, además de disponibilidad de reconocimiento en español en el dispositivo.

Puedes contarle a Frida algo de tu día por texto o voz. Frida responde con
preguntas sencillas según el relato. Cuando termines o después de varias
intervenciones ofrece preparar un resumen para el diario. También puedes
pedírselo con «Guarda esto en mi diario».

En **Revisar resumen**, Apple Intelligence elige fragmentos del relato. Puedes
compararlos con el texto original, editar la nota, elegir el diario y revisar
quién podrá leerla. Si el modelo no está disponible, se conserva el relato. **Guardar en diario** envía la nota a la API con
tu sesión.

Si le dices a Frida que quieres seguir platicando, respeta ese ritmo. Las
expresiones explícitas de peligro abren opciones de apoyo para México sin
iniciar llamadas. Para riesgo de hacerse daño, la app muestra 911, Línea
de la Vida y los contactos de emergencia disponibles en la cuenta.

## Red de cuidado, contactos y diario

- **Red de cuidado (HU-17, HU-26):** invita por teléfono o con un código de un solo uso (`cruzcontigo://invitacion/CODIGO`, registrado en `CruzContigo-Info.plist`) con rol administrador, cocuidador, solo lectura o temporal. El acceso temporal vence solo y no ve la ficha médica salvo que se permita.
- **Contactos de emergencia (RF-15):** en orden de prioridad; salen en la ficha de emergencia sin conexión, en el QR y en el botón de Emergencia.
- **Diario de cuidado (HU-13):** notas por tema con fecha y autor; solo el autor las edita.

Requiere que el backend tenga aplicado `red-de-cuidado.sql`.

## Ejecutar el proyecto

1. Usa macOS con Xcode y el SDK de iOS 27 para compilar la versión actual. El proyecto tiene iOS 26 como mínimo de ejecución. La lectura de recetas requiere iOS 27.
2. Configura `CruzContigo_Backend` con su `.env` y ejecuta `npm ci` y `npm run dev` desde ese repositorio.
3. Abre `CruzContigo.xcodeproj`, selecciona el esquema `CruzContigo` y ejecuta con **⌘R**.
4. En Debug, el simulador usa `http://localhost:3000`. Para usar otra URL, configura `CRUZ_API_URL` en **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**. En un iPhone físico, usa una dirección del backend accesible desde el dispositivo.
5. Ingresa tu número de teléfono. En desarrollo, el código de verificación aparece en la terminal del backend.

La app se conecta a MySQL a través de la API. Las credenciales de la base de datos y el certificado de Aiven se configuran en el backend.

## Pruebas

El target `CruzContigoTests` incluye pruebas unitarias con Swift Testing de modelos y validaciones de familiares, la validación del teléfono, las consultas de Frida los accesos a la ficha médica (`AccesosFichaTests`) y el formulario por pasos y la ficha de emergencia (`FichaEmergenciaTests`). Ejecútalas en Xcode con **Product → Test** o **⌘U**.

Para una prueba manual, registra un familiar, agrega un medicamento y un recordatorio, vuelve a abrir sus pantallas para comprobar que se guardaron y consulta ambos desde Frida.

## Estado actual

Los familiares antiguos sin vínculo admiten recordatorios privados para la cuenta que los crea. Los avisos recurrentes y las alertas automáticas de resurtido quedan pendientes.
