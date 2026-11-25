const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(path.join(process.env.RUNNER_TEMP, 'gerencial-browser/node_modules/playwright'));

const origin = 'http://127.0.0.1:8080';
const identity = JSON.parse(fs.readFileSync(path.join(process.env.RUNNER_TEMP, 'gerencial-browser-identity.json'), 'utf8'));

async function logIn(page, route) {
    await page.goto(origin + route);
    await page.locator('#auth-email').fill(identity.email);
    await page.locator('#auth-password').fill(identity.password);
    await page.locator('#auth-overlay button').click();
    await page.locator('#app-content').waitFor({state: 'visible'});
}

(async () => {
    const browser = await chromium.launch();
    try {
        const context = await browser.newContext();
        await context.route('https://qcvietuczbysditpkopr.supabase.co/**', route => route.abort());
        const portal = await context.newPage();
        await portal.goto(origin);
        await portal.locator('#mural-login [name=email]').fill(identity.email);
        await portal.locator('#mural-login [name=senha]').fill(identity.password);
        await portal.locator('#mural-login button').click();
        await portal.locator('#portal-content').waitFor({state:'visible'});
        await portal.locator('#mural-novo').click();
        await portal.locator('#mural-form [name=titulo]').fill('Aviso de integração fictício');
        await portal.locator('#mural-form [name=conteudo]').fill('Registro descartável');
        await portal.locator('#mural-form').getByRole('button',{name:'Salvar aviso'}).click();
        await portal.locator('#mural-lista').getByText('Aviso de integração fictício').waitFor();
        console.log('OK: autenticação e gravação de aviso pelo Gerencial');
        const agenda = await context.newPage();
        await logIn(agenda, '/audiencias/');
        const controle = await context.newPage();
        await logIn(controle, '/controle-processual/');
        await controle.getByRole('button',{name:'Novo Processo'}).click();
        await controle.locator('#pi-processo').fill('EXEMPLO-BROWSER');
        await controle.locator('#modal-idoso').getByRole('button',{name:'Salvar'}).click();
        await controle.getByText('EXEMPLO-BROWSER',{exact:true}).waitFor();
        await controle.reload();
        await controle.getByText('EXEMPLO-BROWSER',{exact:true}).waitFor();
        console.log('OK: acesso direto e persistência confirmada após recarregar');
        await agenda.locator('.btn-logout').click();
        await agenda.locator('#auth-overlay').waitFor({state:'visible'});
        await controle.reload();
        await controle.getByText('EXEMPLO-BROWSER',{exact:true}).waitFor();
        await portal.reload();
        await portal.locator('#mural-lista').getByText('Aviso de integração fictício').waitFor();
        assert.equal(await agenda.locator('#app-content').isVisible(), false);
        console.log('OK: encerrar sessão em Audiências mantém Mural e Controle autenticados');
    } finally {
        await browser.close();
    }
})().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
});
