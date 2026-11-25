-- PROPOSTA NÃO EXECUTADA. Aplicar somente após backup, classificação e homologação.
begin;
create table public.perfis_usuarios (
 user_id uuid primary key references auth.users(id) on delete cascade,
 nome text not null, perfil text not null check(perfil in ('administrador','servidor','consulta')),
 ativo boolean not null default false
);
create table public.permissoes_usuarios (
 user_id uuid references public.perfis_usuarios(user_id) on delete cascade,
 aplicativo text not null check(aplicativo in ('audiencias','controle_processual','tempo_apn')),
 operacao text not null check(operacao in ('select','insert','update','delete')),
 primary key(user_id,aplicativo,operacao)
);
alter table public.perfis_usuarios enable row level security;
alter table public.permissoes_usuarios enable row level security;
revoke all on public.perfis_usuarios,public.permissoes_usuarios from public,anon,authenticated;
grant select on public.perfis_usuarios,public.permissoes_usuarios to authenticated;
create policy perfil_proprio on public.perfis_usuarios for select to authenticated using(user_id=(select auth.uid()));
create policy permissoes_proprias on public.permissoes_usuarios for select to authenticated using(user_id=(select auth.uid()));
-- Perfis dos aplicativos são provisionados independentemente do mural.
-- Nenhum usuário, inclusive o diretor do mural, recebe acesso automático aos aplicativos.
-- Autorizações de cada aplicativo deverão ser provisionadas separadamente antes da troca de políticas.
create schema if not exists gerencial_privado;
revoke all on schema gerencial_privado from public,anon,authenticated;
grant usage on schema gerencial_privado to authenticated;
create function gerencial_privado.autorizado(app text,op text) returns boolean
language sql stable security invoker set search_path='' as $$
select exists(select 1 from public.perfis_usuarios p where p.user_id=(select auth.uid()) and p.ativo and
(((p.perfil in ('administrador','servidor') or (p.perfil='consulta' and op='select')) and exists(select 1 from public.permissoes_usuarios a where a.user_id=p.user_id and a.aplicativo=app and a.operacao=op))))
$$;
revoke all on function gerencial_privado.autorizado(text,text) from public,anon,authenticated;
grant execute on function gerencial_privado.autorizado(text,text) to authenticated;
-- Segunda etapa: somente após saneamento confirmado. Não executar isoladamente.
-- Políticas antigas são substituídas atomicamente; nenhum dado é apagado.
do $$
declare t text; app text; op text;
begin
foreach t in array array['audiencias','magistrados','promotores','salas','processos_idosos','cartas_precatorias','tempo_apn'] loop
app:=case when t in ('audiencias','magistrados','promotores','salas') then 'audiencias' when t='tempo_apn' then 'tempo_apn' else 'controle_processual' end;
execute format('drop policy if exists %I on public.%I','authenticated access',t);
execute format('drop policy if exists %I on public.%I','Autenticados podem tudo',t);
execute format('revoke all on public.%I from public,anon,authenticated',t);
execute format('grant select,insert,update,delete on public.%I to authenticated',t);
foreach op in array array['select','insert','update','delete'] loop
execute format('create policy %I on public.%I for %s to authenticated %s', 'gerencial_'||op,t,op,
case when op='insert' then format('with check (gerencial_privado.autorizado(%L,%L))',app,op)
when op='update' then format('using (gerencial_privado.autorizado(%L,%L)) with check (gerencial_privado.autorizado(%L,%L))',app,op,app,op)
else format('using (gerencial_privado.autorizado(%L,%L))',app,op) end);
end loop;
end loop;
end $$;
-- BLOQUEIO INTENCIONAL: rascunho não pode ser aplicado por acidente.
rollback;
