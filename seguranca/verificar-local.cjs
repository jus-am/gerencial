const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const { PGlite } = require('../.test-runtime/node_modules/@electric-sql/pglite');

const read = (file) => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

for (const file of ['index.html', 'audiencias/index.html', 'controle-processual/index.html', 'homologacao/index.html']) {
    test(`JavaScript e ausência de endpoint de produção em ${file}`, () => {
        const html = read(file);
        assert.doesNotMatch(html, /qcvietuczbysditpkopr/);
        for (const [, script] of html.matchAll(/<script>([\s\S]*?)<\/script>/gi)) {
            new vm.Script(script, {filename: file});
        }
    });
}

const local = 'http://127.0.0.1:54321';
const valid = {url: local, publishableKey: 'sb_publishable_EXEMPLO'};
function startClient(config, hostname = '127.0.0.1', origin = 'http://127.0.0.1:8080') {
    const window = {
        GERENCIAL_HOMOLOGACAO: config,
        supabase: {createClient: (url, key, options) => ({url, key, options})}
    };
    vm.runInNewContext(read('seguranca/cliente-homologacao.js'), {window, URL, location: {hostname, origin}});
    return window.criarClienteHomologacao('sessao-de-teste');
}

test('aceita endpoint estritamente local com chave publicável', () => {
    const client = startClient(valid);
    assert.equal(client.url, local);
    assert.equal(client.options.auth.storageKey, 'sessao-de-teste');
});

test('Codespace aceita apenas seu próprio endereço HTTPS', () => {
    const hostname = 'gerencial-preview-8080.app.github.dev';
    const origin = 'https://' + hostname;
    assert.equal(startClient({...valid, url: origin}, hostname, origin).url, origin);
    assert.throws(() => startClient({...valid, url: 'https://outro-8080.app.github.dev'}, hostname, origin));
    assert.throws(() => startClient({...valid, url: 'http://' + hostname}, hostname, 'http://' + hostname));
});

for (const [config, host] of [
    [undefined],
    [{...valid, url: 'https://servico-remoto.example'}],
    [{...valid, url: local + '/outro/'}],
    [{...valid, publishableKey: 'sb_secret_EXEMPLO'}],
    [valid, 'portal.example']
]) {
    test(`bloqueia configuração inadequada ${JSON.stringify([config, host])}`, () => {
        assert.throws(() => startClient(config, host));
    });
}

test('PostgreSQL embarcado: perfis, políticas legadas, operações e reversão', async () => {
    const db = new PGlite();
    try {
        await db.exec(`
            create role anon;
            create role authenticated;
            create schema auth;
            grant usage on schema auth to authenticated;
            create table auth.users(id uuid primary key);
            create function auth.uid() returns uuid language sql stable
                as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
            create function auth.jwt() returns jsonb language sql stable
                as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
            create function auth.role() returns text language sql stable
                as $$ select current_user::text $$;
            create publication supabase_realtime;
            create table public.tempo_apn(id bigint primary key);
        `);
        for (const file of ['audiencias/supabase_schema.sql', 'audiencias/supabase_add_salas.sql', 'controle-processual/supabase_schema.sql']) {
            await db.exec(read(file));
        }
        const draft = read('seguranca/rascunho_rls.sql');
        assert.match(draft, /rollback;\s*$/);
        await db.exec(draft);
        const result = await db.query("select to_regclass('public.perfis_usuarios') as table_name");
        assert.equal(result.rows[0].table_name, null);
        await db.exec(draft.replace(/rollback;\s*$/, 'commit;'));
        await db.exec(read('seguranca/testes_autorizacao.sql'));
        await db.exec(read('seguranca/mural-local.sql'));
        await db.exec(`
            insert into auth.users(id) values
                ('00000000-0000-4000-8000-000000000011'),
                ('00000000-0000-4000-8000-000000000012');
            insert into public.membros_mural values
                ('00000000-0000-4000-8000-000000000011', 'diretor'),
                ('00000000-0000-4000-8000-000000000012', 'consulta');
            set role authenticated;
            select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',false);
            insert into public.avisos_secretaria(titulo, conteudo) values ('Fictício', 'Fictício');
        `);
        assert.equal((await db.query('select * from public.historico_avisos')).rows.length, 1);
        await assert.rejects(db.exec('delete from public.avisos_secretaria'), {code: '42501'});
        await db.exec("select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',false)");
        assert.equal((await db.query('select * from public.avisos_secretaria')).rows.length, 1);
        assert.equal((await db.query("update public.avisos_secretaria set titulo='Outro' returning id")).rows.length, 0);
        await db.exec("select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',false)");
        await db.exec('update public.avisos_secretaria set excluido_em=now()');
        assert.equal((await db.query('select * from public.historico_avisos')).rows.length, 2);
        await db.exec("select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',false)");
        assert.equal((await db.query('select * from public.avisos_secretaria')).rows.length, 0);
    } finally {
        await db.close();
    }
});

test('bootstrap completo recusa destino sem marca e funciona em banco descartável', async () => {
    const db = new PGlite();
    try {
        await db.exec(`
            create role anon;
            create role authenticated;
            create schema auth;
            create table auth.users(id uuid primary key);
            create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
            create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;
            create function auth.role() returns text language sql stable as $$ select current_user::text $$;
            create publication supabase_realtime;
        `);
        const bootstrap = execFileSync(process.execPath, [path.join(__dirname, 'preparar-banco-local.cjs')],
            {encoding: 'utf8'});
        await assert.rejects(db.exec(bootstrap));
        await db.exec("rollback; set gerencial.homologacao_local = 'sim';");
        await db.exec(bootstrap);
        assert.equal((await db.query('select count(*)::int as total from public.audiencias')).rows[0].total, 0);
        await assert.rejects(db.exec(bootstrap));
    } finally {
        await db.close();
    }
});
