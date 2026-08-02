-- ==========================================
-- TAXÍS MULTI-INCOME & HEIMAGISTING SCHEMA
-- ==========================================
-- Fixes applied vs. original draft:
--   1. Removed uuid-ossp (gen_random_uuid() is built-in, no extension needed)
--   2. Both tables reference auth.users(id) ON DELETE CASCADE
--   3. RLS enabled on both tables (own-row-only policies)
--   4. withholding_tax_paid: added CHECK (>= 0)
--   5. tax_ledger: added updated_at + trigger
--   6. View: cliff triggered → dynamic_airbnb_capital_tax_reserve is NULL
--      (not 0) so the frontend knows to use the progressive bracket engine;
--      added total_progressive_tax_base that merges airbnb when cliff fires
--   7. View: joined user_tax_profiles so persónuafsláttur is applied
-- Verify before deploying:
--   - available_persónuafsláttur default (72,492) — confirm 2026 RSK figure
--   - lodging_tax_per_night default (800) — confirm current Gistináttaskattur rate


-- ==========================================
-- 1. ENUMS
-- ==========================================

CREATE TYPE income_category AS ENUM ('launþegi', 'verktaki', 'heimagisting');
CREATE TYPE reporting_period  AS ENUM ('monthly', 'bimonthly', 'annual');


-- ==========================================
-- 2. USER TAX PROFILES
-- ==========================================

CREATE TABLE user_tax_profiles (
    user_id                    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    use_personal_discount      BOOLEAN DEFAULT TRUE,
    available_persónuafsláttur NUMERIC(12, 2) DEFAULT 72492.00, -- Verify: 2026 RSK (2025 was 60,995 ISK/mo)
    accumulated_salary_income  NUMERIC(12, 2) DEFAULT 0.00,
    updated_at                 TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

ALTER TABLE user_tax_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own profile"
    ON user_tax_profiles FOR ALL
    USING  (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- ==========================================
-- 3. CORE TAX LEDGER
-- ==========================================

CREATE TABLE tax_ledger (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category    income_category NOT NULL,
    gross_amount NUMERIC(12, 2) NOT NULL CHECK (gross_amount >= 0),
    date_logged  DATE NOT NULL DEFAULT CURRENT_DATE,
    description  TEXT,

    -- Verktaki fields
    deductible_expenses  NUMERIC(12, 2) DEFAULT 0.00 CHECK (deductible_expenses >= 0),
    withholding_tax_paid NUMERIC(12, 2) DEFAULT 0.00 CHECK (withholding_tax_paid >= 0),

    -- Heimagisting fields
    check_in                  DATE,
    check_out                 DATE,
    nights_count INT GENERATED ALWAYS AS (
        CASE
            WHEN check_out IS NOT NULL AND check_in IS NOT NULL
            THEN (check_out - check_in)
            ELSE NULL
        END
    ) STORED,
    lodging_tax_per_night     NUMERIC(10, 2) DEFAULT 800.00, -- Verify: current Gistináttaskattur rate
    is_external_vat_registered BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),

    CONSTRAINT check_heimagisting_dates CHECK (
        (category = 'heimagisting'
            AND check_in  IS NOT NULL
            AND check_out IS NOT NULL
            AND check_out > check_in)
        OR
        (category != 'heimagisting'
            AND check_in  IS NULL
            AND check_out IS NULL)
    )
);

ALTER TABLE tax_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own ledger"
    ON tax_ledger FOR ALL
    USING  (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- updated_at trigger
CREATE OR REPLACE FUNCTION set_tax_ledger_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tax_ledger_updated_at
    BEFORE UPDATE ON tax_ledger
    FOR EACH ROW EXECUTE FUNCTION set_tax_ledger_updated_at();


-- ==========================================
-- 4. DASHBOARD METRICS VIEW
-- ==========================================

CREATE OR REPLACE VIEW user_tax_dashboard_metrics AS
WITH aggregated AS (
    SELECT
        tl.user_id,
        EXTRACT(YEAR FROM tl.date_logged)                                                   AS tax_year,

        SUM(CASE WHEN tl.category = 'launþegi'
                 THEN tl.gross_amount ELSE 0 END)                                           AS total_salary_gross,

        SUM(CASE WHEN tl.category = 'verktaki'
                 THEN (tl.gross_amount - tl.deductible_expenses) ELSE 0 END)               AS total_contractor_net,

        SUM(CASE WHEN tl.category = 'heimagisting'
                 THEN tl.gross_amount ELSE 0 END)                                           AS total_airbnb_gross,

        SUM(CASE WHEN tl.category = 'heimagisting'
                 THEN COALESCE(tl.nights_count, 0) ELSE 0 END)                             AS total_airbnb_nights,

        SUM(CASE WHEN tl.category = 'heimagisting'
                 THEN COALESCE(tl.nights_count, 0) * tl.lodging_tax_per_night ELSE 0 END)  AS total_gistinattaskattur,

        -- Pull persónuafsláttur from profile (falls back to default if profile missing)
        COALESCE(MAX(p.available_persónuafsláttur), 72492.00)                               AS persónuafsláttur,
        COALESCE(BOOL_OR(p.use_personal_discount), TRUE)                                    AS use_personal_discount

    FROM tax_ledger tl
    LEFT JOIN user_tax_profiles p ON p.user_id = tl.user_id
    GROUP BY tl.user_id, EXTRACT(YEAR FROM tl.date_logged)
),
computed AS (
    SELECT *,
        (total_salary_gross + total_contractor_net)                      AS primary_progressive_tax_base,
        (total_airbnb_nights > 90 OR total_airbnb_gross > 2000000.00)   AS heimagisting_cliff_triggered
    FROM aggregated
)
SELECT
    user_id,
    tax_year,

    -- Base progressive tax income (salary + contractor, before airbnb)
    primary_progressive_tax_base,

    -- Full progressive base when cliff fires (airbnb merges in)
    CASE WHEN heimagisting_cliff_triggered
        THEN primary_progressive_tax_base + total_airbnb_gross
        ELSE primary_progressive_tax_base
    END                                                                 AS total_progressive_tax_base,

    -- Persónuafsláttur applied only when opted in
    CASE WHEN use_personal_discount
        THEN persónuafsláttur
        ELSE 0
    END                                                                 AS effective_persónuafsláttur,

    total_airbnb_gross,
    total_airbnb_nights,
    total_gistinattaskattur,
    heimagisting_cliff_triggered,

    -- Capital tax reserve (22%) — NULL when cliff triggered.
    -- When NULL, the frontend must use the progressive bracket engine
    -- against total_progressive_tax_base instead.
    CASE WHEN heimagisting_cliff_triggered
        THEN NULL
        ELSE ROUND(total_airbnb_gross * 0.22, 2)
    END                                                                 AS dynamic_airbnb_capital_tax_reserve,

    GREATEST(0,    90          - total_airbnb_nights) AS nights_remaining,
    GREATEST(0.00, 2000000.00  - total_airbnb_gross)  AS income_allowance_remaining

FROM computed;


-- ==========================================
-- 5. INDEXES
-- ==========================================

CREATE INDEX idx_tax_ledger_user_year ON tax_ledger (user_id, EXTRACT(YEAR FROM date_logged));
CREATE INDEX idx_tax_ledger_category  ON tax_ledger (category);
