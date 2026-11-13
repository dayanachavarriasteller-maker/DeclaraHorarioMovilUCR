import 'package:declara_horario/domain/rules/schedule_grid.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario_movil/core/theme/ucr_theme.dart';
import 'package:declara_horario_movil/domain/declaration_draft.dart';
import 'package:declara_horario_movil/domain/grid_editing.dart';
import 'package:declara_horario_movil/features/declaration/week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DeclarationDraft _draft({List<DraftInterval>? intervals}) => DeclarationDraft(
  jobs: [
    DraftJob(
      key: 'ucr',
      kind: JobKind.ucr,
      name: 'Sede del Sur',
      workload: '1/4 TC',
    ),
    DraftJob(
      key: 'ext',
      kind: JobKind.external,
      name: 'Colegio',
      workload: '1/8 TC',
    ),
  ],
  intervals: intervals,
);

DraftInterval _i(String key, String job, Weekday day, int start, int end) =>
    DraftInterval(
      key: key,
      jobKey: job,
      day: day,
      startMinutes: start * 60,
      endMinutes: end * 60,
    );

List<(Weekday, int, int)> _ranges(DeclarationDraft d, String job) => [
  for (final i in d.sortedIntervals.where((i) => i.jobKey == job))
    (i.day, i.startMinutes, i.endMinutes),
];

void main() {
  const mon = Weekday.monday;

  group('GridEditing (reglas de la cuadrícula del original)', () {
    test('tocar horas seguidas forma un solo intervalo', () {
      final d = _draft();
      for (final m in [480, 540]) {
        expect(
          GridEditing.tap(d, 'ucr', GridCell(mon, m)),
          isA<GridTapChanged>(),
        );
      }
      expect(_ranges(d, 'ucr'), [(mon, 480, 600)]);
    });

    test('tocar de nuevo libera la hora y parte el intervalo', () {
      final d = _draft(intervals: [_i('a', 'ucr', mon, 8, 11)]);
      final r = GridEditing.tap(d, 'ucr', const GridCell(mon, 540));
      expect(r, isA<GridTapChanged>().having((r) => r.added, 'added', false));
      expect(_ranges(d, 'ucr'), [(mon, 480, 540), (mon, 600, 660)]);
    });

    test('el almuerzo está cerrado', () {
      final d = _draft();
      expect(
        GridEditing.tap(d, 'ucr', const GridCell(mon, 720)),
        isA<GridTapBlocked>(),
      );
      expect(d.intervals, isEmpty);
    });

    test('no se toma una hora de otro trabajo (traslape)', () {
      final d = _draft(intervals: [_i('a', 'ext', mon, 8, 10)]);
      final r = GridEditing.tap(d, 'ucr', const GridCell(mon, 540));
      expect(r, isA<GridTapBlocked>());
      expect((r as GridTapBlocked).message, contains('ocupada por Colegio'));
      expect(_ranges(d, 'ucr'), isEmpty);
    });

    test('no pasa de las horas de la jornada', () {
      // 1/8 TC = 5 h.
      final d = _draft(intervals: [_i('a', 'ext', mon, 7, 12)]);
      final r = GridEditing.tap(d, 'ext', const GridCell(Weekday.tuesday, 420));
      expect((r as GridTapBlocked).message, contains('Ya ubicó'));
    });

    test('sin jornada escogida no deja marcar', () {
      final d = _draft()..jobs.first.workload = '';
      expect(
        GridEditing.tap(d, 'ucr', const GridCell(mon, 480)),
        isA<GridTapBlocked>(),
      );
    });

    test('un día no pasa de 10 horas', () {
      final d = _draft(
        intervals: [_i('a', 'ucr', mon, 7, 12), _i('b', 'ext', mon, 13, 18)],
      )..jobs.first.workload = '1 TC';
      final r = GridEditing.tap(d, 'ucr', const GridCell(mon, 18 * 60));
      expect((r as GridTapBlocked).message, contains('máximo diario'));
    });

    test('no más de 6 horas seguidas sin una hora de descanso', () {
      final d = _draft(intervals: [_i('a', 'ucr', Weekday.tuesday, 13, 19)])
        ..jobs.first.workload = '1 TC';
      // 13:00-19:00 son 6 h: la séptima seguida no se permite...
      final r = GridEditing.tap(
        d,
        'ucr',
        const GridCell(Weekday.tuesday, 19 * 60),
      );
      expect(
        (r as GridTapBlocked).message,
        contains('sin una hora de descanso'),
      );
      // ...pero con una hora de descanso (19:00-20:00) sí.
      expect(
        GridEditing.tap(d, 'ucr', const GridCell(Weekday.tuesday, 20 * 60)),
        isA<GridTapChanged>(),
      );
    });

    test('el tramo continuo une trabajos distintos', () {
      final d = _draft(
        intervals: [
          _i('a', 'ucr', Weekday.tuesday, 13, 17),
          _i('b', 'ext', Weekday.tuesday, 17, 19),
        ],
      )..jobs.first.workload = '1 TC';
      final r = GridEditing.tap(
        d,
        'ucr',
        const GridCell(Weekday.tuesday, 19 * 60),
      );
      expect(r, isA<GridTapBlocked>());
    });

    test('un traslape ya registrado abre el intervalo para corregirlo', () {
      final d = _draft(
        intervals: [_i('a', 'ucr', mon, 8, 12), _i('b', 'ext', mon, 11, 14)],
      );
      final r = GridEditing.tap(d, 'ucr', const GridCell(mon, 660));
      expect((r as GridTapConflict).interval.key, 'a');
    });
  });

  testWidgets('la cuadrícula cabe en 412 dp y reporta la media hora tocada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    GridCell? tapped;
    final d = _draft(
      intervals: [_i('a', 'ucr', mon, 8, 12), _i('b', 'ext', mon, 11, 14)],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: UcrTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                WeekGridJobPicker(
                  draft: d,
                  selectedJobKey: 'ucr',
                  onSelected: (_) {},
                ),
                WeekGrid(
                  draft: d,
                  selectedJobKey: 'ucr',
                  onCellTap: (c) => tapped = c,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.textContaining('Conflicto'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Miércoles 09:00 a 10:00, libre'));
    expect(tapped, const GridCell(Weekday.wednesday, 540));
  });
}
