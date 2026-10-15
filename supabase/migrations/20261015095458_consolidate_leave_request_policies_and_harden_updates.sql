-- Consolidate overlapping permissive leave-request policies.
-- Keep school isolation and own-pending access, while requiring principal/staff
-- role checks for both existing-row access and approved state changes.
DROP POLICY IF EXISTS leave_delete_own_pending ON public.leave_requests;
DROP POLICY IF EXISTS leave_delete_principal_staff ON public.leave_requests;
CREATE POLICY leave_delete_school ON public.leave_requests
  FOR DELETE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND (
      (user_id = (SELECT auth.uid()) AND status = 'pending')
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = (SELECT auth.uid()) AND p.role IN ('principal', 'staff')
      )
    )
  );

DROP POLICY IF EXISTS leave_manage_principal_staff ON public.leave_requests;
DROP POLICY IF EXISTS leave_update_own_pending ON public.leave_requests;
CREATE POLICY leave_update_school ON public.leave_requests
  FOR UPDATE TO authenticated
  USING (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND (
      (user_id = (SELECT auth.uid()) AND status = 'pending')
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = (SELECT auth.uid()) AND p.role IN ('principal', 'staff')
      )
    )
  )
  WITH CHECK (
    school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
    AND (
      (user_id = (SELECT auth.uid()) AND status = 'pending')
      OR (
        status IN ('pending', 'approved', 'rejected', 'cancelled')
        AND EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.id = (SELECT auth.uid()) AND p.role IN ('principal', 'staff')
        )
      )
    )
  );
