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
> Android haría falta `flutterfire configure --platforms=android`.

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
  features/
    auth/                       SessionState + LoginScreen
    home/home_screen.dart       R1: lista, estados, nueva declaración
    declaration/                R2–R5: formulario en pestañas, hoja de intervalo,
                                controlador (guardar, validar)
    summary/summary_screen.dart R6: resumen y validación
  shared/widgets/ucr_widgets.dart  Firma, franja, StatusChip, IssueTile…
scripts/seed-movil.js           Datos ficticios en los emuladores
test/mobile_validator_test.dart Pruebas 01–04 y caso obligatorio
```

## Componentes reutilizados del sistema web

| Del original | Uso en el móvil |
|---|---|
| Modelos (`Declaration`, `DeclarationStatus`, `Appointment`, `ExternalJob`, `TimeBlock`, `Weekday`, `VersionContent`, `HoursSummary`…) | Datos de la declaración, nombres exactos de estado |
| `OverlapDetector`, `TimeRules`, `HoursCalculator` | Traslapes, rangos, formatos y totales |
| `ScheduleValidator` (`checkNotEmpty`, `checkDailyLimit`, `checkWeeklyLimit`, `checkExternalWeeklyLimit`, `checkExternalHours`, `checkWorkloadMatch`) | Reglas de negocio |
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

## Validación de horarios

- La hora final debe ser posterior a la inicial (la hoja de intervalo no deja
  guardar un rango inválido y el validador lo vuelve a revisar).
- Traslapes por intervalo, aunque sean de instituciones diferentes. Caso
  obligatorio: lunes 8:00–12:00 y 11:00–14:00 → «Traslape el lunes … 11:00-12:00
  (60 min)», el intervalo se marca en rojo, «Corregir» abre ese intervalo y el
  botón «Validar» queda deshabilitado hasta corregirlo.
- Contiguos (8–10 y 10–12) no son traslape (misma decisión del original).
- No se aplican las reglas que dependen de la asignación de cursos de la
  coordinación (lecciones, categorías, franja 12–13): esa información no se
  captura en el teléfono.

## Pruebas

| Prueba | Cómo se comprueba |
|---|---|
| 01 Declaración válida | `test/…` + guardar y abrir Resumen |
| 02 Horarios traslapados | `test/…` (caso obligatorio) + app |
| 03 Datos incompletos | `test/…`; en la app los campos con `*` muestran el error y el resumen lista lo pendiente |
| 04 Persistencia | `test/…` (ida y vuelta del modelo) + cerrar y reabrir el borrador |
| 05 Vista móvil | Marco de 412 dp, pestañas desplazables, sin desbordes |

Todas con datos ficticios (`scripts/seed-movil.js`).

### Evidencias visuales (`docs/capturas/`)

Tomadas en Chrome a 412 × 892 dp contra los emuladores:

| Captura | Muestra |
|---|---|
| 01–03 | Login, inicio sin declaraciones, elección de período |
| 04–05 | Formulario (datos) y borrador listado como BORRADOR |
| 06–07 | Caso obligatorio: lunes 08:00–12:00 vs 11:00–14:00, conflicto marcado y hoja «Corregir intervalo» |
| 08 | Nombramiento UCR y otra institución |
| 09 | Resumen con el traslape y «Validar» deshabilitado (prueba 02) |
| 10–13 | Horario corregido, resumen sin errores, VALIDADA e inicio con el estado (prueba 01) |
| 14–15 | Campos obligatorios pendientes (prueba 03) |

## Identidad visual (resumen de la justificación)

- **Color**: Azul UCR #005DA4 en barra de navegación, botones y títulos (6,6:1
  sobre blanco). Celeste #00C0F3 solo como franja y acento (2,1:1, no apto para
  texto). Amarillo #FFE06A = BORRADOR y Verde #6DC067 = VALIDADA, siempre como
  fondo con texto oscuro. Definidos una sola vez en `UcrColors`/`UcrTheme`.
- **Tipografía**: Arial como sustituta permitida, mediante Arimo (métricamente
  compatible y libre). Trueno/Myriad Pro no tienen licencia libre.
- **Firma**: solo el archivo oficial `assets/images/firma_ucr.png`, escalado
  proporcionalmente sobre blanco; si falta, se muestra el nombre en texto (nunca
  un logotipo reconstruido).
- **Accesibilidad**: controles de ≥ 48 dp, etiquetas visibles, errores
  específicos con «Corregir», semántica en estados e íconos.

Páginas del manual consultadas: _completar_ (Manual de identidad visual UCR,
3.ª ed., 2019).

## Dificultades

- El original solo tiene Firebase para web → ejecución en Chrome con marco de
  teléfono.
- `flutter_localizations` exige `intl ^0.20`; el original pide `^0.19` →
  `dependency_overrides`.
- Las reglas de Firestore exigen perfil con superior y sede, período
  habilitado y asignación de cursos para crear una declaración → script seed.
- Una sola declaración por período → el seed crea dos períodos.
- La edición por cuadrícula del original no cabe en un teléfono → lista por
  día + hoja inferior por intervalo.

## Reflexión técnica

1. **Reutilizado**: modelos, reglas de dominio, repositorios Firestore,
   autenticación, servicio de flujo, catálogo de jornadas, validadores, reglas
   de seguridad y emuladores.
2. **Pantalla pequeña**: la cuadrícula semanal se cambió por secciones por día;
   el formulario se dividió en cuatro pestañas; los hallazgos llevan al dato.
3. **Manual UCR**: una sola paleta y tipografía en el tema; estados con colores
   institucionales consistentes con contraste comprobado.
4. **Firmas y aprobación**: añadir las pantallas de juramento y firma
   (`beginDeclarantSigning`, `signAsDeclarant`), la bandeja del superior y
   notificaciones; todo el backend ya existe en el original.
