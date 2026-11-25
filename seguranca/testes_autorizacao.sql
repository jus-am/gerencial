-- Executar exclusivamente em PostgreSQL descartável, nunca em produção.
-- Requer fixture de auth.users, auth.uid(), roles anon/authenticated e sete tabelas legadas.
-- Aplicar cópia de teste do rascunho com COMMIT, depois executar este arquivo.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002'),('00000000-0000-4000-8000-000000000003'),('00000000-0000-4000-8000-000000000004');
insert into public.perfis_usuarios values ('00000000-0000-4000-8000-000000000002','audiencias','Consulta fictícia','consulta',true),('00000000-0000-4000-8000-000000000003','audiencias','Servidor fictício','servidor',true),('00000000-0000-4000-8000-000000000004','audiencias','Suspenso fictício','servidor',false);
insert into public.permissoes_usuarios values ('00000000-0000-4000-8000-000000000002','audiencias','select'),('00000000-0000-4000-8000-000000000002','audiencias','update'),('00000000-0000-4000-8000-000000000003','audiencias','select'),('00000000-0000-4000-8000-000000000003','audiencias','update'),('00000000-0000-4000-8000-000000000004','audiencias','select');
insert into public.perfis_usuarios values
    ('00000000-0000-4000-8000-000000000003','controle_processual','Consulta fictícia','consulta',true);
insert into public.permissoes_usuarios values
    ('00000000-0000-4000-8000-000000000003','controle_processual','select'),
    ('00000000-0000-4000-8000-000000000003','controle_processual','update');
insert into public.audiencias(id, processo) values (1, 'FICTICIO');
set local role authenticated;
do $$ declare affected integer;
begin
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
if gerencial_privado.autorizado('audiencias','select') then raise exception 'Sem perfil autorizado'; end if;
if exists(select 1 from public.audiencias) then raise exception 'Política legada ainda permite leitura'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
if not gerencial_privado.autorizado('audiencias','select') or gerencial_privado.autorizado('audiencias','update') then raise exception 'Consulta incorreta'; end if;
update public.audiencias set processo='FICTICIO-BLOQUEADO' where id=1;
get diagnostics affected=row_count;
if affected<>0 then raise exception 'Consulta alterou audiência'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
if not gerencial_privado.autorizado('audiencias','update') or gerencial_privado.autorizado('tempo_apn','select') then raise exception 'Permissão cruzada'; end if;
if not gerencial_privado.autorizado('controle_processual','select') or gerencial_privado.autorizado('controle_processual','update') then raise exception 'Perfis por aplicativo não isolados'; end if;
update public.audiencias set processo='FICTICIO-ATUALIZADO' where id=1;
get diagnostics affected=row_count;
if affected<>1 then raise exception 'Operação autorizada não confirmada'; end if;
perform set_config('request.jwt.claims','{"is_anonymous":true}',true);
if exists(select 1 from public.audiencias) then raise exception 'Identidade anônima autorizada'; end if;
perform set_config('request.jwt.claims','{}',true);
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
if gerencial_privado.autorizado('audiencias','select') then raise exception 'Suspenso autorizado'; end if;
if has_table_privilege(current_user,'public.audiencias','TRUNCATE')
   or has_table_privilege(current_user,'public.perfis_usuarios','UPDATE')
   or has_table_privilege('anon','public.audiencias','SELECT') then
    raise exception 'Privilégio direto indevido';
end if;
end $$;
reset role;
rollback;
