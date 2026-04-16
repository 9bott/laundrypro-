-- Point multi-tenant: stores, memberships, store_id on tenant tables, RLS.
-- Depends on prior migrations 001–007.
-- Edge Functions using service_role continue to bypass RLS.

-- ——————————————————————————————————————————————————————————————
-- 0) Helpers: short codes (6 chars, no ambiguous glyphs)
-- ——————————————————————————————————————————————————————————————
CREATE OR REPLACE FUNCTION public._generate_store_short_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  chars CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate TEXT;
  attempt INT := 0;
BEGIN
  LOOP
    candidate := '';
    FOR i IN 1..6 LOOP
      candidate := candidate || substr(chars, (floor(random() * length(chars)) + 1)::INT, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.stores s WHERE s.short_code = candidate);
    attempt := attempt + 1;
    IF attempt > 80 THEN
      RAISE EXCEPTION 'Could not generate unique store short_code';
    END IF;
  END LOOP;
  RETURN candidate;
END;
$$;

-- ——————————————————————————————————————————————————————————————
-- 1) Core SaaS tables
-- ——————————————————————————————————————————————————————————————
CREATE TABLE IF NOT EXISTS public.stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  short_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  business_type TEXT NOT NULL DEFAULT 'other',
  logo_url TEXT,
  brand_color TEXT NOT NULL DEFAULT '#185FA5',
  cashback_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.20,
  owner_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT stores_business_type_chk CHECK (
    business_type IN ('laundry', 'carwash', 'cafe', 'salon', 'other')
  ),
  CONSTRAINT stores_cashback_rate_chk CHECK (cashback_rate >= 0 AND cashback_rate <= 1)
);

CREATE INDEX IF NOT EXISTS stores_owner_id_idx ON public.stores (owner_id);
CREATE INDEX IF NOT EXISTS stores_status_idx ON public.stores (status);

CREATE TABLE IF NOT EXISTS public.store_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'manager', 'staff')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (store_id, user_id)
);

CREATE INDEX IF NOT EXISTS store_memberships_user_id_idx ON public.store_memberships (user_id);
CREATE INDEX IF NOT EXISTS store_memberships_store_id_idx ON public.store_memberships (store_id);

CREATE TABLE IF NOT EXISTS public.customer_store_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (store_id, user_id)
);

CREATE INDEX IF NOT EXISTS customer_store_memberships_user_idx
  ON public.customer_store_memberships (user_id);
CREATE INDEX IF NOT EXISTS customer_store_memberships_store_idx
  ON public.customer_store_memberships (store_id);

ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_store_memberships ENABLE ROW LEVEL SECURITY;

-- ——————————————————————————————————————————————————————————————
-- 2) Add store_id to all public business tables (nullable until backfill)
-- ——————————————————————————————————————————————————————————————
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);

ALTER TABLE public.staff
  ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);

ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);

-- Optional tables (some hosted DBs predate these migrations)
DO $opt$
BEGIN
  IF to_regclass('public.promotions') IS NOT NULL THEN
    ALTER TABLE public.promotions
      ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);
    CREATE INDEX IF NOT EXISTS idx_promotions_store_id ON public.promotions (store_id);
  END IF;
  IF to_regclass('public.notifications_log') IS NOT NULL THEN
    ALTER TABLE public.notifications_log
      ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);
    CREATE INDEX IF NOT EXISTS idx_notifications_log_store_id ON public.notifications_log (store_id);
  END IF;
  IF to_regclass('public.fraud_flags') IS NOT NULL THEN
    ALTER TABLE public.fraud_flags
      ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);
    CREATE INDEX IF NOT EXISTS idx_fraud_flags_store_id ON public.fraud_flags (store_id);
  END IF;
  IF to_regclass('public.audit_log') IS NOT NULL THEN
    ALTER TABLE public.audit_log
      ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);
    CREATE INDEX IF NOT EXISTS idx_audit_log_store_id ON public.audit_log (store_id);
  END IF;
  IF to_regclass('public.branches') IS NOT NULL THEN
    ALTER TABLE public.branches
      ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores (id);
    CREATE INDEX IF NOT EXISTS idx_branches_store_id ON public.branches (store_id);
  END IF;
END
$opt$;

