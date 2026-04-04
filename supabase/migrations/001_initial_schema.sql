-- LaundryPro initial schema — column names match Flutter / PostgREST clients exactly.
-- Requires: pgcrypto (gen_random_uuid — available on Supabase by default)

-- —— customers ——
CREATE TABLE public.customers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  -- Links row to Supabase Auth (phone OTP user). Nullable until first login links the account.
  auth_user_id UUID UNIQUE REFERENCES auth.users (id),
  phone VARCHAR(15) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  avatar_url TEXT,
  cashback_balance DECIMAL(10, 2) DEFAULT 0.00 NOT NULL,
  subscription_balance DECIMAL(10, 2) DEFAULT 0.00 NOT NULL,
  tier VARCHAR(20) DEFAULT 'bronze' NOT NULL,
  total_spent DECIMAL(10, 2) DEFAULT 0.00,
  visit_count INTEGER DEFAULT 0,
  streak_count INTEGER DEFAULT 0,
  last_visit_date TIMESTAMPTZ,
  birthday DATE,
  referral_code VARCHAR(10) UNIQUE,
  referred_by UUID REFERENCES public.customers (id),
  device_token TEXT,
  preferred_language VARCHAR(5) DEFAULT 'ar',
  is_blocked BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON COLUMN public.customers.auth_user_id IS 'Maps this customer to auth.users.id for RLS (auth.uid()).';

-- Auto-generate 6-character referral code when missing (alphanumeric, no ambiguous chars).
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
  LOOP
    candidate := '';
    FOR i IN 1..6 LOOP
      candidate := candidate || substr(chars, (floor(random() * length(chars)) + 1)::INT, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.customers c WHERE c.referral_code = candidate
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

CREATE TRIGGER trg_customers_referral_code
  BEFORE INSERT ON public.customers
  FOR EACH ROW
  EXECUTE PROCEDURE public.customers_set_referral_code();

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE PROCEDURE public.touch_updated_at();

-- —— staff ——
CREATE TABLE public.staff (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  auth_user_id UUID UNIQUE REFERENCES auth.users (id),
  phone VARCHAR(15) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  pin_hash VARCHAR(255),
  role VARCHAR(20) DEFAULT 'staff' NOT NULL,
  branch VARCHAR(100) DEFAULT 'main' NOT NULL,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON COLUMN public.staff.role IS 'staff | manager | owner (owner used for fraud/audit RLS).';

-- —— transactions ——
CREATE TABLE public.transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  idempotency_key VARCHAR(100) UNIQUE,
  customer_id UUID NOT NULL REFERENCES public.customers (id),
  staff_id UUID REFERENCES public.staff (id),
  type VARCHAR(30) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  cashback_earned DECIMAL(10, 2) DEFAULT 0.00,
  subscription_used DECIMAL(10, 2) DEFAULT 0.00,
  cashback_used DECIMAL(10, 2) DEFAULT 0.00,
  balance_before_cashback DECIMAL(10, 2),
  balance_before_subscription DECIMAL(10, 2),
  balance_after_cashback DECIMAL(10, 2),
  balance_after_subscription DECIMAL(10, 2),
  notes TEXT,
  device_id VARCHAR(255),
  is_undone BOOLEAN DEFAULT FALSE NOT NULL,
  undone_at TIMESTAMPTZ,
  undone_by UUID REFERENCES public.staff (id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON COLUMN public.transactions.type IS 'purchase | redemption | subscription | cashback_bonus | referral_bonus | streak_bonus | birthday_bonus | manual_adjustment';

-- —— subscription_plans ——
CREATE TABLE public.subscription_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  name_ar VARCHAR(100) NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  credit DECIMAL(10, 2) NOT NULL,
  bonus_percentage DECIMAL(5, 2),
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  sort_order INTEGER DEFAULT 0 NOT NULL
);

-- —— promotions ——
CREATE TABLE public.promotions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  title_ar VARCHAR(200) NOT NULL,
  type VARCHAR(30) NOT NULL,
  cashback_override DECIMAL(5, 2),
  bonus_amount DECIMAL(10, 2),
  conditions JSONB,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON COLUMN public.promotions.type IS 'streak | birthday | dormant | referral | manual';

-- —— notifications_log ——
CREATE TABLE public.notifications_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES public.customers (id),
  type VARCHAR(50) NOT NULL,
  channel VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  sent_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  delivered BOOLEAN DEFAULT FALSE NOT NULL,
  transaction_id UUID REFERENCES public.transactions (id)
);

COMMENT ON COLUMN public.notifications_log.type IS 'transaction | low_balance | dormant | streak | birthday | subscription_expiry';

-- —— fraud_flags ——
CREATE TABLE public.fraud_flags (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  transaction_id UUID REFERENCES public.transactions (id),
  staff_id UUID REFERENCES public.staff (id),
  customer_id UUID REFERENCES public.customers (id),
  flag_type VARCHAR(50) NOT NULL,
  auto_detected BOOLEAN DEFAULT TRUE NOT NULL,
  reviewed_by UUID REFERENCES public.staff (id),
  resolved BOOLEAN DEFAULT FALSE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON COLUMN public.fraud_flags.flag_type IS 'self_transaction | velocity_exceeded | large_amount | duplicate_device';

-- —— audit_log ——
CREATE TABLE public.audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  actor_id UUID NOT NULL,
  actor_type VARCHAR(20) NOT NULL,
  action VARCHAR(100) NOT NULL,
  table_name VARCHAR(50),
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  device_id VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON COLUMN public.audit_log.actor_type IS 'customer | staff | owner | system';
