-- Keep auth-dependent RLS expressions init-plan eligible and index leave approver FK.
ALTER POLICY communication_messages_update ON public.communication_messages
USING (
  sender_id = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.communication_threads t ON t.id = communication_messages.thread_id
    WHERE p.id = (SELECT auth.uid())
      AND p.school_id = t.school_id
      AND t.school_id = (SELECT public.get_my_school_id())
      AND p.role = 'principal'
      AND COALESCE(p.is_active, true)
  )
)
WITH CHECK (
  sender_id = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.communication_threads t ON t.id = communication_messages.thread_id
    WHERE p.id = (SELECT auth.uid())
      AND p.school_id = t.school_id
      AND t.school_id = (SELECT public.get_my_school_id())
      AND p.role = 'principal'
      AND COALESCE(p.is_active, true)
  )
);

ALTER POLICY leave_delete_own_pending ON public.leave_requests
USING (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
  AND user_id = (SELECT auth.uid())
  AND status = 'pending'
);

ALTER POLICY leave_delete_principal_staff ON public.leave_requests
USING (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.role IN ('principal', 'staff')
  )
);

ALTER POLICY leave_insert_own ON public.leave_requests
WITH CHECK (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
  AND user_id = (SELECT auth.uid())
  AND status = 'pending'
);

ALTER POLICY leave_manage_principal_staff ON public.leave_requests
USING (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.role IN ('principal', 'staff')
  )
)
WITH CHECK (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
  AND status IN ('pending', 'approved', 'rejected', 'cancelled')
);

ALTER POLICY leave_select_school ON public.leave_requests
USING (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
);

ALTER POLICY leave_update_own_pending ON public.leave_requests
USING (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
  AND user_id = (SELECT auth.uid())
  AND status = 'pending'
)
WITH CHECK (
  school_id = (SELECT p.school_id FROM public.profiles p WHERE p.id = (SELECT auth.uid()))
  AND user_id = (SELECT auth.uid())
  AND status = 'pending'
);

CREATE INDEX IF NOT EXISTS idx_leave_requests_approved_by
ON public.leave_requests (approved_by);
