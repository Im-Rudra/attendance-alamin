// Recent payments (UX 3b): the last five receipts with a receipt-share button.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';

class RecentPaymentsTile extends ConsumerWidget {
  const RecentPaymentsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final List<RecentReceipt>? receipts = ref.watch(todayRecentReceiptsProvider).value;
    final List<Student> students = ref.watch(todayStudentsProvider).value ?? const <Student>[];

    final Widget header = TileHeader(
      icon: BhorIcons.receipt,
      title: l10n.todayRecentTitle,
    );
    if (receipts == null) {
      return TileFrame(header: header, child: const BhorSkeleton(height: 96, radius: 12));
    }
    if (receipts.isEmpty) {
      return TileFrame(
        header: header,
        child: TileMessage(icon: BhorIcons.receipt, message: l10n.todayRecentEmpty),
      );
    }

    final Map<String, String> names = <String, String>{
      for (final Student s in students) s.id: s.name,
    };
    return TileFrame(
      header: header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final RecentReceipt r in receipts)
            Padding(
              key: ValueKey<String>('today-receipt-${r.receiptId}'),
              padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
              child: Row(
                children: <Widget>[
                  BhorAvatar(name: names[r.studentId] ?? '', size: 36),
                  const SizedBox(width: BhorSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          names[r.studentId] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: b.type.heading,
                        ),
                        Text(
                          l10n.todayRecentLine(fmt.money(r.total), fmt.dateShort(r.paidOn)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: b.type.meta,
                        ),
                      ],
                    ),
                  ),
                  BhorIconButton(
                    semanticLabel: l10n.todayRecentShare,
                    icon: BhorIcons.share,
                    onPressed: () => shareReceipt(context, receiptId: r.receiptId),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
