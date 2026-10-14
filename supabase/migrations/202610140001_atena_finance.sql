-- Atena Financeiro: despesas compartilhadas e comprovantes privados.
create table if not exists public.atena_expenses (
  id uuid primary key default gen_random_uuid(),
  description text not null check (length(trim(description)) between 1 and 180),
  category_group text not null check (category_group in ('Despesas Fixas','Despesas Variáveis','Despesas Diversas','Investimentos')),
  account_name text not null,
  expense_date date not null,
  due_date date,
  amount numeric(12,2) not null check (amount > 0),
  interest numeric(12,2) not null default 0 check (interest >= 0),
  status text not null default 'pending' check (status in ('pending','paid','overdue')),
  paid_date date,
  payment_method text,
  notes text,
  receipt_path text,
  receipt_name text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint atena_expenses_paid_date_check check (status <> 'paid' or paid_date is not null),
  constraint atena_expenses_overdue_due_date_check check (status <> 'overdue' or due_date is not null)
);

create index if not exists atena_expenses_expense_date_idx on public.atena_expenses (expense_date desc);
create index if not exists atena_expenses_due_date_idx on public.atena_expenses (due_date);

create table if not exists public.atena_sale_receivables (
  id uuid primary key default gen_random_uuid(),
  sale_key text not null,
  sale_date date not null,
  client_name text not null,
  ticket text not null,
  due_date date not null,
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending','received')),
  received_date date,
  payment_method text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  constraint atena_receivable_received_date_check check (status <> 'received' or received_date is not null)
);
create table if not exists public.atena_financial_accounts (
  id uuid primary key default gen_random_uuid(),
  category_group text not null check (category_group in ('Despesas Fixas','Despesas Variáveis','Despesas Diversas','Investimentos')),
  account_name text not null check (length(trim(account_name)) between 1 and 100),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (category_group, account_name)
);
create table if not exists public.atena_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  label text not null check (length(trim(label)) between 1 and 80),
  institution text not null check (length(trim(institution)) between 1 and 80),
  account_type text not null check (account_type in ('Conta corrente','Conta poupança','Conta de pagamento','Cartão','Outro')),
  last4 text check (last4 is null or last4 ~ '^\d{4}$'),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (institution, label)
);
create table if not exists public.atena_financial_parties (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  party_type text not null check (party_type in ('Fornecedor','Recebedor','Ambos')),
  contact text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (name, party_type)
);
alter table public.atena_expenses add column if not exists party_id uuid references public.atena_financial_parties(id) on delete set null;
alter table public.atena_expenses add column if not exists bank_account_id uuid references public.atena_bank_accounts(id) on delete set null;
create index if not exists atena_sale_receivables_due_date_idx on public.atena_sale_receivables (due_date);
create index if not exists atena_sale_receivables_sale_key_idx on public.atena_sale_receivables (sale_key);

alter table public.atena_expenses enable row level security;
revoke all on table public.atena_expenses from public, anon, authenticated;
grant select, insert, update, delete on table public.atena_expenses to authenticated;

drop policy if exists "Atena expenses read" on public.atena_expenses;
create policy "Atena expenses read" on public.atena_expenses
  for select to authenticated using ((select private.is_atena_user()));
drop policy if exists "Atena expenses insert" on public.atena_expenses;
create policy "Atena expenses insert" on public.atena_expenses
  for insert to authenticated with check ((select private.is_atena_user()) and created_by = auth.uid());
drop policy if exists "Atena expenses update" on public.atena_expenses;
create policy "Atena expenses update" on public.atena_expenses
  for update to authenticated using ((select private.is_atena_user())) with check ((select private.is_atena_user()));
drop policy if exists "Atena expenses delete" on public.atena_expenses;
create policy "Atena expenses delete" on public.atena_expenses
  for delete to authenticated using ((select private.is_atena_user()));

alter table public.atena_sale_receivables enable row level security;
revoke all on table public.atena_sale_receivables from public, anon, authenticated;
grant select, insert, update, delete on table public.atena_sale_receivables to authenticated;
drop policy if exists "Atena receivables read" on public.atena_sale_receivables;
create policy "Atena receivables read" on public.atena_sale_receivables
  for select to authenticated using ((select private.is_atena_user()));
drop policy if exists "Atena receivables insert" on public.atena_sale_receivables;
create policy "Atena receivables insert" on public.atena_sale_receivables
  for insert to authenticated with check ((select private.is_atena_user()) and created_by = auth.uid());
drop policy if exists "Atena receivables update" on public.atena_sale_receivables;
create policy "Atena receivables update" on public.atena_sale_receivables
  for update to authenticated using ((select private.is_atena_user())) with check ((select private.is_atena_user()));
drop policy if exists "Atena receivables delete" on public.atena_sale_receivables;
create policy "Atena receivables delete" on public.atena_sale_receivables
  for delete to authenticated using ((select private.is_atena_user()));

