// Entry point: everything happens in bootstrap() (DB open with a visible error
// path, preferences, first route, then the app).

import 'package:attendance_alamin/app/bootstrap.dart';

Future<void> main() => bootstrap();