CREATE INDEX IF NOT EXISTS idx_customers_store_id ON public.customers (store_id);
CREATE INDEX IF NOT EXISTS idx_staff_store_id ON public.staff (store_id);
CREATE INDEX IF NOT EXISTS idx_transactions_store_id ON public.transactions (store_id);
CREATE INDEX IF NOT EXISTS idx_subscription_plans_store_id ON public.subscription_plans (store_id);

-- New store: attach owner membership (must exist before legacy INSERT below).
CREATE OR REPLACE FUNCTION public._stores_after_insert_owner_membership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.store_memberships (store_id, user_id, role, status)
  VALUES (NEW.id, NEW.owner_id, 'owner', 'active')
  ON CONFLICT (store_id, user_id) DO UPDATE
  SET role = 'owner', status = 'active';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stores_owner_membership ON public.stores;
CREATE TRIGGER trg_stores_owner_membership
  AFTER INSERT ON public.stores
  FOR EACH ROW
  EXECUTE PROCEDURE public._stores_after_insert_owner_membership();

-- ——————————————————————————————————————————————————————————————
-- 3) Legacy store + backfill store_id
-- ——————————————————————————————————————————————————————————————
DO $$
DECLARE
  v_owner UUID;
  v_store UUID;
  v_slug TEXT;
  v_code TEXT;
BEGIN
  SELECT s.id INTO v_store FROM public.stores s ORDER BY s.created_at ASC LIMIT 1;

  IF v_store IS NULL THEN
    SELECT s.auth_user_id INTO v_owner
    FROM public.staff s
    WHERE s.role = 'owner' AND s.auth_user_id IS NOT NULL
    ORDER BY s.created_at ASC NULLS LAST
    LIMIT 1;

    IF v_owner IS NULL THEN
      SELECT s.auth_user_id INTO v_owner
      FROM public.staff s
      WHERE s.auth_user_id IS NOT NULL
      ORDER BY s.created_at ASC NULLS LAST
      LIMIT 1;
    END IF;

    IF v_owner IS NULL THEN
      SELECT u.id INTO v_owner FROM auth.users u ORDER BY u.created_at ASC LIMIT 1;
    END IF;

    IF v_owner IS NULL THEN
      RAISE EXCEPTION 'Cannot create legacy store: no auth.users and no staff with auth_user_id';
    END IF;

    v_code := public._generate_store_short_code();
    v_slug := 'legacy-' || substr(md5(random()::text || clock_timestamp()::text), 1, 10);

    INSERT INTO public.stores (slug, short_code, name, business_type, brand_color, cashback_rate, owner_id, status)
    VALUES (v_slug, v_code, 'متجر افتراضي', 'other', '#185FA5', 0.20, v_owner, 'active')
    RETURNING id INTO v_store;
  END IF;

  UPDATE public.customers SET store_id = v_store WHERE store_id IS NULL;
  UPDATE public.staff SET store_id = v_store WHERE store_id IS NULL;
  UPDATE public.subscription_plans SET store_id = v_store WHERE store_id IS NULL;

  IF to_regclass('public.promotions') IS NOT NULL THEN
    UPDATE public.promotions SET store_id = v_store WHERE store_id IS NULL;
  END IF;
  IF to_regclass('public.branches') IS NOT NULL THEN
    UPDATE public.branches SET store_id = v_store WHERE store_id IS NULL;
  END IF;

  UPDATE public.transactions t
  SET store_id = c.store_id
  FROM public.customers c
  WHERE t.customer_id = c.id AND t.store_id IS NULL;

  IF to_regclass('public.notifications_log') IS NOT NULL THEN
    UPDATE public.notifications_log n
    SET store_id = c.store_id
    FROM public.customers c
    WHERE n.customer_id = c.id AND n.store_id IS NULL;

    UPDATE public.notifications_log SET store_id = v_store WHERE store_id IS NULL;
  END IF;

  IF to_regclass('public.fraud_flags') IS NOT NULL THEN
    -- Some DBs omit transaction_id on fraud_flags; customer_id alone is enough for backfill.
    UPDATE public.fraud_flags f
    SET store_id = COALESCE(
      (SELECT c.store_id FROM public.customers c WHERE c.id = f.customer_id LIMIT 1),
      v_store
    )
    WHERE f.store_id IS NULL;
  END IF;

  IF to_regclass('public.audit_log') IS NOT NULL THEN
    UPDATE public.audit_log SET store_id = v_store WHERE store_id IS NULL;
  END IF;
