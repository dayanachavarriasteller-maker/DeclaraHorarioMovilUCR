import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/domain/mobile_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Datos ficticios (laboratorio §7).
DeclarationDraft _validDraft() {
  final draft = DeclarationDraft(
    fullName: 'Ana Pérez Mora',
    identification: '101110111',
    unitName: 'Informática Empresarial',
    campusName: 'Sede del Sur',
  );
  draft.jobs.add(DraftJob(
    key: 'ucr',
    kind: JobKind.ucr,
    name: 'Informática Empresarial',
    position: 'Profesora interina',
    workload: '1/4 TC', // 10 h
  ));
  void add(String key, Weekday day, int start, int end) =>
      draft.intervals.add(DraftInterval(
        key: key,
        jobKey: 'ucr',
        day: day,
        startMinutes: start,
        endMinutes: end,
      ));
  add('a', Weekday.monday, 8 * 60, 12 * 60);
  add('b', Weekday.tuesday, 8 * 60, 11 * 60);
  add('c', Weekday.wednesday, 13 * 60, 16 * 60);
  return draft;
}

MobileValidation _validate(DeclarationDraft draft) =>
    const MobileValidator().validate(
      draft,
      periodStart: DateTime(2027, 3, 8),
      periodEnd: DateTime(2027, 7, 3),
    );

void main() {
  test('01 · declaración válida: sin errores y con el total correcto', () {
    final result = _validate(_validDraft());
    expect(result.hasBlocking, isFalse, reason: '${result.issues.map((i) => i.message)}');
    expect(result.hoursSummary.declaredMinutes, 10 * 60);
    expect(result.hoursSummary.expectedMinutes, 10 * 60);
  });

  test('02 · caso obligatorio: lunes 8:00-12:00 y 11:00-14:00 se traslapan',
      () {
    final draft = _validDraft();
    draft.jobs.add(DraftJob(
      key: 'ext',
      kind: JobKind.external,
      name: 'Colegio Técnico de Pérez Zeledón',
      position: 'Docente',
      workload: '1/8 TC',
      startDate: DateTime(2027, 3, 1),
      endDate: DateTime(2027, 12, 1),
    ));
    // Otra institución, mismo día: igual debe detectarse (R4).
    draft.intervals.add(DraftInterval(
      key: 'x',
      jobKey: 'ext',
      day: Weekday.monday,
      startMinutes: 11 * 60,
      endMinutes: 14 * 60,
    ));

    final result = _validate(draft);
    final overlaps = result.issues
        .where((i) => i.code == ValidationIssueCode.externalOverlap)
        .toList();
    expect(overlaps, hasLength(1));
    expect(overlaps.single.blocking, isTrue);
    expect(overlaps.single.targetKeys, containsAll(<String>['a', 'x']));
    expect(overlaps.single.message, contains('11:00-12:00'));
    expect(result.hasBlocking, isTrue);

    // Al corregir (11:00 → 13:00) el traslape desaparece.
    draft.intervals.last.startMinutes = 13 * 60;
    draft.intervals.last.endMinutes = 18 * 60;
    expect(
      _validate(draft).issues.where((i) =>
          i.code == ValidationIssueCode.externalOverlap ||
          i.code == ValidationIssueCode.internalOverlap),
      isEmpty,
    );
  });

  test('traslape entre dos intervalos del mismo nombramiento', () {
    final draft = _validDraft();
    draft.intervals.add(DraftInterval(
      key: 'z',
      jobKey: 'ucr',
      day: Weekday.monday,
      startMinutes: 11 * 60,
      endMinutes: 14 * 60,
    ));
    final result = _validate(draft);
    expect(
      result.issues.where((i) => i.code == ValidationIssueCode.internalOverlap),
      hasLength(1),
    );
  });

  test('intervalos contiguos (8-10 y 10-12) no son traslape', () {
    final draft = _validDraft();
    draft.intervals
      ..clear()
      ..add(DraftInterval(
          key: '1',
          jobKey: 'ucr',
          day: Weekday.friday,
          startMinutes: 8 * 60,
          endMinutes: 10 * 60))
      ..add(DraftInterval(
          key: '2',
          jobKey: 'ucr',
          day: Weekday.friday,
          startMinutes: 10 * 60,
          endMinutes: 12 * 60));
    expect(
      _validate(draft).issues.where((i) =>
          i.code == ValidationIssueCode.internalOverlap),
      isEmpty,
    );
  });

  test('la hora final debe ser posterior a la inicial', () {
    final draft = _validDraft();
    draft.intervals.first.endMinutes = 7 * 60;
    final result = _validate(draft);
    final issue = result.issues
        .firstWhere((i) => i.code == ValidationIssueCode.invalidTimeRange);
    expect(issue.blocking, isTrue);
    expect(issue.targetKeys, <String>['a']);
  });

  test('03 · datos incompletos: señala los campos obligatorios', () {
    final draft = DeclarationDraft(identification: '12');
    draft.jobs.add(DraftJob(key: 'j', kind: JobKind.ucr));
    final messages = _validate(draft).blocking.map((i) => i.message).join('\n');
    expect(messages, contains('nombre completo'));
    expect(messages, contains('Identificación'));
    expect(messages, contains('lugar de trabajo, puesto y tipo de jornada'));
    expect(messages, contains('no tiene horas'));
  });

  test('otra institución: las horas deben coincidir con su jornada', () {
    final draft = _validDraft();
    draft.jobs.add(DraftJob(
      key: 'ext',
      kind: JobKind.external,
      name: 'Fundación X',
      position: 'Consultora',
      workload: '1/8 TC', // 5 h
      institutionType: InstitutionType.foundation,
      startDate: DateTime(2027, 3, 1),
      endDate: DateTime(2027, 12, 1),
    ));
    draft.intervals.add(DraftInterval(
      key: 'e',
      jobKey: 'ext',
      day: Weekday.saturday,
      startMinutes: 8 * 60,
      endMinutes: 10 * 60,
    ));
    final result = _validate(draft);
    expect(
      result.issues.where(
          (i) => i.code == ValidationIssueCode.externalHoursMismatch),
      hasLength(1),
    );
  });

  test('el borrador se reconstruye igual desde el contenido guardado (04)',
      () {
    final draft = _validDraft()..observations = 'Ficticio';
    final start = DateTime(2027, 3, 8);
    final end = DateTime(2027, 7, 3);
    final content = VersionContent(
      version: DeclarationVersion(
        id: 'v1',
        number: 1,
        declarantSnapshot: draft.toSnapshot(),
        observations: draft.observations,
        isLocked: false,
      ),
      appointments: draft.toAppointments(periodStart: start, periodEnd: end),
      externalJobs: draft.toExternalJobs(periodStart: start, periodEnd: end),
    );
    final reopened = DeclarationDraft.fromContent(content);
    expect(reopened.fullName, draft.fullName);
    expect(reopened.identification, draft.identification);
    expect(reopened.observations, 'Ficticio');
    expect(reopened.jobs.single.workload, '1/4 TC');
    expect(reopened.intervals, hasLength(3));
    expect(reopened.totalMinutes, draft.totalMinutes);
  });
}
