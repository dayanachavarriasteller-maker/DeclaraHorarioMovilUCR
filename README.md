# DeclaraHorario móvil · UCR Sede del Sur

Módulo móvil (Flutter + Dart) del Sistema de Declaraciones Juradas de Horario y
Jornada de Trabajo. Laboratorio de Desarrollo Móvil, IF0009 Desarrollo de
Software IV.

No es una plataforma nueva: importa el proyecto original
(`../declara_horario/DeclaraHorario`) como paquete Dart y reutiliza sus modelos,
reglas, repositorios, autenticación y backend de Firebase.

## Requisito: ubicación del proyecto original

`pubspec.yaml` importa el original con `path: ../declara_horario/DeclaraHorario`,
así que ambos repositorios deben quedar uno al lado del otro:

```
flutterProyects/
  Declara_Horario_UCR/                 ← este repositorio
  declara_horario/DeclaraHorario/      ← github.com/dayanachavarriasteller-maker/DeclaraHorario
```

## Ejecución

```bash
# 1. Emuladores del proyecto original (otra terminal)
cd ../declara_horario/DeclaraHorario
npm run emulators

# 2. Datos ficticios para la prueba
cd ../../Declara_Horario_UCR
node scripts/seed-movil.js        # declarante@ucr.ac.cr / 123456

# 3. App (vista de teléfono en Chrome)
flutter run -d chrome --dart-define=USE_EMULATORS=true
flutter test
```

> El proyecto original solo tiene configuración Firebase para web
> (`firebase_options.dart`), así que la app corre en Chrome. En una ventana
> ancha se dibuja dentro de un marco de 412 × 892 dp (como un Pixel 7). Para
> compilarla como APK nativa haría falta `flutterfire configure --platforms=android`;
> mientras tanto se prueba en un teléfono Android real desde su navegador
> (siguiente sección).

### Prueba en un teléfono Android (Samsung Galaxy A34)

La app se probó en un **Samsung Galaxy A34 (SM-A346M)** con el teclado Samsung,
conectado por USB a la computadora de desarrollo. Por Wi‑Fi de la universidad
(eduroam) no funciona porque la red aísla los dispositivos entre sí, así que se
usa `adb reverse` para que el teléfono vea los puertos de la computadora como
propios (`localhost`):

```bash
# Con los emuladores corriendo y la depuración USB activada en el teléfono
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8001 --dart-define=USE_EMULATORS=true

# adb está en %LOCALAPPDATA%\Android\Sdk\platform-tools
adb reverse tcp:8001 tcp:8001   # app
adb reverse tcp:8080 tcp:8080   # Firestore
adb reverse tcp:9099 tcp:9099   # Auth
adb reverse tcp:9199 tcp:9199   # Storage
```

Luego se abre `http://localhost:8001` en el navegador del teléfono. Como todo
pasa por `localhost`, no hay que cambiar la configuración de emuladores del
proyecto original.

Ajustes que salieron de esta prueba (commit `0a22960`):

- **Login**: con `AutofillGroup`/`autofillHints` el teclado Samsung no dejaba
  escribir en los campos. Se quitaron; la contraseña usa
  `TextInputType.visiblePassword` sin sugerencias y sigue oculta.
- **Aviso de emuladores**: Firebase muestra la franja «Running in emulator mode»
  sobre la barra de navegación inferior; se oculta con CSS en `web/index.html`
  (solo aparece en desarrollo).

En el teléfono se recorrió y se grabó el flujo completo, sin desbordes: login,
crear declaración, datos incompletos, registro del horario en la cuadrícula,
caso obligatorio del traslape, corregir, guardar, reabrir el borrador, resumen,
validar y descargar el PDF.

> **Ojo con `R` (hot restart)** en `flutter run -d web-server`: si se agregaron
> archivos `.dart` nuevos falla con «Library not defined». En ese caso se detiene
> con `q` y se vuelve a ejecutar `flutter run`.

## Estructura

