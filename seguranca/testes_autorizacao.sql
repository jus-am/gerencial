-- Executar exclusivamente em PostgreSQL descartável, nunca em produção.
-- Requer fixture de auth.users, auth.uid(), roles anon/authenticated e sete tabelas legadas.
-- Aplicar cópia de teste do rascunho com COMMIT, depois executar este arquivo.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002'),('00000000-0000-4000-8000-000000000003'),('00000000-0000-4000-8000-000000000004');
insert into public.perfis_usuarios values ('00000000-0000-4000-8000-000000000002','Consulta fictícia','consulta',true),('00000000-0000-4000-8000-000000000003','Servidor fictício','servidor',true),('00000000-0000-4000-8000-000000000004','Suspenso fictício','servidor',false);
insert into public.permissoes_usuarios values ('00000000-0000-4000-8000-000000000002','audiencias','select'),('00000000-0000-4000-8000-000000000002','audiencias','update'),('00000000-0000-4000-8000-000000000003','audiencias','select'),('00000000-0000-4000-8000-000000000003','audiencias','update'),('00000000-0000-4000-8000-000000000004','audiencias','select');
set local role authenticated;
do $$ begin
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
if gerencial_privado.autorizado('audiencias','select') then raise exception 'Sem perfil autorizado'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
if not gerencial_privado.autorizado('audiencias','select') or gerencial_privado.autorizado('audiencias','update') then raise exception 'Consulta incorreta'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
if not gerencial_privado.autorizado('audiencias','update') or gerencial_privado.autorizado('tempo_apn','select') then raise exception 'Permissão cruzada'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
if gerencial_privado.autorizado('audiencias','select') then raise exception 'Suspenso autorizado'; end if;
end $$;
reset role;
rollback;
