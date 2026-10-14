# Database Setup Reconciliation

## Current status

The connected Supabase project has migration-history entries that are not represented by SQL files in this repository branch. This is migration drift, not proof that the live schema is broken. **Do not bootstrap a fresh project from this branch until the missing SQL has been recovered and reviewed.**

A comparison on 2026-10-14 found 37 database migration-history entries missing from `supabase/migrations/`. Their version and name are recorded below from the Supabase migration ledger. The ledger stores names/versions, not the original SQL body, so these files must not be recreated from names alone.

## Migration files to recover

- `20260912070451_fix_school_registration_auth_link.sql`
- `20260912075434_harden_school_auth_linkage.sql`
- `20260912092306_add_ensure_my_school_link.sql`
- `20260912092312_harden_parent_and_teacher_linkage.sql`
- `20260912092413_add_teacher_creator_function_marker.sql`
- `20260912092436_fix_user_profile_trigger_linkage.sql`
- `20260912122327_role_based_portals_rls.sql`
- `20260912122722_tighten_security_definer_grants.sql`
- `20260912122736_revoke_public_function_execute.sql`
- `20260912122745_pin_trigger_function_search_paths.sql`
- `20260912122806_remove_duplicate_parent_email_index.sql`
- `20260912132454_secure_school_communication.sql`
- `20260912164014_complete_communication_system.sql`
- `20260912164425_enable_communication_realtime.sql`
- `20260912164436_add_academic_sessions_for_settings.sql`
- `20260912164701_log_communication_activity.sql`
- `20260912170143_advance_fee_automation_and_payment.sql`
- `20260913111443_operations_modules.sql`
- `20260913121539_fix_operations_rls_role_scope.sql`
- `20260914052836_school_work_phase_1.sql`
- `20260930113730_harden_security_definer_function_grants.sql`
- `20260930113746_fix_public_security_definer_grants.sql`
- `20260930113855_harden_fee_receipt_uniqueness.sql`
- `20260930121823_tighten_school_write_policies.sql`
- `20260930121844_tighten_admin_module_writes.sql`
- `20260930121917_revoke_direct_communication_activity_execute.sql`
- `20260930122207_cleanup_rls_performance_policies.sql`
- `20260930122223_add_missing_foreign_key_indexes.sql`
- `20260930122254_cleanup_duplicate_fk_indexes.sql`
- `20260930122312_finish_fk_index_cleanup.sql`
- `20260930122724_optimize_rls_auth_initplans_v2.sql`
- `20261002050339_complete_leave_management.sql`
- `20261002050446_harden_leave_timestamp_function.sql`
- `20261002050747_harden_auth_metadata_tenant_assignment.sql`
- `20261002050906_harden_communication_message_update_scope.sql`
- `20261002051019_remove_unused_table_name_and_lock_rpcs.sql`
- `20261002051024_lock_subscription_plan_rpc.sql`

## Safe recovery procedure

1. Retrieve the original SQL from trusted migration backups, CI logs, local developer copies, or version control history.
2. Compare each recovered migration with the live schema, functions, grants, RLS policies, triggers, indexes, and constraints.
3. Preserve the original version prefix and filename. Do not re-run already-applied migrations against the live database simply to mark them as present.
4. Test the recovered sequence against a disposable Supabase project/database before using it for a fresh deployment.
5. Document any schema differences that cannot be traced to an original migration and create a separately reviewed reconciliation migration only after testing.

## Existing duplicate monthly fee data

A live query found two pending `student_fees` rows for the same school, student, fee category, and September 2026 fee month. Neither row had linked rows in `fee_payments` via `student_fee_id` at the time of inspection. Their due dates differ, so they have **not** been automatically deleted or merged. Confirm which due date is correct and inspect application/audit history before reconciliation; then re-check duplicates before adding a uniqueness constraint.

## Other remaining manual action

Enable leaked-password protection in Supabase Auth settings. The security advisor currently reports this as a warning. It has not been enabled by this repository change.


## Recent RLS policy cleanup (2026-10-14)

The live project migration `reduce_duplicate_permissive_policies` was applied and its SQL is tracked as `supabase/migrations/20261014080409_reduce_duplicate_permissive_policies.sql`. It replaces write-only `ALL` policies on accounting entries and school challans with separate INSERT/UPDATE/DELETE policies, preserving the existing school and active principal/staff checks. It also removes one duplicate school-notification SELECT policy whose predicate was identical to the remaining policy.

After the change, the Supabase performance advisor's multiple-permissive-policy warning count fell from six to two. The two remaining warnings are for leave-request UPDATE/DELETE, where the policies represent different owner-versus-principal/staff capabilities and should not be merged without proving equivalence. The advisor still reports unused-index informational findings; indexes are not being removed solely on that basis.