```
lib/
  main.dart                     Firebase + emuladores (config del original)
  app.dart                      MaterialApp, idioma español, marco de teléfono
  core/
    providers.dart              Registro de repositorios/servicios del original
    navigation.dart             Abrir declaración / resumen
    theme/ucr_colors.dart       Paleta UCR (único lugar con códigos de color)
    theme/ucr_theme.dart        ThemeData + extensión de colores de estado
  domain/
    declaration_draft.dart      Borrador editable ↔ Appointment / ExternalJob
    mobile_validator.dart       Validación (reglas del original + obligatorios)
    grid_editing.dart           Cuadrícula por horas: tocar una hora y sus reglas
  features/
    auth/                       SessionState + LoginScreen
    home/home_screen.dart       R1: lista, estados, nueva declaración
    declaration/                R2–R5: formulario en pestañas, cuadrícula semanal
                                (week_grid.dart), hoja de intervalo, controlador
                                (guardar, validar)
    summary/summary_screen.dart R6: resumen, validación y descarga del PDF
  shared/widgets/ucr_widgets.dart  Firma, franja, StatusChip, IssueTile…
scripts/seed-movil.js           Datos ficticios en los emuladores
test/mobile_validator_test.dart Pruebas 01–04, caso obligatorio, almuerzo y 6 h
test/week_grid_test.dart       Reglas de la cuadrícula y vista a 412 dp
```

## Componentes reutilizados del sistema web

| Del original | Uso en el móvil |
|---|---|
| Modelos (`Declaration`, `DeclarationStatus`, `Appointment`, `ExternalJob`, `TimeBlock`, `Weekday`, `VersionContent`, `HoursSummary`…) | Datos de la declaración, nombres exactos de estado |
| `OverlapDetector`, `TimeRules`, `HoursCalculator` | Traslapes, rangos, formatos y totales |
| `ScheduleValidator` (`checkNotEmpty`, `checkDailyLimit`, `checkWeeklyLimit`, `checkExternalWeeklyLimit`, `checkExternalHours`, `checkContinuousHours`, `checkWorkloadMatch`) | Reglas de negocio |
| `ScheduleRulesConfig`, `GridCell` | Límites del horario (07:00–22:00, almuerzo, 10 h por día, 6 h seguidas) y celdas de la cuadrícula |
| `PdfState`, `PdfBuilderService`, `DownloadPdfButton`, `BrowserFileDownloadService`, `OathTextService` | PDF de la declaración validada (vista previa sin firmas) |
| `WorkloadCatalog` | Opciones de jornada (1/8 TC … 1 TC) |
| `FormValidators` | Correo, identificación, obligatorios |
| `FirebaseAuthService`, `FirestoreUserRepository` | Inicio de sesión y perfil |
| `FirestoreDeclarationRepository.createDraft/watchByDeclarant` | Crear y listar |
| `FirestoreVersionContentRepository` | Guardar/recuperar nombramientos, otras instituciones y observaciones |
| `FirestoreWorkflowService.markValidated / reopenAsDraft` | BORRADOR ↔ VALIDADA |
| `FirebaseEmulators`, `firebase_options.dart`, `firestore.rules` | Mismo backend y mismas reglas |

## Persistencia

El borrador se guarda en Firestore con los repositorios del original
(`declarations/{id}/versions/{v}/appointments|externalJobs`, observaciones y
`declarantSnapshot` de la versión). Al reabrir, `getContent` reconstruye el
borrador (prueba 04). Si la declaración estaba VALIDADA y se edita, primero se
devuelve a BORRADOR con `reopenAsDraft` (las reglas solo permiten editar en
BORRADOR). Validar sin errores bloqueantes llama a `markValidated`.

El PDF no se guarda: «Descargar PDF» (en el Resumen, una vez VALIDADA y sin
cambios pendientes) lo genera en el navegador con `PdfState.buildPreview` del
original a partir de lo guardado en Firestore. Es la vista previa con la marca
«BORRADOR»; el PDF oficial con firmas lo genera Recursos Humanos en el sistema
web.

