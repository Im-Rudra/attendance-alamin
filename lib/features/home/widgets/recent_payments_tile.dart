// Recent payments (UX 3b): the last five receipts with a receipt-share button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final List<RecentReceipt>? receipts = ref.watch(todayRecentReceiptsProvider).value;
    final List<Student> students = ref.watch(todayStudentsProvider).value ?? const <Student>[];

    final Widget header = TileHeader(
      icon: Icons.receipt_long_outlined,
      title: l10n.todayRecentTitle,
    );
    if (receipts == null) {
      return TileFrame(header: header, child: const SizedBox(height: 96));
    }
    if (receipts.isEmpty) {
      return TileFrame(
        header: header,
        child: TileMessage(icon: Icons.receipt_long_outlined, message: l10n.todayRecentEmpty),
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
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  InitialsAvatar(name: names[r.studentId] ?? '', size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          names[r.studentId] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.todayRecentLine(fmt.money(r.total), fmt.dateShort(r.paidOn)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.todayRecentShare,
                    icon: const Icon(Icons.share_outlined),
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
