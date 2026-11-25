const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const draft = read('seguranca/rascunho_rls.sql');
if (!/rollback;\s*$/i.test(draft)) throw new Error('Rascunho sem barreira de reversão.');

const legacySchemas = [
    'audiencias/supabase_schema.sql',
    'audiencias/supabase_add_prioridades.sql',
    'audiencias/supabase_add_reservado.sql',
    'audiencias/supabase_add_reu_revel.sql',
    'audiencias/supabase_add_salas.sql',
    'controle-processual/supabase_schema.sql'
];
const authorization = draft.replace(/^begin;\s*$/im, '').replace(/rollback;\s*$/i, '');
const previewSchema = `
-- Tabela mínima de teste do escopo de RLS. O aplicativo externo opera independentemente.
create table public.tempo_apn (id bigint primary key);
alter publication supabase_realtime add table public.salas;
`;
process.stdout.write([
    'begin;',
    `do $$ begin
        if current_setting('gerencial.homologacao_local', true) is distinct from 'sim'
           or to_regclass('public.audiencias') is not null
           or to_regclass('public.membros_mural') is not null then
            raise exception 'O banco de homologação precisa estar vazio e explicitamente identificado';
        end if;
    end $$;`,
    ...legacySchemas.map(read),
    previewSchema,
    authorization,
    read('seguranca/mural-local.sql'),
    'commit;'
].join('\n'));
