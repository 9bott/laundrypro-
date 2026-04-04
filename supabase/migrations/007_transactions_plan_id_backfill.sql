-- Link subscription transactions to plans and backfill customer active plan fields.

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES public.subscription_plans (id);

COMMENT ON COLUMN public.transactions.plan_id IS 'subscription_plans row for type=subscription (set by add-subscription).';

-- Infer plan_id for historical subscription rows (match amount to plan price; tie-break by sort_order).
UPDATE public.transactions t
SET plan_id = sub.plan_id
FROM (
  SELECT DISTINCT ON (t2.id)
    t2.id AS tid,
    sp.id AS plan_id
  FROM public.transactions t2
  INNER JOIN public.subscription_plans sp
    ON sp.price = t2.amount AND COALESCE(sp.is_active, true)
  WHERE t2.type = 'subscription'
    AND NOT t2.is_undone
    AND t2.plan_id IS NULL
  ORDER BY t2.id, sp.sort_order DESC NULLS LAST, sp.id
) sub
WHERE t.id = sub.tid
  AND t.plan_id IS NULL;

-- Backfill customers from their latest subscription transaction that has a plan.
UPDATE public.customers c
SET
  active_plan_name = sp.name,
  active_plan_name_ar = sp.name_ar,
  active_subscription_plan_id = sp.id
FROM public.transactions t
JOIN public.subscription_plans sp ON sp.id = t.plan_id
WHERE t.customer_id = c.id
  AND t.type = 'subscription'
  AND NOT t.is_undone
  AND t.plan_id IS NOT NULL
  AND t.created_at = (
    SELECT MAX(t2.created_at)
    FROM public.transactions t2
    WHERE t2.customer_id = c.id
      AND t2.type = 'subscription'
      AND NOT t2.is_undone
      AND t2.plan_id IS NOT NULL
  );

-- Align customers.tier with subscription product tier (same mapping as the app plans screen).
WITH ordered AS (
  SELECT
    id,
    ROW_NUMBER() OVER (ORDER BY sort_order ASC NULLS LAST, id) AS rn,
    COUNT(*) OVER () AS n
  FROM public.subscription_plans
  WHERE COALESCE(is_active, true)
),
plan_tier AS (
  SELECT
    id,
    CASE
      WHEN n >= 3 AND rn = 1 THEN 'silver'
      WHEN n >= 3 AND rn >= 2 THEN 'gold'
      WHEN n = 2 AND rn = 1 THEN 'silver'
      WHEN n = 2 AND rn = 2 THEN 'gold'
      WHEN n = 1 THEN 'gold'
      ELSE 'silver'
    END AS subscription_tier
  FROM ordered
)
UPDATE public.customers c
SET tier = pt.subscription_tier
FROM plan_tier pt
WHERE c.active_subscription_plan_id = pt.id;