END $$;

-- ——————————————————————————————————————————————————————————————
-- 4) Uniqueness: phone / auth_user_id / referral per store
-- ——————————————————————————————————————————————————————————————
ALTER TABLE public.customers DROP CONSTRAINT IF EXISTS customers_phone_key;
ALTER TABLE public.customers DROP CONSTRAINT IF EXISTS customers_auth_user_id_key;
ALTER TABLE public.customers DROP CONSTRAINT IF EXISTS customers_referral_code_key;

ALTER TABLE public.staff DROP CONSTRAINT IF EXISTS staff_phone_key;
ALTER TABLE public.staff DROP CONSTRAINT IF EXISTS staff_auth_user_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS customers_store_phone_uniq
  ON public.customers (store_id, phone);

CREATE UNIQUE INDEX IF NOT EXISTS customers_store_auth_user_uniq
  ON public.customers (store_id, auth_user_id)
  WHERE auth_user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS customers_store_referral_code_uniq
  ON public.customers (store_id, referral_code);

CREATE UNIQUE INDEX IF NOT EXISTS staff_store_phone_uniq
  ON public.staff (store_id, phone);

CREATE UNIQUE INDEX IF NOT EXISTS staff_store_auth_user_uniq
  ON public.staff (store_id, auth_user_id)
  WHERE auth_user_id IS NOT NULL;

-- Referral code trigger: uniqueness scoped by store_id
CREATE OR REPLACE FUNCTION public.customers_set_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  chars CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate TEXT;
  attempt INT := 0;
BEGIN
  IF NEW.referral_code IS NOT NULL AND NEW.referral_code <> '' THEN
    RETURN NEW;
  END IF;
  IF NEW.store_id IS NULL THEN
    RAISE EXCEPTION 'store_id is required before referral_code generation';
  END IF;
  LOOP
    candidate := '';
    FOR i IN 1..6 LOOP
      candidate := candidate || substr(chars, (floor(random() * length(chars)) + 1)::INT, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.customers c
      WHERE c.referral_code = candidate AND c.store_id = NEW.store_id
    );
    attempt := attempt + 1;
    IF attempt > 50 THEN
      RAISE EXCEPTION 'Could not generate unique referral_code';
    END IF;
  END LOOP;
  NEW.referral_code := candidate;
  RETURN NEW;
END;
$$;

-- ——————————————————————————————————————————————————————————————
-- 5) NOT NULL on store_id (all rows backfilled)
-- ——————————————————————————————————————————————————————————————
ALTER TABLE public.customers ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE public.staff ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE public.transactions ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE public.subscription_plans ALTER COLUMN store_id SET NOT NULL;

DO $nn$
BEGIN
  IF to_regclass('public.promotions') IS NOT NULL THEN
    ALTER TABLE public.promotions ALTER COLUMN store_id SET NOT NULL;
  END IF;
  IF to_regclass('public.notifications_log') IS NOT NULL THEN
    ALTER TABLE public.notifications_log ALTER COLUMN store_id SET NOT NULL;
  END IF;
  IF to_regclass('public.fraud_flags') IS NOT NULL THEN
    ALTER TABLE public.fraud_flags ALTER COLUMN store_id SET NOT NULL;
  END IF;
  IF to_regclass('public.audit_log') IS NOT NULL THEN
    ALTER TABLE public.audit_log ALTER COLUMN store_id SET NOT NULL;
  END IF;
  IF to_regclass('public.branches') IS NOT NULL THEN
    ALTER TABLE public.branches ALTER COLUMN store_id SET NOT NULL;
  END IF;
END
$nn$;

-- ——————————————————————————————————————————————————————————————
-- 6) Backfill store_memberships + customer_store_memberships
-- ——————————————————————————————————————————————————————————————
INSERT INTO public.store_memberships (store_id, user_id, role, status)
SELECT DISTINCT ON (s.store_id, s.auth_user_id)
  s.store_id,
  s.auth_user_id,
  CASE
    WHEN s.role = 'owner' THEN 'owner'
    WHEN s.role = 'manager' THEN 'manager'
    ELSE 'staff'
  END,
  'active'
