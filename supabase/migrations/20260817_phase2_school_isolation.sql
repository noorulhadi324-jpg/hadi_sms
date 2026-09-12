-- HADI SMS Phase 2: school tenant isolation
-- IMPORTANT: Review against your current Supabase schema before applying.
-- This migration assumes schools.id, profiles.school_id and students.school_id
-- are UUID-compatible, and attendance.school_id exists as UUID.

create index if not exists idx_students_school_id
  on public.students (school_id);

create index if not exists idx_attendance_school_date
  on public.attendance (school_id, attendance_date);

-- RLS must remain the final enforcement layer. Existing policies are intentionally
-- not dropped or replaced here because their exact current definitions must be
-- verified before changing production authorization behavior.
