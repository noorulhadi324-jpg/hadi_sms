-- Preserve existing tenant and role conditions while avoiding SELECT being
-- implicitly included in write-only policies. This removes redundant permissive
-- SELECT paths without changing intended read access.

-- accounting_entries: the ALL policy previously duplicated the school-read
-- policy for SELECT, and granted writes only to active principals/staff.
DROP POLICY IF EXISTS accounting_entries_school_write ON public.accounting_entries;
CREATE POLICY accounting_entries_school_insert
  ON public.accounting_entries FOR INSERT TO authenticated
  WITH CHECK (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );
CREATE POLICY accounting_entries_school_update
  ON public.accounting_entries FOR UPDATE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  )
  WITH CHECK (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );
CREATE POLICY accounting_entries_school_delete
  ON public.accounting_entries FOR DELETE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );

-- Challans: keep school-read policies separate from role-restricted writes.
DROP POLICY IF EXISTS school_challans_school_write ON public.school_challans;
CREATE POLICY school_challans_school_insert
  ON public.school_challans FOR INSERT TO authenticated
  WITH CHECK (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );
CREATE POLICY school_challans_school_update
  ON public.school_challans FOR UPDATE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  )
  WITH CHECK (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );
CREATE POLICY school_challans_school_delete
  ON public.school_challans FOR DELETE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );

DROP POLICY IF EXISTS school_challan_payments_school_write ON public.school_challan_payments;
CREATE POLICY school_challan_payments_school_insert
  ON public.school_challan_payments FOR INSERT TO authenticated
  WITH CHECK (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );
CREATE POLICY school_challan_payments_school_update
  ON public.school_challan_payments FOR UPDATE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  )
  WITH CHECK (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );
CREATE POLICY school_challan_payments_school_delete
  ON public.school_challan_payments FOR DELETE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = ANY (ARRAY['principal'::text, 'staff'::text])
        AND COALESCE(p.is_active, true)
    )
  );

-- These two SELECT policies have identical role, command and predicate.
DROP POLICY IF EXISTS "Users can view their school notifications" ON public.notifications;
