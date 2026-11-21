// The one GoRouter (Arch 1.4, plan M5-A route table). Frozen after M5-A.
//
// Five shell branches (আজ · ব্যাচ · শিক্ষার্থী · বেতন · আরও) in a
// StatefulShellRoute.indexedStack, so each tab keeps its own stack. Detail
// routes (`/batches/:batchId`, `/students/:studentId`, `/fees/s/:studentId`)
// go through AdaptiveDetail: list ‖ detail on wide windows, the detail alone
// on phones. Forms, the roll call and the other full-screen flows sit on the
// root navigator (no navigation chrome). Static segments are declared before
// `:param` siblings. Only this file imports feature screens.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/ds/gallery/ds_gallery_screen.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/adaptive_detail.dart';
import 'package:attendance_alamin/app/shell/adaptive_scaffold.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/attendance/ui/batch_roll_call_launcher.dart';
import 'package:attendance_alamin/features/attendance/ui/roll_call_screen.dart';
import 'package:attendance_alamin/features/backup/ui/backup_review_screen.dart';
import 'package:attendance_alamin/features/backup/ui/backup_screen.dart';
import 'package:attendance_alamin/features/batches/ui/archived_batches_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batches_screen.dart';
import 'package:attendance_alamin/features/dues/ui/collection_screen.dart';
import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/features/extras/ui/bulk_add_screen.dart';
import 'package:attendance_alamin/features/extras/ui/holiday_screen.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';
import 'package:attendance_alamin/features/onboarding/ui/onboarding_screen.dart';
import 'package:attendance_alamin/features/reminders/ui/reminder_priming_screen.dart';
import 'package:attendance_alamin/features/schedule/ui/slot_editor_screen.dart';
import 'package:attendance_alamin/features/search/ui/search_screen.dart';
import 'package:attendance_alamin/features/settings/ui/diagnostics_screen.dart';
import 'package:attendance_alamin/features/settings/ui/help_screen.dart';
import 'package:attendance_alamin/features/settings/ui/more_screen.dart';
import 'package:attendance_alamin/features/settings/ui/payment_methods_screen.dart';
import 'package:attendance_alamin/features/settings/ui/template_editor_screen.dart';
import 'package:attendance_alamin/features/students/ui/left_students_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';

/// Navigator of full-screen routes (`parentNavigatorKey: rootNavigatorKey`).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app router; created once per ProviderContainer.
final routerProvider = Provider<GoRouter>((ref) {
  final GoRouter router = buildRouter(ref.watch(initialLocationProvider));
  ref.onDispose(router.dispose);
  return router;
});

String _param(GoRouterState state, String name) => state.pathParameters[name]!;

/// Detail page: instant on wide windows (the list stays put and only the
/// detail pane changes), a short slide + fade on phones.
Page<void> _detailPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondary, Widget child) {
        if (WindowClass.of(context).isWide) return child;
        final Animation<double> curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Every other page: the Bhor fade + rise (200 ms, ease-out), the same on
/// every platform (WidgetsApp has no Material page transitions).
Page<void> _page(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      arguments: state.extra,
      child: child,
      transitionDuration: BhorMotion.slow,
      reverseTransitionDuration: const Duration(milliseconds: 160),
      transitionsBuilder: bhorPageTransition,
    );

GoRouter buildRouter(String initialLocation) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    errorBuilder: (BuildContext context, GoRouterState state) => const NotFoundScreen(),
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (BuildContext context, GoRouterState state) => Routes.today),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
            AdaptiveScaffold(navigationShell: shell),
        branches: <StatefulShellBranch>[
          // 0 · আজ
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.today,
                pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const TodayScreen()),
              ),
            ],
          ),
          // 1 · ব্যাচ
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.batches,
                pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const BatchesScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const BatchFormScreen()),
                  ),
                  GoRoute(
                    path: ':batchId',
                    pageBuilder: (BuildContext context, GoRouterState state) => _detailPage(
                      state,
                      AdaptiveDetail(
                        id: _param(state, 'batchId'),
                        master: (String id) => BatchesScreen(selectedId: id),
                        detail: (String id) => BatchDetailScreen(batchId: id),
                      ),
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, BatchFormScreen(batchId: _param(state, 'batchId'))),
                      ),
                      GoRoute(
                        path: 'slots',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, SlotEditorScreen(batchId: _param(state, 'batchId'))),
                      ),
                      GoRoute(
                        path: 'rollcall/:date',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) {
                          final LocalDate? date = LocalDate.tryParse(state.pathParameters['date']);
                          if (date == null) return _page(state, const NotFoundScreen());
                          return _page(state, BatchRollCallLauncher(batchId: _param(state, 'batchId'), date: date));
                        },
                      ),
                      GoRoute(
                        path: 'bulk-add',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, BulkAddScreen(batchId: _param(state, 'batchId'))),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 2 · শিক্ষার্থী
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.students,
                pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const StudentsScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      final Object? extra = state.extra;
                      return _page(state, StudentFormScreen(initialBatchId: extra is String ? extra : null));
                    },
                  ),
                  GoRoute(
                    path: ':studentId',
                    pageBuilder: (BuildContext context, GoRouterState state) => _detailPage(
                      state,
                      AdaptiveDetail(
                        id: _param(state, 'studentId'),
                        master: (String id) => StudentsScreen(selectedId: id),
                        detail: (String id) => StudentProfileScreen(studentId: id),
                      ),
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, StudentFormScreen(studentId: _param(state, 'studentId'))),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 3 · বেতন
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.fees,
                pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const FeesScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'collection',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const CollectionScreen()),
                  ),
                  GoRoute(
                    path: 's/:studentId',
                    pageBuilder: (BuildContext context, GoRouterState state) => _detailPage(
                      state,
                      AdaptiveDetail(
                        id: _param(state, 'studentId'),
                        master: (String id) => FeesScreen(selectedStudentId: id),
                        detail: (String id) => StudentProfileScreen(studentId: id),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 4 · আরও
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.more,
                pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const MoreScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'backup',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const BackupScreen()),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'review',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const BackupReviewScreen()),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'archived',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const ArchivedBatchesScreen()),
                  ),
                  GoRoute(
                    path: 'left',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const LeftStudentsScreen()),
                  ),
                  GoRoute(
                    path: 'templates/:kind',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, TemplateEditorScreen(kind: _param(state, 'kind'))),
                  ),
                  GoRoute(
                    path: 'payment-methods',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const PaymentMethodsScreen()),
                  ),
                  GoRoute(
                    path: 'holidays',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const HolidayScreen()),
                  ),
                  GoRoute(
                    path: 'diagnostics',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const DiagnosticsScreen()),
                  ),
                  GoRoute(
                    path: 'help',
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const HelpScreen()),
                  ),
                  // Lead amendment (ds/bhor-library): hidden design-system gallery.
                  GoRoute(
                    path: 'design-system',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const DsGalleryScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes: top-level, so they live on the root navigator.
      GoRoute(
        path: '/rollcall/:occ',
        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, RollCallScreen(
          occ: _param(state, 'occ'),
          returnTo: state.extra is String ? state.extra! as String : null,
        )),
      ),
      GoRoute(
        path: Routes.search,
        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const SearchScreen()),
      ),
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.reminderPriming,
        pageBuilder: (BuildContext context, GoRouterState state) => _page(state, const ReminderPrimingScreen()),
      ),
    ],
  );
}
