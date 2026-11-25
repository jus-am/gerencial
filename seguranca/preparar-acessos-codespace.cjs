const fs = require('node:fs');
const path = require('node:path');
const { randomBytes } = require('node:crypto');
const { execFileSync } = require('node:child_process');

async function prepare() {
    const name = process.env.CODESPACE_NAME;
    if (process.env.CODESPACES !== 'true' || !/^[a-z0-9-]+$/.test(name ?? '') ||
        process.env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN !== 'app.github.dev') throw Error();

    const status = JSON.parse(fs.readFileSync(0, 'utf8'));
    const key = status.PUBLISHABLE_KEY;
    if (!/^sb_publishable_[\w-]+$/.test(key ?? '')) throw Error();
    const url = `https://${name}-8080.app.github.dev`;
    fs.writeFileSync(path.join(__dirname, 'config.local.js'),
        `window.GERENCIAL_HOMOLOGACAO = ${JSON.stringify({url, publishableKey: key})};\n`,
        {mode: 0o600});

    const credentials = path.join(__dirname, 'acessos-codespace.txt');
    if (fs.existsSync(credentials)) return;
    if (!status.SERVICE_ROLE_KEY) throw Error();
    const users = [];
    const statements = [];
    const batch = randomBytes(5).toString('hex');
    for (const [label, app, role] of [
        ['Mural diretor', 'mural', 'diretor'],
        ['Mural consulta', 'mural', 'consulta'],
        ['Audiências servidor', 'audiencias', 'servidor'],
        ['Audiências consulta', 'audiencias', 'consulta'],
        ['Controle Processual servidor', 'controle_processual', 'servidor'],
        ['Controle Processual consulta', 'controle_processual', 'consulta'],
        ['Conta sem permissão', null, null]
    ]) {
        const email = `teste-${batch}-${users.length + 1}@example.test`;
        const password = randomBytes(24).toString('base64url');
        const response = await fetch('http://127.0.0.1:54321/auth/v1/admin/users', {
            method: 'POST',
            headers: {apikey: status.SERVICE_ROLE_KEY, Authorization: `Bearer ${status.SERVICE_ROLE_KEY}`,
                'Content-Type': 'application/json'},
            body: JSON.stringify({email, password, email_confirm: true})
        });
        if (!response.ok) throw Error();
        const { id } = await response.json();
        if (!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id)) throw Error();
        if (app === 'mural') {
            statements.push(`insert into public.membros_mural values ('${id}', '${role}');`);
        } else if (app) {
            statements.push(`insert into public.perfis_usuarios values ('${id}', '${app}', 'Usuário fictício', '${role}', true);`);
            const operations = role === 'consulta' ? ['select'] : ['select', 'insert', 'update', 'delete'];
            for (const operation of operations) {
                statements.push(`insert into public.permissoes_usuarios values ('${id}', '${app}', '${operation}');`);
            }
        }
        users.push(`${label}\n${email}\n${password}`);
    }

    execFileSync('docker', ['exec', '-i', 'supabase_db_gerencial-2-homologacao-local',
        'psql', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'],
    {input: ['begin;', ...statements, 'commit;'].join('\n'), stdio: ['pipe', 'ignore', 'ignore']});
    fs.writeFileSync(credentials, users.join('\n\n') + '\n', {mode: 0o600, flag: 'wx'});
}

prepare().catch(() => {
    console.error('Falha na preparação das contas fictícias do Codespace.');
    process.exitCode = 1;
});
