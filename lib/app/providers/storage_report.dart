// Re-export of the web storage report for feature screens (Diagnostics).
// Features may not import data/db directly (tool/check_domain_purity.sh rule 4);
// this thin bridge lives in app/, which may.

export 'package:attendance_alamin/data/db/connection/web_storage_report.dart'
    show WebStorageInfo, webStorageReport;
