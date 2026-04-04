-- Default subscription tiers (pay X → credit Y in subscription_balance).

INSERT INTO public.subscription_plans (
  name,
  name_ar,
  price,
  credit,
  bonus_percentage,
  sort_order
)
VALUES
  ('Basic', 'الأساسية', 100.00, 120.00, 20.00, 1),
  ('Silver', 'الفضية', 200.00, 250.00, 25.00, 2),
  ('Gold', 'الذهبية', 500.00, 650.00, 30.00, 3);
