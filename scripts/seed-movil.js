// Prepara los EMULADORES de Firebase con datos FICTICIOS para probar el
// módulo móvil (laboratorio §7: "todas las pruebas con datos ficticios").
//
// Uso (con los emuladores del proyecto original corriendo: `npm run
// emulators` en ../declara_horario/DeclaraHorario):
//
//   node scripts/seed-movil.js
//
// Crea, sin borrar nada más:
//   * sede "Sede del Sur" y carrera "Informática Empresarial";
//   * superior.movil@ucr.ac.cr  (superior)
//   * declarante@ucr.ac.cr / 123456  (declarante activa, con sede, carrera y
//     superior, como exige firestore.rules para crear declaraciones);
//   * dos períodos habilitados y la asignación de cursos de cada uno
//     (workloadAssignments/{periodo}_{uid}), también exigida por las reglas.
//
// Igual que scripts/seed-presentacion.js del original, solo habla con
// emuladores locales y usa sus endpoints REST (sin paquetes extra).
const { readFileSync } = require('node:fs');
const path = require('node:path');

const ORIGINAL = path.join(__dirname, '..', '..', 'declara_horario', 'DeclaraHorario');

const HOSTS = {
  firestore: process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080',
  auth: process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099',
};

const CAMPUS_ID = 'sede-sur';
const UNIT_ID = 'informatica-empresarial';
const PASSWORD = '123456';

const SUPERIOR = {
  email: 'superior.movil@ucr.ac.cr',
  fullName: 'Carlos Jiménez Rojas',
  identification: '102220222',
  phone: '87654321',
  roles: ['superior'],
};

const DECLARANT = {
  email: 'declarante@ucr.ac.cr',
  fullName: 'Ana Pérez Mora',
  identification: '101110111',
  phone: '88887777',
  roles: ['declarant'],
};

// Medianoche de Costa Rica (UTC-6).
const PERIODS = [
  { id: '2027-I', name: 'I Ciclo 2027', cycle: 'I', year: 2027, start: '2027-03-08T06:00:00Z', end: '2027-07-03T06:00:00Z' },
  { id: '2027-II', name: 'II Ciclo 2027', cycle: 'II', year: 2027, start: '2027-08-09T06:00:00Z', end: '2027-12-04T06:00:00Z' },
];

function ensureLocal(host) {
  const name = host.replace(/:\d+$/, '');
  if (!['127.0.0.1', 'localhost', '::1', '[::1]'].includes(name)) {
    console.error(`${host} no es un emulador local; no se toca nada.`);
    process.exit(1);
  }
  return `http://${host}`;
}

function projectId() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  const rc = JSON.parse(readFileSync(path.join(ORIGINAL, '.firebaserc'), 'utf8'));
  return rc.projects.default;
}

async function call(method, url, body) {
  const response = await fetch(url, {
    method,
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${method} ${url}: ${response.status} ${await response.text()}`);
  }
  return response.json();
}

/** Valor REST de Firestore: texto, booleano, entero, fecha o lista. */
function value(v) {
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Number.isInteger(v)) return { integerValue: String(v) };
  return { stringValue: v };
}

const fields = (data) =>
  Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)]));

async function main() {
  const firestore = ensureLocal(HOSTS.firestore);
  const auth = ensureLocal(HOSTS.auth);
  const project = projectId();
  const docs = `${firestore}/v1/projects/${project}/databases/(default)/documents`;
  const put = (docPath, data) => call('PATCH', `${docs}/${docPath}`, { fields: fields(data) });

  /** Crea la cuenta (o reutiliza la existente) con el correo verificado. */
  async function account(email) {
    const lookup = await call(
      'POST',
      `${auth}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,
      { email: [email] },
    );
    let uid = lookup.users && lookup.users[0] && lookup.users[0].localId;
    if (!uid) {
      const created = await call(
        'POST',
        `${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator`,
        { email, password: PASSWORD, returnSecureToken: true },
      );
      uid = created.localId;
    }
    await call('POST', `${auth}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:update`, {
      localId: uid,
      emailVerified: true,
    });
    return uid;
  }

  async function profile(uid, person, extra) {
    await put(`users/${uid}`, {
      fullName: person.fullName,
      identification: person.identification,
      identificationType: 'CEDULA',
      phone: person.phone,
      email: person.email,
      roles: person.roles,
      active: true,
      campusId: CAMPUS_ID,
      unitId: UNIT_ID,
      ...extra,
    });
    await put(`identifications/CEDULA_${person.identification}`, { uid });
  }

  await put(`campuses/${CAMPUS_ID}`, { name: 'Sede del Sur', active: true });
  await put(`units/${UNIT_ID}`, { name: 'Informática Empresarial', active: true, campusId: CAMPUS_ID });

  const superiorUid = await account(SUPERIOR.email);
  await profile(superiorUid, SUPERIOR, {});

  const declarantUid = await account(DECLARANT.email);
  await profile(declarantUid, DECLARANT, { superiorUid });

  for (const p of PERIODS) {
    await put(`periods/${p.id}`, {
      name: p.name,
      startDate: new Date(p.start),
      endDate: new Date(p.end),
      enabled: true,
      createdBy: superiorUid,
      cycle: p.cycle,
      year: p.year,
    });
    // Asignación de la coordinación de carrera: 1/4 TC con 6 h de lecciones.
    await put(`workloadAssignments/${p.id}_${declarantUid}`, {
      declarantUid,
      periodId: p.id,
      lessonMinutes: 360,
      workloadMinutes: 600,
      assignedBy: superiorUid,
      slots: [],
      campusId: CAMPUS_ID,
      unitId: UNIT_ID,
      updatedAt: new Date(),
    });
  }

  console.log(`Emuladores de ${project} listos (datos ficticios):`);
  console.log(`  Declarante: ${DECLARANT.email} / ${PASSWORD}`);
  console.log(`  Superior:   ${SUPERIOR.email} / ${PASSWORD}`);
  console.log(`  Períodos habilitados: ${PERIODS.map((p) => p.name).join(', ')}`);
}

main().catch((error) => {
  console.error('No se pudieron preparar los datos:', error.message);
  process.exit(1);
});
