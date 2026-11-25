# Segurança — Benjamin Constant (rascunho)
Uso exclusivo da Vara Única. Não executar SQL em produção. Inventário: 1473 registros legados e 11 do mural. Classificar origem e validar backup antes de qualquer saneamento. Não copiar dados reais para testes.
## Sequência
1. Validar backup/restauração e autorização institucional. Identificar dependências externas de tempo_apn.
2. Remover seeds e autocadastro dos clientes; revisar caches, XSS, IDs e exclusões. Revisar histórico público sem reescrita não autorizada.
3. Testar políticas em Postgres isolado com fixtures fictícias. O SQL proposto termina em rollback e não constitui migração final.
4. Preparar configurações, auditoria e convites server-side; integrar membros_mural sem regressão. Bloquear cadastro público no Auth após validar convites.
5. Validar classificação dos registros; manter antigos inacessíveis até destinação autorizada. Não excluir registros.
6. Homologar clientes e migração juntos; aprovar janela e reversão antes de produção.
## Testes
Anônimo e autenticado sem perfil: negar leitura/escrita. Consulta: somente SELECT autorizado. Servidor: operações concedidas por app. Suspenso: negar todas. Administrador: acesso autorizado. Testar API direta, Realtime, troca de conta, seeds, concorrência, convites e recuperação. Confirmar ausência de políticas permissivas adicionais e privilégios de sequência necessários. Não liberar equipe antes dos testes.

## Diretriz obrigatória: autonomia dos aplicativos
Gerencial é portal de atalhos e mural. Não é provedor obrigatório de autenticação nem controlador funcional dos aplicativos. Cada aplicativo mantém endereço, sessão, interface e autorização próprios; compartilhar Supabase não implica compartilhar permissões. O perfil administrativo do portal não concede acesso automático a Audiências, Controle Processual ou Tempo APN. A autorização de cada módulo deve ser explícita e administrada no respectivo escopo. Não modificar Firebase ou outros repositórios nesta etapa. O rascunho RLS anterior precisa ser revisado para retirar o bypass global do administrador e não depender de membros_mural para conceder acesso aos módulos. Testar acesso direto aos aplicativos com portal indisponível, saída independente, e usuário exclusivamente do mural sem acesso a dados processuais.