FROM public.staff s
WHERE s.auth_user_id IS NOT NULL
ORDER BY s.store_id, s.auth_user_id, s.created_at ASC NULLS LAST
ON CONFLICT (store_id, user_id) DO NOTHING;

-- Ensure store owner has owner membership (covers owner-only auth without staff row)
INSERT INTO public.store_memberships (store_id, user_id, role, status)
SELECT st.id, st.owner_id, 'owner', 'active'
FROM public.stores st
ON CONFLICT (store_id, user_id) DO UPDATE
SET role = 'owner', status = 'active';

INSERT INTO public.customer_store_memberships (store_id, user_id)
SELECT c.store_id, c.auth_user_id
FROM public.customers c
WHERE c.auth_user_id IS NOT NULL
ON CONFLICT (store_id, user_id) DO NOTHING;

-- ——————————————————————————————————————————————————————————————
-- 7) Join store by short code (for “أدخل رمز المتجر” client flow)
-- ——————————————————————————————————————————————————————————————
CREATE OR REPLACE FUNCTION public.join_store_as_customer(p_short_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store UUID;
  v_norm TEXT;
BEGIN
  v_norm := upper(trim(both from p_short_code));
  IF v_norm IS NULL OR length(v_norm) < 4 THEN
    RAISE EXCEPTION 'رمز المتجر غير صالح';
  END IF;

  SELECT id INTO v_store
  FROM public.stores
  WHERE upper(trim(both from short_code)) = v_norm
    AND status = 'active'
  LIMIT 1;

  IF v_store IS NULL THEN
    RAISE EXCEPTION 'لم يتم العثور على المتجر';
  END IF;

  INSERT INTO public.customer_store_memberships (store_id, user_id)
  VALUES (v_store, auth.uid())
  ON CONFLICT (store_id, user_id) DO NOTHING;

  RETURN v_store;
END;
$$;

REVOKE ALL ON FUNCTION public.join_store_as_customer(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_store_as_customer(TEXT) TO authenticated;

-- ——————————————————————————————————————————————————————————————
-- 8) Drop old RLS policies
-- ——————————————————————————————————————————————————————————————
DROP POLICY IF EXISTS customers_select_own ON public.customers;
DROP POLICY IF EXISTS customers_select_staff ON public.customers;
DROP POLICY IF EXISTS customers_update_own_profile ON public.customers;

DROP POLICY IF EXISTS staff_select_active_members ON public.staff;

DROP POLICY IF EXISTS transactions_select_own_customer ON public.transactions;
DROP POLICY IF EXISTS transactions_select_staff ON public.transactions;

DROP POLICY IF EXISTS subscription_plans_select_authenticated ON public.subscription_plans;
DROP POLICY IF EXISTS subscription_plans_select_anon ON public.subscription_plans;

DO $dropopt$
BEGIN
  IF to_regclass('public.promotions') IS NOT NULL THEN
    DROP POLICY IF EXISTS promotions_select_authenticated ON public.promotions;
    DROP POLICY IF EXISTS promotions_select_anon ON public.promotions;
  END IF;
  IF to_regclass('public.notifications_log') IS NOT NULL THEN
    DROP POLICY IF EXISTS notifications_select_own_customer ON public.notifications_log;
    DROP POLICY IF EXISTS notifications_select_staff ON public.notifications_log;
  END IF;
  IF to_regclass('public.fraud_flags') IS NOT NULL THEN
    DROP POLICY IF EXISTS fraud_flags_select_owner ON public.fraud_flags;
  END IF;
  IF to_regclass('public.audit_log') IS NOT NULL THEN
    DROP POLICY IF EXISTS audit_log_select_owner ON public.audit_log;
  END IF;
  IF to_regclass('public.branches') IS NOT NULL THEN
    DROP POLICY IF EXISTS branches_read ON public.branches;
  END IF;
END
$dropopt$;

-- ——————————————————————————————————————————————————————————————
-- 9) New RLS: stores & memberships
-- ——————————————————————————————————————————————————————————————
CREATE POLICY stores_select_member
  ON public.stores FOR SELECT TO authenticated
  USING (
    owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.store_id = stores.id
        AND sm.user_id = auth.uid()
        AND sm.status IN ('active', 'invited')
    )
    OR EXISTS (
      SELECT 1 FROM public.customer_store_memberships csm
      WHERE csm.store_id = stores.id
        AND csm.user_id = auth.uid()
    )
  );

