const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');

const html = 'text/html; charset=utf-8';
const js = 'text/javascript; charset=utf-8';
const routes = new Map([
    ['/', ['index.html', html]],
    ['/index.html', ['index.html', html]],
    ['/audiencias/', ['audiencias/index.html', html]],
    ['/audiencias/index.html', ['audiencias/index.html', html]],
    ['/controle-processual/', ['controle-processual/index.html', html]],
    ['/controle-processual/index.html', ['controle-processual/index.html', html]],
    ['/homologacao/', ['homologacao/index.html', html]],
    ['/homologacao/index.html', ['homologacao/index.html', html]],
    ['/logo.png', ['logo.png', 'image/png']],
    ['/manifest.json', ['manifest.json', 'application/json']],
    ['/seguranca/config.local.js', ['seguranca/config.local.js', js]],
    ['/seguranca/cliente-homologacao.js', ['seguranca/cliente-homologacao.js', js]]
]);

const address = '127.0.0.1';
const codespace = process.env.CODESPACES === 'true' && process.argv.includes('--codespace');
const port = codespace ? 8081 : 8080;
if (codespace) routes.set('/acessos-de-teste', ['seguranca/acessos-codespace.txt', 'text/plain; charset=utf-8']);
const server = http.createServer(async (request, response) => {
    if (request.headers.host !== `${address}:${server.address().port}`) {
        return response.writeHead(421).end();
    }
    if (!['GET', 'HEAD'].includes(request.method)) {
        return response.writeHead(405, {Allow: 'GET, HEAD'}).end();
    }
    const route = routes.get(request.url.split('?')[0]);
    if (!route) return response.writeHead(404).end();
    const [file, contentType] = route;
    let content;
    try {
        content = await fs.readFile(path.join(__dirname, '..', file));
    } catch {
        return response.writeHead(404).end();
    }
    response.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff'
    });
    response.end(request.method === 'HEAD' ? undefined : content);
});

if (require.main === module) {
    server.listen(port, address, () => {
        console.log(`Interface local em http://${address}:${port}/`);
    });
}

module.exports = server;
