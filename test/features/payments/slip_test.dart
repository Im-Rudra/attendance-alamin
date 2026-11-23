// Payment slip (feedback item 2): the slip number on the card, in the history
// rows, in the collected list and in the shared text; the guardian phone and
// the place on the card; Print / Save PDF with A4 and 80 mm paper.

import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/services/print_service.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/features/dues/ui/collection_screen.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/payments/receipt_text.dart';
import 'package:attendance_alamin/features/payments/slip_paper.dart';
import 'package:attendance_alamin/features/payments/slip_pdf.dart';
import 'package:attendance_alamin/features/payments/slip_render.dart';
import 'package:attendance_alamin/features/payments/widgets/receipt_preview.dart';
import 'package:attendance_alamin/features/payments/widgets/slip_actions.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

/// A real 1x1 white PNG, built here so its checksums are right (the PDF
/// builder decodes what it is given).
final Uint8List _tinyPng = _makePng();

Uint8List _makePng() {
  int crc32(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final int b in bytes) {
      c ^= b;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
      }
    }
    return c ^ 0xFFFFFFFF;
  }

  List<int> u32(int v) => <int>[(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final List<int> body = <int>[...type.codeUnits, ...data];
    return <int>[...u32(data.length), ...body, ...u32(crc32(body))];
  }

  return Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...chunk('IHDR', <int>[...u32(1), ...u32(1), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', zlib.encode(<int>[0, 255, 255, 255])),
    ...chunk('IEND', <int>[]),
  ]);
}

class _Launcher extends StatelessWidget {
  const _Launcher(this.onTap);

  final Future<void> Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) => BhorScaffold(
        body: Center(child: BhorButton(label: 'open', onPressed: () => onTap(context))),
      );
}

/// Records what would have gone to the printer / file.
class _FakePrintService implements PrintService {
  final List<({Uint8List pdf, String jobName, double width, double height})> printed =
      <({Uint8List pdf, String jobName, double width, double height})>[];
  final List<({Uint8List pdf, String fileName})> saved = <({Uint8List pdf, String fileName})>[];
  bool saveResult = true;

  @override
  Future<bool> printPdf(Uint8List pdf, {required String jobName, required double pageWidth, required double pageHeight}) async {
    printed.add((pdf: pdf, jobName: jobName, width: pageWidth, height: pageHeight));
    return true;
  }

  @override
  Future<bool> savePdf(Uint8List pdf, {required String fileName}) async {
    saved.add((pdf: pdf, fileName: fileName));
    return saveResult;
  }
}

Finder _key(String k) => find.byKey(ValueKey<String>(k));

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The seed with every receipt numbered `2026-000N` (receipt `rcp-N`).
SeededFakes _numbered({Map<String, Object?>? settings}) {
  final SeededFakes f = seedFakes(encodedSettings: settings);
  final List<Payment> rows = f.payments.payments;
  for (var i = 0; i < rows.length; i++) {
    final Payment p = rows[i];
    rows[i] = Payment(
      id: p.id,
      receiptId: p.receiptId,
      studentId: p.studentId,
      enrollmentId: p.enrollmentId,
      batchId: p.batchId,
      billingMonth: p.billingMonth,
      amount: p.amount,
      paidOn: p.paidOn,
      method: p.method,
      receiptNo: '2026-000${p.receiptId.substring(4)}',
    );
  }
  return f;
}

String _plain(WidgetTester t) => t
    .widgetList<Text>(find.descendant(of: _key('pay-receipt-text'), matching: find.byType(Text)))
    .map((Text w) => w.data ?? w.textSpan?.toPlainText() ?? '')
    .join(' | ');