CREATE POLICY stores_update_owner_manager
  ON public.stores FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.store_id = stores.id
        AND sm.user_id = auth.uid()
        AND sm.status = 'active'
        AND sm.role IN ('owner', 'manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.store_id = stores.id
        AND sm.user_id = auth.uid()
        AND sm.status = 'active'
        AND sm.role IN ('owner', 'manager')
    )
  );

CREATE POLICY stores_insert_authenticated_owner
  ON public.stores FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY store_memberships_select
  ON public.store_memberships FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.store_id = store_memberships.store_id
        AND sm.user_id = auth.uid()
        AND sm.status = 'active'
        AND sm.role IN ('owner', 'manager')
    )
  );

-- Inserts/updates for staff invites: service_role / future RPC; not from anon JWT clients.
CREATE POLICY store_memberships_insert_owner_manager
  ON public.store_memberships FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.store_id = store_memberships.store_id
        AND sm.user_id = auth.uid()
        AND sm.status = 'active'
        AND sm.role IN ('owner', 'manager')
    )
  );

CREATE POLICY store_memberships_update_owner_manager
  ON public.store_memberships FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.store_id = store_memberships.store_id
        AND sm.user_id = auth.uid()
        AND sm.status = 'active'
        AND sm.role IN ('owner', 'manager')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.store_id = store_memberships.store_id
        AND sm.user_id = auth.uid()
        AND sm.status = 'active'
        AND sm.role IN ('owner', 'manager')
    )
  );

CREATE POLICY customer_store_memberships_select_own
  ON public.customer_store_memberships FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Direct client inserts disabled; use join_store_as_customer() or service_role.
CREATE POLICY customer_store_memberships_insert_none
  ON public.customer_store_memberships FOR INSERT TO authenticated
  WITH CHECK (false);

-- ——————————————————————————————————————————————————————————————
-- 10) Tenant tables RLS (store-scoped)
-- ——————————————————————————————————————————————————————————————
CREATE POLICY customers_select_own_member
  ON public.customers FOR SELECT TO authenticated
  USING (
    auth_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.customer_store_memberships m
      WHERE m.user_id = auth.uid()
        AND m.store_id = customers.store_id
    )
  );

CREATE POLICY customers_select_staff_same_store
  ON public.customers FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.store_id = customers.store_id
        AND sm.status = 'active'
        AND sm.role IN ('owner', 'manager', 'staff')
    )
  );

CREATE POLICY customers_update_own_profile
  ON public.customers FOR UPDATE TO authenticated
  USING (
    auth_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.customer_store_memberships m
      WHERE m.user_id = auth.uid()
        AND m.store_id = customers.store_id
    )
  )
  WITH CHECK (
    auth_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.customer_store_memberships m
      WHERE m.user_id = auth.uid()
        AND m.store_id = customers.store_id
    )
  );

-- Customer self-registration after joining a store (join_store_as_customer).
DROP POLICY IF EXISTS customers_insert_joined_store ON public.customers;
CREATE POLICY customers_insert_joined_store
  ON public.customers FOR INSERT TO authenticated
  WITH CHECK (
    auth_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.customer_store_memberships csm
      WHERE csm.user_id = auth.uid()
        AND csm.store_id = customers.store_id
    )
  );

CREATE POLICY staff_select_same_store
  ON public.staff FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.store_id = staff.store_id
        AND sm.status = 'active'
    )
  );

CREATE POLICY transactions_select_customer
  ON public.transactions FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.customers c
      WHERE c.id = transactions.customer_id
        AND c.auth_user_id = auth.uid()
        AND EXISTS (
          SELECT 1 FROM public.customer_store_memberships m
          WHERE m.user_id = auth.uid()
            AND m.store_id = c.store_id
            AND m.store_id = transactions.store_id
        )
    )
  );

CREATE POLICY transactions_select_staff
  ON public.transactions FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.store_id = transactions.store_id
        AND sm.status = 'active'
    )
  );

