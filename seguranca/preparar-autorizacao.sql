-- PROPOSTA NÃO EXECUTADA. Aplicar somente após backup, classificação e homologação.
begin;
do $ begin
    if current_setting('gerencial.liberacao_producao', true) is distinct from 'confirmada' then
        raise exception 'Mudança bloqueada: confirme o backup, a restauração e a janela de produção';
    end if;
end $;
create table public.perfis_usuarios (
 user_id uuid references auth.users(id) on delete cascade,
 aplicativo text not null check(aplicativo in ('audiencias','controle_processual','tempo_apn')),
 nome text not null, perfil text not null check(perfil in ('administrador','servidor','consulta')),
 ativo boolean not null default false,
 primary key(user_id, aplicativo)
);
create table public.permissoes_usuarios (
 user_id uuid not null,
 aplicativo text not null check(aplicativo in ('audiencias','controle_processual','tempo_apn')),
 operacao text not null check(operacao in ('select','insert','update','delete')),
 primary key(user_id,aplicativo,operacao),
 foreign key(user_id,aplicativo) references public.perfis_usuarios(user_id,aplicativo) on delete cascade
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
select exists(select 1 from public.perfis_usuarios p where p.user_id=(select auth.uid()) and p.aplicativo=app and p.ativo
 and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') = 'false' and
(((p.perfil in ('administrador','servidor') or (p.perfil='consulta' and op='select')) and exists(select 1 from public.permissoes_usuarios a where a.user_id=p.user_id and a.aplicativo=app and a.operacao=op))))
$$;
revoke all on function gerencial_privado.autorizado(text,text) from public,anon,authenticated;
grant execute on function gerencial_privado.autorizado(text,text) to authenticated;
commit;