void main() {
  group('slip number', () {
    testWidgets('the receipt card shows it (Bangla digits)', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showReceiptSheet(c, receiptId: 'rcp-2')),
        overrides: _numbered().overrides,
      );
      await _open(tester);
      expect(tester.widget<Text>(_key('pay-receipt-no')).data, '২০২৬-০০০২');
    });

    testWidgets('the receipt card shows it (English, Latin digits)', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showReceiptSheet(c, receiptId: 'rcp-2')),
        overrides: _numbered().overrides,
        lang: Lang.en,
      );
      await _open(tester);
      expect(tester.widget<Text>(_key('pay-receipt-no')).data, '2026-0002');
      expect(_plain(tester), contains('Slip no.'));
    });

    testWidgets('a receipt without a number has no slip number line', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showReceiptSheet(c, receiptId: 'rcp-2')),
        overrides: seedFakes().overrides,
      );
      await _open(tester);
      expect(_key('pay-receipt-text'), findsOneWidget);
      expect(_key('pay-receipt-no'), findsNothing);
    });

    testWidgets("the student's payment history shows it on every row", (WidgetTester tester) async {
      await pumpApp(
        tester,
        const BhorScaffold(body: SingleChildScrollView(child: PaymentHistoryList(studentId: kStuRahim))),
        overrides: _numbered().overrides,
      );
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Text>(_key('pay-history-no-pay-1')).data, 'নং ২০২৬-০০০১');
      expect(tester.widget<Text>(_key('pay-history-no-pay-2')).data, 'নং ২০২৬-০০০২');
    });

    testWidgets('the Collected list shows it next to the amount', (WidgetTester tester) async {
      await pumpApp(tester, const CollectionScreen(), overrides: _numbered().overrides);
      // Tall, so the whole list is built.
      tester.view.physicalSize = const Size(360, 2200);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Text>(_key('coll-receipt-no-rcp-4')).data, 'নং ২০২৬-০০০৪');
    });

    group('shared text', () {
      final ReceiptFacts base = ReceiptFacts(
        studentName: 'রহিম',
        roll: '12',
        batchName: 'ফিজিক্স এ',
        rows: <Payment>[
          Payment(
            id: 'p',
            receiptId: 'r',
            studentId: 's',
            enrollmentId: 'e',
            batchId: 'b',
            billingMonth: const YearMonth(2026, 11),
            amount: 1000,
            paidOn: kToday,
            method: PaymentMethod.cash,
            receiptNo: '2026-0007',
          ),
        ],
        partialMonths: const <YearMonth>{},
        remaining: 0,
      );

      String render(Lang lang, ReceiptFacts f, {String template = ''}) => renderReceiptText(
            facts: f,
            template: template.isEmpty ? DefaultTemplates.receipt(lang) : template,
            center: 'আলো কোচিং',
            fmt: AppFormat(lang),
            l10n: lookupAppLocalizations(Locale(lang.code)),
            today: kToday,
            methodLabel: 'Cash',
            paidOn: kToday,
          );

      final ReceiptFacts unnumbered = ReceiptFacts(
        studentName: base.studentName,
        roll: base.roll,
        batchName: base.batchName,
        rows: <Payment>[
          Payment(
            id: 'p',
            receiptId: 'r',
            studentId: 's',
            enrollmentId: 'e',
            batchId: 'b',
            billingMonth: const YearMonth(2026, 11),
            amount: 1000,
            paidOn: kToday,
            method: PaymentMethod.cash,
          ),
        ],
        partialMonths: const <YearMonth>{},
        remaining: 0,
      );

      test('the Bangla default names the slip, in Bangla digits', () {
        final String t = render(Lang.bn, base);
        expect(t.split('\n').first, 'রসিদ নং ২০২৬-০০০৭ — আলো কোচিং');
      });

      test('the English default names the slip', () {
        final String t = render(Lang.en, base);
        expect(t.split('\n').first, 'Receipt #2026-0007 — আলো কোচিং');
      });

      test('a receipt without a number keeps the old first line', () {
        expect(render(Lang.bn, unnumbered).split('\n').first, 'রসিদ — আলো কোচিং');
        expect(render(Lang.en, unnumbered).split('\n').first, 'Receipt — আলো কোচিং');
      });

      test("a teacher's own template is left exactly as written", () {
        expect(render(Lang.en, base, template: 'Thanks {student}'), 'Thanks রহিম');
        expect(render(Lang.en, base, template: 'No. {receipt_no} / {amount}'), 'No. 2026-0007 / 1,000');
      });
    });
  });

  group('guardian phone and place on the card', () {
    testWidgets('the card has the guardian phone and the place name, phone and address', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      f.places.places[0] = const Place(
        id: kDefaultPlaceId,
        name: 'আলামিন কোচিং',
        phone: '01711000000',
        address: 'মিরপুর, ঢাকা',
        sortOrder: 0,
      );
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showReceiptSheet(c, receiptId: 'rcp-2')),
        overrides: f.overrides,
      );
      await _open(tester);
      expect(tester.widget<Text>(_key('pay-receipt-guardian-phone')).data, '০১৮১১২২৩৩৪৪');
      expect(tester.widget<Text>(_key('pay-receipt-centre')).data, 'আলামিন কোচিং');
      expect(tester.widget<Text>(_key('pay-receipt-centre-phone')).data, '০১৭১১০০০০০০');
      expect(tester.widget<Text>(_key('pay-receipt-centre-address')).data, 'মিরপুর, ঢাকা');
    });

    testWidgets('a place without a phone uses the centre settings (default place)', (WidgetTester tester) async {
      final SeededFakes f = seedFakes(encodedSettings: <String, Object?>{
        SettingKeys.centerPhone.id: '01799887766',
        SettingKeys.centerAddress.id: 'Dhaka',
      });
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showReceiptSheet(c, receiptId: 'rcp-2')),
        overrides: f.overrides,
        lang: Lang.en,
      );
      await _open(tester);
      expect(tester.widget<Text>(_key('pay-receipt-centre-phone')).data, '01799887766');
      expect(tester.widget<Text>(_key('pay-receipt-centre-address')).data, 'Dhaka');
      expect(tester.widget<Text>(_key('pay-receipt-guardian-phone')).data, '01811223344');
    });

    test('resolveReceiptCentre: another place never borrows the centre phone', () {
      const Place home = Place(id: 'p2', name: 'Home', sortOrder: 1);
      final ReceiptCentre c = resolveReceiptCentre(
        place: home,
        centerName: 'Main',
        centerPhone: '017',
        centerAddress: 'Dhaka',
      );
      expect(c.name, 'Home');
      expect(c.phone, '');
      expect(c.address, '');
      final ReceiptCentre none = resolveReceiptCentre(
        place: null,
        centerName: ' Main ',
        centerPhone: '017',
        centerAddress: 'Dhaka',
      );
      expect((none.name, none.phone, none.address), ('Main', '017', 'Dhaka'));
    });
  });

  group('PDF', () {
    String head(Uint8List b) => String.fromCharCodes(b.sublist(0, 5));

    test('A4: a one-page PDF, the slip on the top half', () async {
      final Uint8List pdf =
          await buildSlipPdf(png: _tinyPng, pixelWidth: 1260, pixelHeight: 1300, paper: SlipPaper.a4, title: '2026-0007');
      expect(head(pdf), '%PDF-');
      expect(pdf.length, greaterThan(500));
      final PdfPageFormat page = _page(SlipPaper.a4, 1260, 1300);
      expect(page.width, closeTo(595.27, 0.1));
      expect(page.height, closeTo(841.89, 0.1));
      final ({double width, double height}) size = slipDrawSize(SlipPaper.a4, pixelWidth: 1260, pixelHeight: 1300);
      expect(size.width, lessThanOrEqualTo(kA4SlipMaxWidth));
      expect(size.height, lessThanOrEqualTo((page.height - 2 * kA4Margin) / 2 + 0.001));
      // Same proportions as the picture.
      expect(size.height / size.width, closeTo(1300 / 1260, 0.001));
    });

    test('80 mm: roll width, as tall as the slip', () async {
      final Uint8List pdf =
          await buildSlipPdf(png: _tinyPng, pixelWidth: 900, pixelHeight: 1500, paper: SlipPaper.thermal80);
      expect(head(pdf), '%PDF-');
      final PdfPageFormat page = _page(SlipPaper.thermal80, 900, 1500);
      expect(page.width, closeTo(226.77, 0.1));
      final ({double width, double height}) size = slipDrawSize(SlipPaper.thermal80, pixelWidth: 900, pixelHeight: 1500);
      expect(size.width, closeTo(226.77 - 2 * kThermalMargin, 0.1));
      expect(size.height, closeTo(size.width * 1500 / 900, 0.001));
      expect(page.height, greaterThan(size.height + 2 * kThermalMargin));
    });

    test('a taller slip makes a taller 80 mm page', () {
      final PdfPageFormat short = _page(SlipPaper.thermal80, 900, 1000);
      final PdfPageFormat tall = _page(SlipPaper.thermal80, 900, 1800);
      expect(tall.height, greaterThan(short.height));
      expect(tall.width, short.width);
    });

    test('paper codes round-trip; anything unknown is A4', () {
      expect(SlipPaper.parse('thermal80'), SlipPaper.thermal80);
      expect(SlipPaper.parse('a4'), SlipPaper.a4);
      expect(SlipPaper.parse(null), SlipPaper.a4);
      expect(SlipPaper.parse('legal'), SlipPaper.a4);
      expect(SlipPaper.thermal80.cardWidth, lessThan(SlipPaper.a4.cardWidth));
    });

    test('the file name carries the slip number', () {
      expect(slipFileName('2026-0007'), 'slip-2026-0007.pdf');
      expect(slipFileName(''), 'receipt.pdf');
    });
  });

  group('Print / Save PDF', () {
    late SeededFakes fakes;

    Future<_FakePrintService> pumpSheet(WidgetTester tester, {Lang lang = Lang.bn}) async {
      final _FakePrintService printer = _FakePrintService();
      final SeededFakes f = _numbered();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showReceiptSheet(c, receiptId: 'rcp-2')),
        lang: lang,
        viewport: TestViewport.desktop,
        overrides: <Override>[
          ...f.overrides,
          printServiceProvider.overrideWithValue(printer),
          slipRendererProvider.overrideWithValue(
            (BuildContext c, Widget card, SlipPaper p) async => SlipImage(png: _tinyPng, width: 840, height: 900),
          ),
        ],
      );
      fakes = f;
      await _open(tester);
      return printer;
    }

    testWidgets('A4 is the default; Print sends a PDF to the printer and remembers the paper',
        (WidgetTester tester) async {
      final _FakePrintService printer = await pumpSheet(tester);
      await tester.tap(_key('pay-receipt-print'));
      await tester.pumpAndSettle();
      expect(_key('pay-paper-a4'), findsOneWidget);
      expect(_key('pay-paper-thermal'), findsOneWidget);
      await tester.tap(_key('pay-print-now'));
      await tester.pumpAndSettle();
      expect(printer.printed, hasLength(1));
      expect(String.fromCharCodes(printer.printed.single.pdf.sublist(0, 5)), '%PDF-');
      expect(printer.printed.single.jobName, 'slip-2026-0002.pdf');
      expect(printer.printed.single.width, closeTo(595.27, 0.1));
      expect(fakes.localMeta.values[kSlipPaperKey], 'a4');
    });

    testWidgets('80 mm: Print uses the roll width; the choice is remembered for the menu',
        (WidgetTester tester) async {
      final _FakePrintService printer = await pumpSheet(tester);
      await tester.tap(_key('pay-receipt-print'));
      await tester.pumpAndSettle();
      await tester.tap(_key('pay-paper-thermal'));
      await tester.pumpAndSettle();
      await tester.tap(_key('pay-print-now'));
      await tester.pumpAndSettle();
      expect(printer.printed, hasLength(1));
      expect(printer.printed.single.width, closeTo(226.77, 0.1));
      expect(printer.printed.single.height, greaterThan(226.77));
      expect(fakes.localMeta.values[kSlipPaperKey], 'thermal80');

      // The ⋮ menu now says 80 mm and uses it without asking.
      await tester.tap(_key('pay-receipt-more'));
      await tester.pumpAndSettle();
      expect(find.text('প্রিন্ট (৮০ মিমি)'), findsOneWidget);
      expect(find.text('PDF সেভ (৮০ মিমি)'), findsOneWidget);
      await tester.tap(_key('pay-receipt-menu-pdf'));
      await tester.pumpAndSettle();
      expect(printer.saved, hasLength(1));
      expect(printer.saved.single.fileName, 'slip-2026-0002.pdf');
      expect(String.fromCharCodes(printer.saved.single.pdf.sublist(0, 5)), '%PDF-');
      expect(find.text('PDF সেভ হয়েছে'), findsOneWidget);
    });

    testWidgets('Save PDF in the panel saves; a cancelled save says nothing', (WidgetTester tester) async {
      final _FakePrintService printer = await pumpSheet(tester, lang: Lang.en);
      printer.saveResult = false;
      await tester.tap(_key('pay-receipt-print'));
      await tester.pumpAndSettle();
      await tester.tap(_key('pay-pdf-save'));
      await tester.pumpAndSettle();
      expect(printer.saved, hasLength(1));
      expect(printer.printed, isEmpty);
      expect(find.text('PDF saved'), findsNothing);
    });

    testWidgets('the menu prints on A4 until another paper was used', (WidgetTester tester) async {
      final _FakePrintService printer = await pumpSheet(tester, lang: Lang.en);
      await tester.tap(_key('pay-receipt-more'));
      await tester.pumpAndSettle();
      expect(find.text('Print (A4)'), findsOneWidget);
      await tester.tap(_key('pay-receipt-menu-print'));
      await tester.pumpAndSettle();
      expect(printer.printed, hasLength(1));
      expect(printer.printed.single.width, closeTo(595.27, 0.1));
    });

    testWidgets('a failing renderer shows a message and nothing is printed', (WidgetTester tester) async {
      final _FakePrintService printer = _FakePrintService();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showReceiptSheet(c, receiptId: 'rcp-2')),
        lang: Lang.en,
        viewport: TestViewport.desktop,
        overrides: <Override>[
          ...seedFakes().overrides,
          printServiceProvider.overrideWithValue(printer),
          slipRendererProvider.overrideWithValue(
            (BuildContext c, Widget card, SlipPaper p) async => throw StateError('no picture'),
          ),
        ],
      );
      await _open(tester);
      await tester.tap(_key('pay-receipt-more'));
      await tester.pumpAndSettle();
      await tester.tap(_key('pay-receipt-menu-print'));
      await tester.pumpAndSettle();
      expect(printer.printed, isEmpty);
      expect(find.text("Couldn't prepare the receipt for printing"), findsOneWidget);
    });
  });
}

PdfPageFormat _page(SlipPaper paper, int w, int h) => slipPageFormat(paper, pixelWidth: w, pixelHeight: h);
