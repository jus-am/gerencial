(() => {
    'use strict';

    window.criarClienteHomologacao = (storageKey) => {
        const config = window.GERENCIAL_HOMOLOGACAO;
        const endpoint = new URL(config?.url ?? 'about:blank');
        const localHosts = ['localhost', '127.0.0.1', '[::1]'];
        const isLocal = localHosts.includes(location.hostname) &&
            localHosts.includes(endpoint.hostname) && ['http:', 'https:'].includes(endpoint.protocol);
        const isCodespace = endpoint.protocol === 'https:' && endpoint.origin === location.origin &&
            /^[a-z0-9-]+-8080\.app\.github\.dev$/.test(endpoint.hostname);
        const isProduction = location.origin === 'https://jus-am.github.io' &&
            location.pathname.startsWith('/gerencial/') &&
            endpoint.origin === 'https://qcvietuczbysditpkopr.supabase.co';
        if ((!isLocal && !isCodespace && !isProduction) ||
            endpoint.href !== endpoint.origin + '/' ||
            typeof config?.publishableKey !== 'string' ||
            !/^sb_publishable_[\w-]+$/.test(config.publishableKey)) {
            throw new Error('Configuração local de homologação indisponível.');
        }
        return window.supabase.createClient(endpoint.origin, config.publishableKey, {
            auth: { storageKey }
        });
    };

    window.exigirLeituraAplicativo = async (client, userId, app) => {
        const [profile, grant] = await Promise.all([
            client.from('perfis_usuarios').select('ativo').eq('user_id', userId).eq('aplicativo', app).single(),
            client.from('permissoes_usuarios').select('operacao').eq('user_id', userId)
                .eq('aplicativo', app).eq('operacao', 'select').single()
        ]);
        if (profile.error || grant.error || !profile.data?.ativo || !grant.data) {
            throw new Error('Acesso indisponível.');
        }
    };

    window.lerTabelaPaginada = async (client, table) => {
        const records = [];
        const pageSize = 500;
        for (let start = 0; ; start += pageSize) {
            const { data, error } = await client.from(table).select('*').order('id')
                .range(start, start + pageSize - 1);
            if (error || !data) throw new Error('Carregamento indisponível.');
            records.push(...data);
            if (data.length < pageSize) return records;
        }
    };
})();
