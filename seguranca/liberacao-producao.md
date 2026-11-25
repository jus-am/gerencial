# Liberação do Gerencial 2.0

## Estado confirmado em 25/11/2026

- A visualização aprovada está em https://60197ecc.gerencial-bc-demonstracao.pages.dev/. O CSS e a fonte Inter do cabeçalho coincidem com a produção.
- A referência de produção registrada é `4633de8bbe44092a82cd640cb49c7afe7580224f`. A configuração atual da publicação deve ser registrada com acesso administrativo antes da janela.
- Consulta de catálogo e contagens em modo somente leitura: quatro contas Auth, um acesso ao mural, seis políticas nas seis tabelas dos módulos e duas políticas em `tempo_apn`. Não existem ainda as tabelas de perfis e permissões por aplicativo. As contagens não conferem autorização a uma conta.
- O teste de integração da API está em https://github.com/jus-am/gerencial/actions/runs/45703383699. Usou Auth, PostgREST e PostgreSQL descartáveis com contas fictícias.

## Ordem da mudança

1. Obter autorização explícita para a migração e aprovar a lista de contas, aplicativos, perfis e operações. Obter autorização de backup e confirmar a janela.
2. Registrar o artefato de produção e exportar, para armazenamento institucional restrito, esquema, políticas, grants, parâmetros Auth e backup autorizado. Verificar checksum e restauração segregada.
3. Preparar a migração final para Audiências e Controle Processual a partir da consulta de catálogo vigente. O rascunho de homologação inclui `tempo_apn`; a troca de políticas dessa tabela depende de confirmar e validar o cliente externo. Manter as políticas do mural durante a transição.
4. Criar as tabelas de autorização e provisionar as permissões aprovadas antes de ativar as novas regras, com confirmação de acesso por aplicativo. Validar também criação e recuperação de contas, concorrência de gravações, Realtime e reversão.
5. Preparar o cliente para o hostname oficial e a chave publicável do projeto autorizado. Os clientes atuais de homologação aceitam exclusivamente loopback ou o domínio do Codespace. Preservar o HTML e as folhas de estilo aprovadas no portal.
6. Validar cliente e políticas juntos com dados fictícios. Durante a janela, aplicar a migração aprovada e publicar o cliente compatível. Verificar acesso, persistência, mural, auditoria, endereço oficial e funcionamento do Tempo APN.
7. Se ocorrer regressão, reverter regras e grants a partir da captura anterior, restaurar o artefato anterior e conferir os acessos. Avaliar transações ocorridas durante a janela antes de qualquer restauração de dados.

O SQL de rascunho termina em ROLLBACK. Este documento registra as dependências e a ordem da futura mudança.
