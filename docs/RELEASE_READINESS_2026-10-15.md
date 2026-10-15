# HADI SMS Release Readiness — 2026-10-15

## Verified in the connected Supabase project

- Removed the user-approved duplicate monthly fee row `student_fees.id = 11`; retained row 12 with its 14 October 2026 due date. Before deletion, checked the linked `fee_payments.student_fee_id` records, foreign-key references, and triggers.
- Applied and verified `20261015095348_prevent_duplicate_monthly_student_fees`: partial unique index on `(school_id, student_id, fee_category_id, fee_month)` where `fee_month IS NOT NULL`.
- Applied and verified `20261015095458_consolidate_leave_request_policies_and_harden_updates`: consolidated overlapping leave-request UPDATE/DELETE policies and tightened the UPDATE `WITH CHECK` role/status conditions.
- Rechecked Supabase Performance Advisor: the two multiple-permissive-policy warnings for leave requests are no longer reported. Remaining unused-index notices are informational; do not drop indexes without usage and query-plan analysis.
- Rechecked Supabase Security Advisor: leaked-password protection is still disabled and requires a manual Auth dashboard change.

## GitHub CI status

PR #8: https://github.com/noorulhadi324-jpg/hadi_sms/pull/8

At the latest check, GitHub Actions run `38716490594` had passed Setup Flutter, Flutter version, package installation, Analyze, and Test; Debug APK build was still running. Do not describe the full CI as passed until the build and artifact upload finish successfully.

## Blockers before calling this production-ready

1. Enable leaked-password protection in Supabase Dashboard → Authentication → Security and Protection. Then re-run the Security Advisor.
2. Reconcile the 37 migration-ledger entries whose original SQL files are missing from the existing security-hardening branch. The ledger records version/name, not the SQL body. Recover original files from trusted version control, backups, CI artifacts, or developer copies; compare schema, functions, grants, triggers, RLS, indexes, and constraints. Do not fabricate migration SQL from names or replay already-applied migrations against production.
3. Run disposable-database bootstrap testing after migration recovery.
4. Verify real role/tenant isolation and critical workflows (admissions, attendance, fee generation/payments/receipts, exams, leave approvals, communication, accounting, subscription) using separate test accounts for each role.
5. Verify Android release signing and release build, app icon/assets, privacy policy and Play Console Data safety declarations, account deletion requirements, and a physical-device smoke test. A passing Debug APK build is not a Play Store release verification.

## Scope note

This checklist records verified operations and explicit remaining work. It does not claim end-to-end production certification.