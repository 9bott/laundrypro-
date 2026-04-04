-- Track the customer's current subscription product for UI (plan names from subscription_plans).
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS active_subscription_plan_id UUID REFERENCES public.subscription_plans (id),
  ADD COLUMN IF NOT EXISTS active_plan_name VARCHAR(100),
  ADD COLUMN IF NOT EXISTS active_plan_name_ar VARCHAR(100);

COMMENT ON COLUMN public.customers.active_subscription_plan_id IS 'Last purchased subscription plan (set by add-subscription).';
COMMENT ON COLUMN public.customers.active_plan_name IS 'Denormalized EN plan label for clients without a join.';
COMMENT ON COLUMN public.customers.active_plan_name_ar IS 'Denormalized AR plan label for clients without a join.';
