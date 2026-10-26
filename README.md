# CruzContigo

## Medicamentos conectados a la API

La pantalla de medicamentos registra, lista, edita y elimina tratamientos del
familiar seleccionado mediante `/familiares/:id/medicamentos`. Los cambios se
guardan en MySQL a través del backend; el servicio de demostración queda solo
para previews. No incluye recordatorios automáticos en este avance.

1. Actualizar también `CruzContigo_Backend` y ejecutar `npm ci` para generar el
   cliente Prisma actualizado. La API y el formulario se ajustan a la definición
   existente de Aiven. Ver `docs/medicamentos.md` del backend. No crear otra tabla
   ni ejecutar un reset o `db push` en Aiven.
2. Iniciar el backend en la Mac con `npm run dev`, conservando su `.env` de Aiven
   y su certificado CA.
3. Abrir `CruzContigo.xcodeproj` con Xcode compatible con iOS 26 y ejecutar en el
   simulador. En Debug se usa `http://localhost:3000`. También puede configurarse
   `CRUZ_API_URL` en Product → Scheme → Edit Scheme → Run → Arguments → Environment
   Variables. La app se conecta al backend, nunca directamente a Aiven; no poner
   credenciales de MySQL en Xcode. En un iPhone físico, localhost apunta al teléfono,
   por lo que se necesita una dirección de API accesible desde el dispositivo.

Para comprobar el avance: registrar un familiar, abrir Medicamentos, agregar un
tratamiento, salir y volver a entrar para verificar que se conserva, y eliminarlo
desde su detalle. Cambiar de familiar debe mostrar su propia lista. Si el backend
no está disponible, debe aparecer un error al cargar o guardar; el formulario no
debe cerrarse como si hubiera guardado. Se puede reintentar con “Actualizar
medicamentos”.

El formulario separa dosis numérica y unidad, admite presentación, frecuencia,
indicación y existencias opcionales, y guarda el umbral de resurtido (5 días por
defecto). Acepta coma o punto decimal, con un máximo de dos decimales. El umbral
todavía no genera alertas. Los tratamientos finalizados antes de hoy aparecen en
Anteriores; el estado se calcula a partir de la fecha de fin. Ya no se solicitan
vía ni médico porque esas columnas no existen en la tabla.

La API tiene ocho pruebas de integración con una copia local del SQL de Aiven.
La compilación y la prueba visual
de esta app deben realizarse en macOS con Xcode; el entorno Linux no dispone del
SDK de iOS.
