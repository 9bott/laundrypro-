-- RLS policies — Edge Functions / service_role bypass RLS and perform balance writes.

-- —— Prevent privileged customer field updates from JWT-authenticated clients ——
CREATE OR REPLACE FUNCTION public.customers_block_system_fields_from_clients()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  -- Service role (Edge Functions, dashboard) may change any column.
  IF (SELECT auth.role()) = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF NEW.cashback_balance IS DISTINCT FROM OLD.cashback_balance
    OR NEW.subscription_balance IS DISTINCT FROM OLD.subscription_balance
    OR NEW.total_spent IS DISTINCT FROM OLD.total_spent
    OR NEW.visit_count IS DISTINCT FROM OLD.visit_count
    OR NEW.streak_count IS DISTINCT FROM OLD.streak_count
    OR NEW.last_visit_date IS DISTINCT FROM OLD.last_visit_date
    OR NEW.tier IS DISTINCT FROM OLD.tier
    OR NEW.is_blocked IS DISTINCT FROM OLD.is_blocked
  THEN
    RAISE EXCEPTION 'Forbidden: balance and loyalty metrics may only be updated by the system';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_customers_block_system_fields
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE PROCEDURE public.customers_block_system_fields_from_clients();

-- —— Enable RLS ——
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- —— Helper: active staff row for current user ——
-- (inline EXISTS in policies below)

-- —— customers ——
CREATE POLICY customers_select_own
  ON public.customers
  FOR SELECT
  TO authenticated
  USING (auth.uid() = auth_user_id);

CREATE POLICY customers_select_staff
  ON public.customers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.staff s
      WHERE s.auth_user_id = auth.uid()
        AND s.is_active
    )
  );

CREATE POLICY customers_update_own_profile
  ON public.customers
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() = auth_user_id);

-- —— staff (read for counter devices; mutations via service_role) ——
CREATE POLICY staff_select_active_members
  ON public.staff
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.staff s
      WHERE s.auth_user_id = auth.uid()
        AND s.is_active
    )
  );

-- —— transactions ——
CREATE POLICY transactions_select_own_customer
  ON public.transactions
  FOR SELECT
  TO authenticated
  USING (
    customer_id IN (
      SELECT c.id
      FROM public.customers c
      WHERE c.auth_user_id = auth.uid()
    )
  );

CREATE POLICY transactions_select_staff
  ON public.transactions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.staff s
      WHERE s.auth_user_id = auth.uid()
        AND s.is_active
    )
  );

-- No INSERT / UPDATE / DELETE for authenticated — use Edge Functions + service_role.

-- —— subscription_plans —— public read of active tiers ——
CREATE POLICY subscription_plans_select_authenticated
  ON public.subscription_plans
  FOR SELECT
  TO authenticated
  USING (is_active);

CREATE POLICY subscription_plans_select_anon
  ON public.subscription_plans
  FOR SELECT
  TO anon
  USING (is_active);

-- —— promotions ——
CREATE POLICY promotions_select_authenticated
  ON public.promotions
  FOR SELECT
  TO authenticated
  USING (is_active);

CREATE POLICY promotions_select_anon
  ON public.promotions
  FOR SELECT
  TO anon
  USING (is_active);

-- —— notifications_log ——
CREATE POLICY notifications_select_own_customer
  ON public.notifications_log
  FOR SELECT
  TO authenticated
  USING (
    customer_id IN (
      SELECT c.id
      FROM public.customers c
      WHERE c.auth_user_id = auth.uid()
    )
  );

CREATE POLICY notifications_select_staff
  ON public.notifications_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.staff s
      WHERE s.auth_user_id = auth.uid()
        AND s.is_active
    )
  );

-- —— fraud_flags —— owner read-only ——
CREATE POLICY fraud_flags_select_owner
  ON public.fraud_flags
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.staff s
      WHERE s.auth_user_id = auth.uid()
        AND s.is_active
        AND s.role = 'owner'
    )
  );

-- —— audit_log —— owner read-only; append via service_role only ——
CREATE POLICY audit_log_select_owner
  ON public.audit_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.staff s
      WHERE s.auth_user_id = auth.uid()
        AND s.is_active
        AND s.role = 'owner'
    )
  );

-- No UPDATE / DELETE policies → authenticated cannot modify rows once RLS applies.