alter table public.atena_financial_accounts enable row level security;
alter table public.atena_bank_accounts enable row level security;
alter table public.atena_financial_parties enable row level security;
revoke all on table public.atena_financial_accounts, public.atena_bank_accounts, public.atena_financial_parties from public, anon, authenticated;
grant select, insert, update, delete on table public.atena_financial_accounts, public.atena_bank_accounts, public.atena_financial_parties to authenticated;
drop policy if exists "Atena manage accounts" on public.atena_financial_accounts;
drop policy if exists "Atena accounts read" on public.atena_financial_accounts;
drop policy if exists "Atena accounts insert" on public.atena_financial_accounts;
drop policy if exists "Atena accounts update" on public.atena_financial_accounts;
drop policy if exists "Atena accounts delete" on public.atena_financial_accounts;
create policy "Atena accounts read" on public.atena_financial_accounts for select to authenticated using ((select private.is_atena_user()));
create policy "Atena accounts insert" on public.atena_financial_accounts for insert to authenticated with check ((select private.is_atena_user()) and created_by = auth.uid());
create policy "Atena accounts update" on public.atena_financial_accounts for update to authenticated using ((select private.is_atena_user())) with check ((select private.is_atena_user()));
create policy "Atena accounts delete" on public.atena_financial_accounts for delete to authenticated using ((select private.is_atena_user()));
drop policy if exists "Atena manage banks" on public.atena_bank_accounts;
drop policy if exists "Atena banks read" on public.atena_bank_accounts;
drop policy if exists "Atena banks insert" on public.atena_bank_accounts;
drop policy if exists "Atena banks update" on public.atena_bank_accounts;
drop policy if exists "Atena banks delete" on public.atena_bank_accounts;
create policy "Atena banks read" on public.atena_bank_accounts for select to authenticated using ((select private.is_atena_user()));
create policy "Atena banks insert" on public.atena_bank_accounts for insert to authenticated with check ((select private.is_atena_user()) and created_by = auth.uid());
create policy "Atena banks update" on public.atena_bank_accounts for update to authenticated using ((select private.is_atena_user())) with check ((select private.is_atena_user()));
create policy "Atena banks delete" on public.atena_bank_accounts for delete to authenticated using ((select private.is_atena_user()));
drop policy if exists "Atena manage parties" on public.atena_financial_parties;
drop policy if exists "Atena parties read" on public.atena_financial_parties;
drop policy if exists "Atena parties insert" on public.atena_financial_parties;
drop policy if exists "Atena parties update" on public.atena_financial_parties;
drop policy if exists "Atena parties delete" on public.atena_financial_parties;
create policy "Atena parties read" on public.atena_financial_parties for select to authenticated using ((select private.is_atena_user()));
create policy "Atena parties insert" on public.atena_financial_parties for insert to authenticated with check ((select private.is_atena_user()) and created_by = auth.uid());
create policy "Atena parties update" on public.atena_financial_parties for update to authenticated using ((select private.is_atena_user())) with check ((select private.is_atena_user()));
create policy "Atena parties delete" on public.atena_financial_parties for delete to authenticated using ((select private.is_atena_user()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('atena-expense-receipts','atena-expense-receipts',false,15728640,array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update set public=false,file_size_limit=15728640,allowed_mime_types=array['application/pdf','image/jpeg','image/png'];

drop policy if exists "Atena receipt read" on storage.objects;
create policy "Atena receipt read" on storage.objects
  for select to authenticated using (bucket_id='atena-expense-receipts' and (select private.is_atena_user()));
drop policy if exists "Atena receipt insert" on storage.objects;
create policy "Atena receipt insert" on storage.objects
  for insert to authenticated with check (bucket_id='atena-expense-receipts' and (select private.is_atena_user()) and (storage.foldername(name))[1]=(select auth.uid()::text));
drop policy if exists "Atena receipt update" on storage.objects;
create policy "Atena receipt update" on storage.objects
  for update to authenticated using (bucket_id='atena-expense-receipts' and (select private.is_atena_user()) and (storage.foldername(name))[1]=(select auth.uid()::text))
  with check (bucket_id='atena-expense-receipts' and (select private.is_atena_user()) and (storage.foldername(name))[1]=(select auth.uid()::text));
drop policy if exists "Atena receipt delete" on storage.objects;
create policy "Atena receipt delete" on storage.objects
  for delete to authenticated using (bucket_id='atena-expense-receipts' and (select private.is_atena_user()) and (storage.foldername(name))[1]=(select auth.uid()::text));

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='atena_expenses') then
    execute 'alter publication supabase_realtime add table public.atena_expenses';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='atena_sale_receivables') then
    execute 'alter publication supabase_realtime add table public.atena_sale_receivables';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='atena_financial_accounts') then
    execute 'alter publication supabase_realtime add table public.atena_financial_accounts';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='atena_bank_accounts') then
    execute 'alter publication supabase_realtime add table public.atena_bank_accounts';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='atena_financial_parties') then
    execute 'alter publication supabase_realtime add table public.atena_financial_parties';
  end if;
end $$;
