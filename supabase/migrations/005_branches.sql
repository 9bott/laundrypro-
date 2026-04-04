-- Branches (locations) — used for listing store branches in the app/admin.
-- Requires: pgcrypto (gen_random_uuid — available on Supabase by default)

CREATE TABLE IF NOT EXISTS public.branches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  address TEXT,
  address_ar TEXT,
  phone TEXT,
  whatsapp TEXT,
  location_lat DECIMAL,
  location_lng DECIMAL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed: one demo branch (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.branches WHERE name = 'Main Branch') THEN
    INSERT INTO public.branches
      (name, name_ar, address, address_ar, phone, whatsapp, location_lat, location_lng)
    VALUES
      (
        'Main Branch',
        'الفرع الرئيسي',
        'Riyadh, Saudi Arabia',
        'الرياض، المملكة العربية السعودية',
        '+966500000000',
        '+966500000000',
        24.7136,
        46.6753
      );
  END IF;
END $$;

-- RLS
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'branches'
      AND policyname = 'branches_read'
  ) THEN
    CREATE POLICY "branches_read"
      ON public.branches
      FOR SELECT
      USING (true);
  END IF;
END $$;

