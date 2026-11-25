-- Aplicar somente após provisionar os acessos autorizados e verificar backup.
begin;
do $$ begin
    if current_setting('gerencial.liberacao_producao', true) is distinct from 'confirmada' then
        raise exception 'Mudança bloqueada: confirme o backup, a restauração e a janela de produção';
    end if;
end $$;
lock table public."audiencias", public."cartas_precatorias", public."magistrados", public."processos_idosos", public."promotores", public."salas" in share row exclusive mode;
do $$
declare app text;
begin
    foreach app in array array['audiencias','controle_processual'] loop
        if not exists (
            select 1 from public.perfis_usuarios p
            join public.permissoes_usuarios a using(user_id, aplicativo)
            where p.aplicativo=app and p.ativo and a.operacao='select'
        ) then
            raise exception 'Aplicativo sem usuário autorizado: %', app;
        end if;
    end loop;
    if (select count(*) from pg_catalog.pg_policies where schemaname='public'
        and tablename in ('audiencias','cartas_precatorias','magistrados','processos_idosos','promotores','salas')) <> 6
       or exists (select 1 from pg_catalog.pg_policies where schemaname='public'
        and tablename in ('audiencias','cartas_precatorias','magistrados','processos_idosos','promotores','salas')
        and (policyname, permissive, roles::text, cmd, qual, with_check) is distinct from
            ('authenticated access','PERMISSIVE','{public}','ALL',
             '(auth.role() = ''authenticated''::text)','(auth.role() = ''authenticated''::text)')) then
        raise exception 'Catálogo de políticas diferente da captura de produção';
    end if;
end $$;
-- Segunda etapa: somente após saneamento confirmado. Não executar isoladamente.
-- Políticas antigas são substituídas atomicamente; nenhum dado é apagado.
do $$
declare t text; app text; op text; politica text; sequencia text;
begin
foreach t in array array['audiencias','magistrados','promotores','salas','processos_idosos','cartas_precatorias'] loop
app:=case when t in ('audiencias','magistrados','promotores','salas') then 'audiencias' when t='tempo_apn' then 'tempo_apn' else 'controle_processual' end;
execute format('alter table public.%I enable row level security',t);
for politica in select policyname from pg_catalog.pg_policies where schemaname='public' and tablename=t loop
execute format('drop policy %I on public.%I',politica,t);
end loop;
execute format('revoke all on public.%I from public,anon,authenticated',t);
execute format('grant select,insert,update,delete on public.%I to authenticated',t);
if exists(select 1 from information_schema.columns
          where table_schema='public' and table_name=t and column_name='id') then
sequencia:=pg_get_serial_sequence(format('public.%I',t),'id');
if sequencia is not null then
execute format('revoke all on sequence %s from public,anon,authenticated',sequencia);
execute format('grant usage on sequence %s to authenticated',sequencia);
end if;
end if;
foreach op in array array['select','insert','update','delete'] loop
execute format('create policy %I on public.%I for %s to authenticated %s', 'gerencial_'||op,t,op,
case when op='insert' then format('with check (gerencial_privado.autorizado(%L,%L))',app,op)
when op='update' then format('using (gerencial_privado.autorizado(%L,%L)) with check (gerencial_privado.autorizado(%L,%L))',app,op,app,op)
else format('using (gerencial_privado.autorizado(%L,%L))',app,op) end);
end loop;
end loop;
end $$;
commit;
