// Paper sizes of the printed / saved payment slip (feedback item 2).
//
// A4 puts the slip on the top half of the page; the 80 mm receipt printer
// takes the full roll width and as much height as the slip needs. No widgets.

import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';

/// `local_meta` key of the last paper the teacher printed on (device only).
const String kSlipPaperKey = 'slip_paper';

enum SlipPaper {
  a4('a4'),
  thermal80('thermal80');

  const SlipPaper(this.code);

  /// Stored value.
  final String code;

  /// A4 is the default, also for an unknown stored value.
  static SlipPaper parse(String? code) {
    for (final SlipPaper p in SlipPaper.values) {
      if (p.code == code) return p;
    }
    return SlipPaper.a4;
  }

  /// Logical width the slip is drawn at before it is scaled onto the page.
  /// The roll is narrower, so its slip is drawn narrower too (bigger text).
  double get cardWidth => this == SlipPaper.a4 ? 420 : 300;
}

/// Reads the remembered paper ([SlipPaper.a4] when none).
Future<SlipPaper> readSlipPaper(LocalMetaRepository meta) async =>
    SlipPaper.parse(await meta.getRaw(kSlipPaperKey));

/// Remembers [paper] for next time.
Future<void> writeSlipPaper(LocalMetaRepository meta, SlipPaper paper) =>
    meta.setRaw(kSlipPaperKey, paper.code);
