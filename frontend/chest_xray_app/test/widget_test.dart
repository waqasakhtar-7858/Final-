import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chest_xray_app/main.dart';

void main() {

  // ─── GROUP 1: App Launch ─────────────────────────────────────────────
  group('App Launch', () {

    testWidgets('App renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('PULMA AI branding is visible on launch', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      expect(find.text('PULMA AI'), findsWidgets);
    });

    testWidgets('Bottom navigation bar shows 3 tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

  });

  // ─── GROUP 2: Navigation ──────────────────────────────────────────────
  group('Navigation', () {

    testWidgets('Tapping Scan tab shows Scan screen', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('Respiratory Scan'), findsOneWidget);
    });

    testWidgets('Tapping History tab shows History screen', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Diagnostic History'), findsOneWidget);
    });

    testWidgets('Tapping Home tab returns to Home screen', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Respiratory\nDisease\nDetection AI'), findsOneWidget);
    });

  });

  // ─── GROUP 3: Home Screen ─────────────────────────────────────────────
  group('Home Screen', () {

    testWidgets('Hero headline is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      expect(find.textContaining('Detection AI'), findsOneWidget);
    });

    testWidgets('Upload Chest X-ray button exists on home', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      expect(find.text('Upload Chest X-ray'), findsWidgets);
    });

    testWidgets('Model Architecture card shows DenseNet-121', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      expect(find.text('DenseNet-121'), findsOneWidget);
    });

    testWidgets('Accuracy shows 98.4%', (WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      expect(find.text('98.4%'), findsWidgets);
    });

  });

  // ─── GROUP 4: Scan Screen ──────────────────────────────────────────────
  group('Scan Screen', () {

    Future<void> goToScan(WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
    }

    testWidgets('Upload zone card is visible', (WidgetTester tester) async {
      await goToScan(tester);
      expect(find.text('Upload Chest X-Ray'), findsOneWidget);
    });

    testWidgets('SELECT CLINICAL IMAGE button is visible', (WidgetTester tester) async {
      await goToScan(tester);
      expect(find.text('SELECT CLINICAL IMAGE'), findsOneWidget);
    });

    testWidgets('Format chips DICOM, JPEG, MAX 25MB are shown', (WidgetTester tester) async {
      await goToScan(tester);
      expect(find.text('DICOM'), findsWidgets);
      expect(find.text('JPEG'), findsWidgets);
      expect(find.text('MAX 25MB'), findsOneWidget);
    });

    testWidgets('Recent Uploads section header is visible', (WidgetTester tester) async {
      await goToScan(tester);
      expect(find.text('Recent Uploads'), findsOneWidget);
    });

    testWidgets('Result card is NOT visible before analysis', (WidgetTester tester) async {
      await goToScan(tester);
      expect(find.text('Diagnosis Result'), findsNothing);
    });

    testWidgets('Info cards are visible', (WidgetTester tester) async {
      await goToScan(tester);
      expect(find.text('Image Requirements'), findsOneWidget);
      expect(find.text('Privacy & Compliance'), findsOneWidget);
    });

  });

  // ─── GROUP 5: History Screen ──────────────────────────────────────────
  group('History Screen', () {

    Future<void> goToHistory(WidgetTester tester) async {
      await tester.pumpWidget(const PulmaApp());
      await tester.pump();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
    }

    testWidgets('History screen title is shown', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.text('Diagnostic History'), findsOneWidget);
    });

    testWidgets('Search bar is present', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Demo patient John Doe is listed', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('Demo patient Sarah Jenkins is listed', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
    });

    testWidgets('Pneumonia badge is shown for Sarah Jenkins', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.text('Pneumonia'), findsWidgets);
    });

    testWidgets('AI Confidence label is shown', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.text('AI Confidence'), findsWidgets);
    });

    testWidgets('Load Previous Reports button is visible', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.text('Load Previous Reports'), findsOneWidget);
    });

    testWidgets('Download All button is visible', (WidgetTester tester) async {
      await goToHistory(tester);
      expect(find.textContaining('Download'), findsOneWidget);
    });

  });

  // ─── GROUP 6: ScanRecord Data Model ───────────────────────────────────
  group('ScanRecord Model', () {

    test('isHealthy returns true for Normal disease', () {
      final r = ScanRecord(
        scanId: 'S1', patientName: 'Test', patientId: '#001',
        date: DateTime.now(), disease: 'Normal',
        confidence: 99.0, imagePath: '',
      );
      expect(r.isHealthy, isTrue);
    });

    test('isHealthy returns false for Pneumonia', () {
      final r = ScanRecord(
        scanId: 'S2', patientName: 'Test', patientId: '#002',
        date: DateTime.now(), disease: 'Pneumonia',
        confidence: 84.5, imagePath: '',
      );
      expect(r.isHealthy, isFalse);
    });

    test('historyNotifier starts with 4 demo records', () {
      expect(historyNotifier.value.length, greaterThanOrEqualTo(4));
    });

    test('formatDate formats correctly', () {
      final result = formatDate(DateTime(2023, 10, 24));
      expect(result, equals('OCT 24, 2023'));
    });

  });

}
