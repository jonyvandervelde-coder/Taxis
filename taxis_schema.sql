-- =====================================================================
-- TaxÍs — Core Accounting Engine: Transactions Schema
-- =====================================================================
-- NOTE: No database schema file existed in the TaxÍs project uploads
-- (docs/ and files/ were empty; only architecture notes were present).
-- This schema is a NEW proposal, designed to be consistent with the
-- documented TaxÍs data-handling philosophy:
--   - "App stores only numbers users enter or confirm — not raw documents"
--   - Receipt/payslip images are OCR'd client-side or via the AI call,
--     the user confirms the extracted figures, and the image itself
--     is discarded (no image_url / blob storage column below on purpose).
--   - Every AI-derived record is estimate-until-confirmed — nothing is
--     treated as an authoritative tax/deduction ruling.
-- Replace/merge this with your actual schema if one already exists.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Reference table: valid Icelandic VSK (VAT) categories.
-- Kept as a real table (not just a CHECK constraint) so the app can
-- show category labels/examples in-app and so the AI extraction
-- prompt can be built dynamically from this table instead of being
-- hardcoded in Swift.
-- ---------------------------------------------------------------------
create table if not exists vsk_categories (
    code            text primary key,              -- 'standard_24' | 'reduced_11' | 'exempt_0'
    rate            numeric(5,4) not null,          -- 0.2400 | 0.1100 | 0.0000
    label_is        text not null,
    label_en        text not null,
    example_is      text not null                    -- example goods/services, used in the AI prompt
);

insert into vsk_categories (code, rate, label_is, label_en, example_is) values
    ('standard_24', 0.2400, 'Almennt þrep', 'Standard rate (24%)',
     'Almennar vörur og þjónusta, t.d. raftæki, fatnaður, eldsneyti, áfengi'),
    ('reduced_11',  0.1100, 'Lægra þrep', 'Reduced rate (11%)',
     'Matvæli, gisting, veitingaþjónusta (sala matar), bækur, tímarit, hiti og rafmagn til heimila'),
    ('exempt_0',    0.0000, 'Undanþegið VSK', 'VAT-exempt (0%)',
     'Heilbrigðisþjónusta, tryggingar, fjármálaþjónusta, íbúðaleiga')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------
-- Core table: one row per receipt/invoice transaction extracted
-- (by the AI model) and confirmed (by the user).
-- ---------------------------------------------------------------------
create table if not exists transactions (
    id                      uuid primary key default gen_random_uuid(),
    user_id                 uuid not null references auth.users(id) on delete cascade,

    -- --- Source document metadata (no image/file retained) ---
    source_document_type    text not null default 'receipt'
                                 check (source_document_type in ('receipt', 'invoice', 'payslip')),
    original_text_hash      text,                    -- sha256 of the OCR'd text, for dedupe only — never the raw text/image

    -- --- Vendor info ---
    vendor_name             text not null,
    vendor_kennitala        text,                    -- 10-digit Icelandic ID, nullable (not always legible/present)

    -- --- Amounts (always ISK; multi-currency is out of scope for v1) ---
    currency                text not null default 'ISK',
    total_amount_isk        numeric(12,2) not null,  -- gross, incl. VSK
    net_amount_isk          numeric(12,2) not null,  -- net, excl. VSK
    vsk_amount_isk          numeric(12,2) not null,  -- total_amount_isk - net_amount_isk

    -- --- VSK classification ---
    vsk_category            text not null references vsk_categories(code),
    vsk_rate                numeric(5,4) not null,   -- snapshot of the rate at extraction time (audit trail if rates change)

    -- Payslip-only salary figures (null for receipts / invoices)
    gross_pay_isk           numeric(14,2),              -- laun alls / bruttólaun
    tax_withheld_isk        numeric(14,2),              -- staðgreiðsla (net of persónuafsláttur)

    -- --- Line-item breakdown, only populated when a receipt mixes VSK
    -- rates (e.g. a supermarket receipt with food at 11% and household
    -- goods at 24%). Null for single-rate receipts.
    line_items               jsonb,

    transaction_date        date not null,

    -- --- AI extraction audit trail ---
    ai_model                text not null,           -- e.g. 'claude-sonnet-5'
    ai_confidence            numeric(3,2)
                                 check (ai_confidence is null or (ai_confidence between 0 and 1)),
    ai_raw_response          jsonb not null,           -- full structured response, for debugging/audit

    -- --- Confirmation workflow (nothing is "official" until confirmed) ---
    extraction_status       text not null default 'pending_review'
                                 check (extraction_status in ('pending_review', 'confirmed', 'rejected')),
    confirmed_at             timestamptz,

    notes                    text,

    created_at               timestamptz not null default now(),
    updated_at               timestamptz not null default now(),

    -- --- Sanity constraints ---
    constraint chk_amounts_consistent
        check (abs(total_amount_isk - (net_amount_isk + vsk_amount_isk)) < 1.00),
    constraint chk_positive_amounts
        check (total_amount_isk >= 0 and net_amount_isk >= 0 and vsk_amount_isk >= 0)
);

create index if not exists idx_transactions_user_id on transactions (user_id);
create index if not exists idx_transactions_date on transactions (transaction_date);
create index if not exists idx_transactions_status on transactions (extraction_status);

-- ---------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists trg_transactions_updated_at on transactions;
create trigger trg_transactions_updated_at
    before update on transactions
    for each row
    execute function set_updated_at();

-- ---------------------------------------------------------------------
-- Row Level Security — each user only ever sees their own transactions.
-- ---------------------------------------------------------------------
alter table transactions enable row level security;

drop policy if exists "Users can view own transactions" on transactions;
create policy "Users can view own transactions"
    on transactions for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own transactions" on transactions;
create policy "Users can insert own transactions"
    on transactions for insert
    with check (auth.uid() = user_id);

drop policy if exists "Users can update own transactions" on transactions;
create policy "Users can update own transactions"
    on transactions for update
    using (auth.uid() = user_id);

drop policy if exists "Users can delete own transactions" on transactions;
create policy "Users can delete own transactions"
    on transactions for delete
    using (auth.uid() = user_id);