## Registro del horario

La pestaña **Horario** tiene dos vistas:

- **Semana** (por omisión): cuadrícula lunes–sábado (L K M J V S) de 07:00 a
  22:00 por **horas completas**, como la del sistema web. Se escoge el trabajo en
  «Marcar horas de:» (cada trabajo tiene su color UCR y muestra «7 h de 10 h») y
  se toca cada hora para marcarla; tocarla de nuevo la quita. Las horas seguidas
  del mismo trabajo se guardan como un solo intervalo. Al tocar se aplican las
  reglas del original y, si una no se cumple, no se marca y se explica por qué:
  almuerzo cerrado, hora ocupada por otro trabajo, jornada sin escoger o ya
  completa, más de 10 h en el día o más de 6 h seguidas sin descanso.
- **Lista**: los intervalos por día. El botón «Agregar intervalo» abre una hoja
  con listas «Desde / Hasta» (horas en punto) donde se pueden marcar varios días
  a la vez; avisa traslapes, almuerzo y horas seguidas antes de guardar. Es la
  vía para registrar el caso obligatorio, que la cuadrícula no deja crear.

## Validación de horarios

- La hora final debe ser posterior a la inicial (la hoja de intervalo no deja
  guardar un rango inválido y el validador lo vuelve a revisar).
- Traslapes por intervalo, aunque sean de instituciones diferentes. Caso
  obligatorio: lunes 8:00–12:00 y 11:00–14:00 → «Traslape el lunes … 11:00-12:00
  (60 min)», el intervalo se marca en rojo, «Corregir» abre ese intervalo y el
  botón «Validar» queda deshabilitado hasta corregirlo.
- Contiguos (8–10 y 10–12) no son traslape (misma decisión del original).
- Hora de almuerzo 12:00–13:00 excluida: un intervalo que la toque es un error
  bloqueante. Se revisa por intervalo y para todos los trabajos (como la
  cuadrícula del original; `checkExcludedWindow` del original solo revisa los
  nombramientos UCR).
- Máximo 6 horas seguidas sin una hora de descanso, sumando todos los trabajos
  del día (`checkContinuousHours` del original; un descanso de menos de una hora
  no corta el tramo). No se repite en un día que ya tiene traslape.
- No se aplican las reglas que dependen de la asignación de cursos de la
  coordinación (lecciones, categorías): esa información no se captura en el
  teléfono.

## Pruebas

| Prueba | Cómo se comprueba |
|---|---|
| 01 Declaración válida | `test/…` + guardar y abrir Resumen |
| 02 Horarios traslapados | `test/…` (caso obligatorio) + app |
| 03 Datos incompletos | `test/…`; en la app los campos con `*` muestran el error y el resumen lista lo pendiente |
| 04 Persistencia | `test/…` (ida y vuelta del modelo) + cerrar y reabrir el borrador |
| 05 Vista móvil | Samsung Galaxy A34 (Android) por USB, desde el navegador del teléfono (flujo completo grabado en video); además marco de 412 dp en Chrome y `test/week_grid_test.dart` |

Todas con datos ficticios (`scripts/seed-movil.js`).

### Video de demostración

[`docs/video/video_declaraciones_juradas.mp4`](docs/video/video_declaraciones_juradas.mp4)
(3 min 06 s, 15,4 MB): recorrido completo en el Samsung Galaxy A34 por USB, con
datos ficticios. Login, nueva declaración, datos incompletos, información
laboral, horario en la cuadrícula, caso obligatorio del traslape (lunes
08:00–12:00 y 11:00–14:00), corrección, guardar y reabrir el borrador, resumen,
validar y descargar el PDF. El guion pedía 2 minutos; el video quedó en
3 min 06 s.

### Evidencias visuales (`docs/capturas/`)

Tomadas en Chrome a 412 × 892 dp contra los emuladores:

| Captura | Muestra |
|---|---|
| 01–03 | Login, inicio sin declaraciones, elección de período |
| 04–05 | Formulario (datos) y borrador listado como BORRADOR |
| 06–07 | Caso obligatorio: lunes 08:00–12:00 vs 11:00–14:00 (traslape y almuerzo), y hoja «Corregir intervalo» con Desde/Hasta |
| 08 | Nombramiento UCR y otra institución |
| 09 | Resumen con el traslape y «Validar» deshabilitado (prueba 02) |
| 10–13 | Cuadrícula corregida, resumen sin errores, VALIDADA con «Descargar PDF» e inicio con el estado (prueba 01) |
| 14–15 | Campos obligatorios pendientes (prueba 03) |
| 16 | Cuadrícula: aviso al tocar una hora cuando la jornada ya está completa |

## Identidad visual: justificación

Fuente: Universidad de Costa Rica (2019). *Manual de identidad visual* (3.ª ed.).
Oficina de Divulgación e Información. Las páginas citadas son las del manual
impreso (coinciden con las del PDF).

| Decisión en la app | Pauta del manual | Páginas |
|---|---|---|
| Paleta en `UcrColors`: Celeste #00C0F3, Azul #005DA4, Blanco #FFFFFF, Amarillo #FFE06A, Verde #6DC067 (valores RGB-web del manual, sin alterar). | Colores principales y su codificación | 28 |
| Predominan azul, celeste y blanco; amarillo (BORRADOR) y verde (VALIDADA) solo como acento. No se usan colores secundarios. | Jerarquía de color: los principales predominan, amarillo y verde son acento | 31 |
| Contraste comprobado: azul sobre blanco 6,8:1 para texto y botones; celeste solo como franja decorativa (2,1:1, no apto para texto); amarillo y verde siempre con texto oscuro (12,4:1 y 7,2:1). | Usar contraste adecuado para la accesibilidad de personas con discapacidad visual | 31 |
| Tipografía **Trueno** (Regular, SemiBold y Bold, versión 3.001b, licencia SIL OFL 1.1 incluida en `assets/fonts/Trueno-OFL.txt`), definida una sola vez en `UcrTheme.fontFamily`. | Trueno: tipografía para sitios web y dispositivos electrónicos, de licencia abierta | 24–25 |
| Arimo (sustituta métrica de Arial) queda solo como respaldo (`fontFamilyFallback`) para símbolos que Trueno no trae. | Arial como sustitución cuando la tipografía institucional no está disponible | 24–25 |
| Encabezado: firma a la izquierda sobre fondo blanco, con línea de 4 px debajo para separar del contenido; barra de navegación en azul UCR. | Cintillo celeste, azul o blanco; firma a la izquierda; línea de 4 px de separación; altura mínima 56 px | 117 |
| Firma oficial horizontal en dos líneas, a color sobre fondo blanco, escalada en proporción (`BoxFit.contain`), con espacio libre alrededor. Alto de 56 dp en el encabezado y 106 dp en el inicio de sesión. | Firma horizontal en dos líneas; uso en medios digitales; firma a color sobre fondo claro; área de protección | 36, 39–40, 49 |
| No se reconstruye ni modifica la firma: se usa el SVG oficial publicado por la OCI, convertido a PNG sin recortar ni recolorear (ver `assets/images/LEEME.txt` y `docs/identidad/`). | Firmas con proporción única e inalterable | 32–33 |
| Diseño plano: tarjetas sin elevación, sin gradientes ni sombras decorativas. | Uso mesurado de efectos; diseños planos que prioricen el contenido | 116, 122 |
| Controles Material de Android (botones ≥ 48 dp, selectores de fecha del sistema, listas desplegables, hoja inferior). | Botones, íconos y fondos según los lineamientos de cada sistema operativo | 122 |
| Uso de los símbolos en un proyecto académico del curso. | El estudiantado puede usar los símbolos en proyectos dentro de actividades académicas | 60 |

