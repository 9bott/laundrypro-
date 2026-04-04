-- Query paths for mobile apps and dashboards.

CREATE INDEX IF NOT EXISTS idx_customers_phone
  ON public.customers (phone);

CREATE INDEX IF NOT EXISTS idx_transactions_customer_id
  ON public.transactions (customer_id);

CREATE INDEX IF NOT EXISTS idx_transactions_created_at
  ON public.transactions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_staff_id
  ON public.transactions (staff_id);
