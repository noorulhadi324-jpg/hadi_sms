-- Prevent duplicate monthly fee rows for the same school, student, and fee category.
-- fee_month is nullable in legacy rows, so the index only covers dated monthly fees.
CREATE UNIQUE INDEX IF NOT EXISTS student_fees_school_student_category_month_uidx
  ON public.student_fees (school_id, student_id, fee_category_id, fee_month)
  WHERE fee_month IS NOT NULL;