**Diferencias con el manual que quedan pendientes**

- La p. 122 pide, en aplicaciones, la *firma promocional* a la izquierda (arriba o
  abajo) y una pantalla de carga con la firma promocional dentro del horizonte
  (p. 57). La app usa la firma oficial horizontal (permitida en medios digitales,
  p. 39–40) y no tiene pantalla de carga propia. La firma promocional no está
  publicada; se solicita a la OCI junto con el paquete de elementos gráficos.
- Tamaño mínimo (p. 37): el escudo debe medir al menos 1,5 cm de ancho. En el
  encabezado (56 dp) mide unos 0,8 cm en un teléfono típico; para cumplirlo la
  firma tendría que ocupar unos 105 dp de alto, demasiado para un encabezado
  fijo. En el inicio de sesión sí se cumple: la firma mide 106 dp de alto y el
  escudo unos 96 dp ≈ 1,5 cm (1 dp ≈ 1/160 pulgada; el tamaño físico real varía
  un poco según el teléfono).
- La p. 117 recomienda que la línea de separación de 4 px sea gris; la app la
  pone en celeste UCR como acento institucional.

**Accesibilidad móvil (laboratorio §5.3)**: controles de ≥ 48 dp, etiquetas
visibles en todos los campos, mensajes de error que dicen qué corregir y llevan al
dato con «Corregir», etiquetas de semántica en estados e íconos, y sin desbordes
horizontales a 412 dp.

## Dificultades

- El original solo tiene Firebase para web → ejecución en Chrome con marco de
  teléfono y, en un Android real, desde el navegador del teléfono.
- En eduroam el teléfono no alcanza la computadora (aislamiento entre
  dispositivos) → conexión por USB con `adb reverse`.
- El teclado Samsung no dejaba escribir en el login con autocompletado activo
  → se quitaron las pistas de autocompletado.
- Trueno no está en npm ni en Google Fonts y Font Squirrel no permite
  descargas automáticas → se descargó a mano desde FontSpace (licencia OFL).
  Es más ancha que Arial: se revisaron todas las pantallas a 412 dp y no hay
  desbordes.
- La firma oficial no está en el repositorio del original y el paquete de la OCI
  requiere cuenta institucional → se usó el SVG público de la OCI.
- `flutter_localizations` exige `intl ^0.20`; el original pide `^0.19` →
  `dependency_overrides`.
- Las reglas de Firestore exigen perfil con superior y sede, período
  habilitado y asignación de cursos para crear una declaración → script seed.
- Una sola declaración por período → el seed crea dos períodos.
- La cuadrícula del original (medias horas, columnas de 118 dp) no cabe en un
  teléfono → cuadrícula propia por horas completas con columnas de unos 56 dp,
  que entra en 412 dp sin desplazamiento horizontal, más la vista de lista.
- Registrar el horario con selectores de hora libres era lento y permitía
  minutos sueltos → se marca tocando horas, y la hoja usa horas en punto.
- La regla de 6 horas seguidas y la del almuerzo no estaban en el validador
  móvil → se agregaron con las reglas del original.

## Reflexión técnica

1. **Reutilizado**: modelos, reglas de dominio, repositorios Firestore,
   autenticación, servicio de flujo, catálogo de jornadas, validadores, reglas
   de seguridad y emuladores.
2. **Pantalla pequeña**: la cuadrícula semanal se adaptó a horas completas y seis
   columnas angostas (con vista de lista como alternativa); el formulario se
   dividió en cuatro pestañas; los hallazgos llevan al dato.
3. **Manual UCR**: una sola paleta y tipografía en el tema; estados con colores
   institucionales consistentes con contraste comprobado.
4. **Firmas y aprobación**: añadir las pantallas de juramento y firma
   (`beginDeclarantSigning`, `signAsDeclarant`), la bandeja del superior y
   notificaciones; todo el backend ya existe en el original.