CREATE POLICY subscription_plans_select_store_member
  ON public.subscription_plans FOR SELECT TO authenticated
  USING (
    is_active
    AND (
      EXISTS (
        SELECT 1 FROM public.store_memberships sm
        WHERE sm.store_id = subscription_plans.store_id
          AND sm.user_id = auth.uid()
          AND sm.status = 'active'
      )
      OR EXISTS (
        SELECT 1 FROM public.customer_store_memberships csm
        WHERE csm.store_id = subscription_plans.store_id
          AND csm.user_id = auth.uid()
      )
    )
  );

DO $polopt$
BEGIN
  IF to_regclass('public.promotions') IS NOT NULL THEN
    DROP POLICY IF EXISTS promotions_select_store_member ON public.promotions;
    CREATE POLICY promotions_select_store_member
      ON public.promotions FOR SELECT TO authenticated
      USING (
        is_active
        AND (
          EXISTS (
            SELECT 1 FROM public.store_memberships sm
            WHERE sm.store_id = promotions.store_id
              AND sm.user_id = auth.uid()
              AND sm.status = 'active'
          )
          OR EXISTS (
            SELECT 1 FROM public.customer_store_memberships csm
            WHERE csm.store_id = promotions.store_id
              AND csm.user_id = auth.uid()
          )
        )
      );
  END IF;

  IF to_regclass('public.notifications_log') IS NOT NULL THEN
    DROP POLICY IF EXISTS notifications_select_customer ON public.notifications_log;
    DROP POLICY IF EXISTS notifications_select_staff ON public.notifications_log;
    CREATE POLICY notifications_select_customer
      ON public.notifications_log FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.customers c
          WHERE c.id = notifications_log.customer_id
            AND c.auth_user_id = auth.uid()
            AND c.store_id = notifications_log.store_id
            AND EXISTS (
              SELECT 1 FROM public.customer_store_memberships m
              WHERE m.user_id = auth.uid()
                AND m.store_id = c.store_id
            )
        )
      );

    CREATE POLICY notifications_select_staff
      ON public.notifications_log FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.store_memberships sm
          WHERE sm.user_id = auth.uid()
            AND sm.store_id = notifications_log.store_id
            AND sm.status = 'active'
        )
      );
  END IF;

  IF to_regclass('public.fraud_flags') IS NOT NULL THEN
    DROP POLICY IF EXISTS fraud_flags_select_owner_manager ON public.fraud_flags;
    CREATE POLICY fraud_flags_select_owner_manager
      ON public.fraud_flags FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.store_memberships sm
          WHERE sm.user_id = auth.uid()
            AND sm.store_id = fraud_flags.store_id
            AND sm.status = 'active'
            AND sm.role IN ('owner', 'manager')
        )
      );
  END IF;

  IF to_regclass('public.audit_log') IS NOT NULL THEN
    DROP POLICY IF EXISTS audit_log_select_owner_manager ON public.audit_log;
    CREATE POLICY audit_log_select_owner_manager
      ON public.audit_log FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.store_memberships sm
          WHERE sm.user_id = auth.uid()
            AND sm.store_id = audit_log.store_id
            AND sm.status = 'active'
            AND sm.role IN ('owner', 'manager')
        )
      );
  END IF;

  IF to_regclass('public.branches') IS NOT NULL THEN
    DROP POLICY IF EXISTS branches_select_store_member ON public.branches;
    CREATE POLICY branches_select_store_member
      ON public.branches FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.store_memberships sm
          WHERE sm.store_id = branches.store_id
            AND sm.user_id = auth.uid()
            AND sm.status = 'active'
        )
        OR EXISTS (
          SELECT 1 FROM public.customer_store_memberships csm
          WHERE csm.store_id = branches.store_id
            AND csm.user_id = auth.uid()
        )
      );
  END IF;
END
$polopt$;

COMMENT ON TABLE public.stores IS 'Point SaaS store (tenant).';
COMMENT ON TABLE public.store_memberships IS 'Staff/owner/manager access to a store (not customers).';
COMMENT ON TABLE public.customer_store_memberships IS 'Which auth users may use the app as customer for which store.';
COMMENT ON FUNCTION public.join_store_as_customer IS 'Idempotent: links auth.uid() to store by 6-char short_code; raises Arabic errors on failure.';
