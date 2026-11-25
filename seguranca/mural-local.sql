-- Esquema inicial para uma instância de homologação vazia.
create table public.membros_mural (
    user_id uuid primary key references auth.users(id) on delete cascade,
    papel text not null check (papel in ('diretor', 'consulta'))
);

create table public.avisos_secretaria (
    id uuid primary key default gen_random_uuid(),
    titulo text not null check (char_length(trim(titulo)) between 1 and 150),
    conteudo text not null check (char_length(trim(conteudo)) between 1 and 5000),
    prioridade text not null default 'informativo'
        check (prioridade in ('informativo', 'importante', 'urgente')),
    fixado boolean not null default false,
    expira_em timestamptz,
    arquivado boolean not null default false,
    autor uuid not null default auth.uid(),
    criado_em timestamptz not null default now(),
    atualizado_em timestamptz not null default now(),
    excluido_em timestamptz
);

create table public.historico_avisos (
    id bigint generated always as identity primary key,
    aviso_id uuid not null references public.avisos_secretaria(id),
    ator uuid,
    evento text not null,
    anterior jsonb,
    posterior jsonb,
    registrado_em timestamptz not null default now()
);

alter table public.membros_mural enable row level security;
alter table public.avisos_secretaria enable row level security;
alter table public.historico_avisos enable row level security;
revoke all on public.membros_mural, public.avisos_secretaria, public.historico_avisos
    from public, anon, authenticated;
grant select on public.membros_mural, public.avisos_secretaria, public.historico_avisos to authenticated;
grant insert (titulo, conteudo, prioridade, fixado, expira_em, arquivado),
      update (titulo, conteudo, prioridade, fixado, expira_em, arquivado, excluido_em)
    on public.avisos_secretaria to authenticated;

create policy mural_membro_proprio on public.membros_mural for select to authenticated
    using (user_id = (select auth.uid()) and
           coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') = 'false');
create policy mural_leitura on public.avisos_secretaria for select to authenticated using (
    exists (select 1 from public.membros_mural
            where user_id = (select auth.uid())
              and (papel = 'diretor' or (excluido_em is null and not arquivado
                   and (expira_em is null or expira_em > now()))))
);
create policy mural_insercao on public.avisos_secretaria for insert to authenticated with check (
    exists (select 1 from public.membros_mural where user_id = (select auth.uid()) and papel = 'diretor')
);
create policy mural_edicao on public.avisos_secretaria for update to authenticated using (
    exists (select 1 from public.membros_mural where user_id = (select auth.uid()) and papel = 'diretor')
) with check (
    exists (select 1 from public.membros_mural where user_id = (select auth.uid()) and papel = 'diretor')
);
create policy mural_historico on public.historico_avisos for select to authenticated using (
    exists (select 1 from public.membros_mural where user_id = (select auth.uid()) and papel = 'diretor')
);

create schema if not exists gerencial_privado;
revoke all on schema gerencial_privado from public, anon, authenticated;
create function gerencial_privado.auditar_aviso() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    insert into public.historico_avisos(aviso_id, ator, evento, anterior, posterior)
    values (new.id, auth.uid(), case
        when tg_op = 'INSERT' then 'criado'
        when old.excluido_em is null and new.excluido_em is not null then 'excluido'
        when not old.arquivado and new.arquivado then 'arquivado'
        else 'editado' end,
        case when tg_op = 'UPDATE' then to_jsonb(old) - 'conteudo' - 'titulo' end,
        to_jsonb(new) - 'conteudo' - 'titulo');
    return new;
end;
$$;
revoke all on function gerencial_privado.auditar_aviso() from public, anon, authenticated;
create trigger mural_auditoria after insert or update on public.avisos_secretaria
    for each row execute function gerencial_privado.auditar_aviso();

create function gerencial_privado.atualizar_aviso() returns trigger
language plpgsql set search_path = '' as $$
begin
    new.atualizado_em := now();
    return new;
end;
$$;
revoke all on function gerencial_privado.atualizar_aviso() from public, anon, authenticated;
create trigger mural_atualizacao before update on public.avisos_secretaria
    for each row execute function gerencial_privado.atualizar_aviso();

alter publication supabase_realtime add table public.avisos_secretaria;
