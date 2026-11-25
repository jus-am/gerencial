# Gerencial 2.0 · homologação local

O portal e os aplicativos de Audiências e Controle Processual usam sessões próprias. O portal consulta a associação no mural. Os aplicativos consultam o perfil ativo e a permissão de leitura no respectivo escopo. O PostgreSQL também verifica as permissões por operação.

## Homologação na nuvem

A branch pode ser executada em GitHub Codespaces com o devcontainer do repositório. A inicialização sobe o Supabase em contêineres da máquina virtual, aplica o esquema de teste e cria contas fictícias. O ambiente encaminha apenas a porta 8080. Mantenha a porta com visibilidade privada. A página `/acessos-de-teste` apresenta as credenciais fictícias ao titular do Codespace. Nenhum dado ou credencial de produção é usado.

## Inicialização local alternativa

Requisitos do ambiente completo: Node.js, Supabase CLI com suporte a chaves publicáveis locais e Docker compatível. Use uma instância nova, com as portas 54321, 54322 e 8080 livres. O Windows utilizado na implementação não tinha Docker nem WSL instalado.

Na raiz desta cópia, inicie o Supabase e aplique o bootstrap somente no contêiner dedicado. O bootstrap exige uma marca de sessão, recusa tabelas existentes e executa o esquema dentro de uma transação.

```powershell
docker network create -o com.docker.network.bridge.host_binding_ipv4=127.0.0.1 gerencial-homologacao-local
supabase start --network-id gerencial-homologacao-local
node seguranca/preparar-banco-local.cjs | docker exec -i -e "PGOPTIONS=-c gerencial.homologacao_local=sim" supabase_db_gerencial-2-homologacao-local psql -U postgres -d postgres -v ON_ERROR_STOP=1
Copy-Item seguranca/config.local.example.js seguranca/config.local.js
node seguranca/servir-local.cjs
```

Preencha `seguranca/config.local.js` com a chave publicável local. O arquivo está no ignore do Git. No Studio local, crie usuários fictícios com senhas escolhidas para o teste. Use os UUIDs desses usuários para conceder acesso via SQL no Studio local. O exemplo usa um diretor do mural e um servidor de Audiências. Para Controle Processual use o escopo `controle_processual`.

```sql
insert into public.membros_mural (user_id, papel) values ('UUID-DO-DIRETOR', 'diretor');
insert into public.perfis_usuarios (user_id, aplicativo, nome, perfil, ativo)
values ('UUID-DO-SERVIDOR', 'audiencias', 'Servidor fictício', 'servidor', true);
insert into public.permissoes_usuarios (user_id, aplicativo, operacao)
select 'UUID-DO-SERVIDOR'::uuid, 'audiencias', operacao
from unnest(array['select','insert','update','delete']) as p(operacao);
```

Rotas locais: [Gerencial](http://127.0.0.1:8080/), [Audiências](http://127.0.0.1:8080/audiencias/) e [Controle Processual](http://127.0.0.1:8080/controle-processual/). O servidor aceita apenas conexões locais e serve uma lista explícita de arquivos. O navegador também valida a origem local do aplicativo e do Supabase.

## Verificação

```powershell
npm.cmd install --prefix .test-runtime --no-save --no-package-lock @electric-sql/pglite@0.3.14
node --test seguranca/verificar-local.cjs
```

O PostgreSQL embarcado executa as políticas com tabelas descartáveis e identidades fictícias. As funções de Auth usam fixtures. Execute o roteiro abaixo em um Supabase local iniciado para validar GoTrue, PostgREST, Realtime e navegador.

- Entrar diretamente em cada aplicativo com um usuário autorizado apenas nele. Testar conta sem perfil, perfis suspensos, consulta, autenticação anônima, autocadastro, renovação, expiração, saída e troca de conta em abas simultâneas. Repetir as operações sensíveis pela API.
- Criar, editar, fixar, expirar, arquivar e excluir logicamente um aviso. Conferir leitura e histórico em cada perfil.
- Criar lote de horários, preencher e editar audiência, testar cadastros e inativação de salas. Conferir relatórios, exportações e concorrência em duas abas. Interromper a rede durante gravação e verificar os campos e o retorno.
- Criar, editar e excluir processos antigos e cartas precatórias. Repetir com a conta de consulta e com a rede interrompida. Conferir filtros, indicadores, paginação e exportações.
- Verificar comportamento em desktop e celular, navegação pelos sete atalhos e pelos 25 cartões, mensagens da interface e console.

## Produção e dados legados

A consulta em 25/11/2026 identificou o projeto Supabase de produção em `sa-east-1`, PostgreSQL `17.11.0.003`, com políticas amplas nas seis tabelas de Audiências e Controle Processual e duas políticas amplas em `tempo_apn`. As políticas específicas do mural foram identificadas por consulta de catálogo. A cópia local do repositório independente `jus-am/controle-processual` contém cinco referências operacionais a `tempo_apn` em `tempo-apn.js`. Confirme o código publicado desse aplicativo antes de uma futura mudança de política.

O seed legado foi retirado da versão corrente de homologação. O histórico público ainda deve passar por avaliação institucional de exposição, incluindo código, seeds e artefatos publicados. Classifique a origem dos registros com os responsáveis, restrinja o acesso ao inventário e registre somente contagens e resultados agregados. Cache antigo deve ser avaliado no dispositivo autorizado para identificar alterações sem sincronização antes de qualquer limpeza. O inventário da ordem de implementação é histórico.

## Implantação futura

1. Obter autorização expressa e confirmar dependências, responsáveis e janela de mudança. Verificar a configuração autenticada do Pages e registrar SHA, artefato, opções de Auth, políticas e privilégios atuais.
2. Gerar backup autorizado em armazenamento institucional restrito, registrar checksum e validar a restauração em instância segregada com acesso controlado. Para homologação funcional use uma base exclusivamente fictícia.
3. Aprovar migração e reversão específicas de produção a partir do catálogo vigente. Validar a restauração, grants, RLS, funções, views, sequences, convites e compatibilidade do Tempo APN. `rascunho_rls.sql` termina em `ROLLBACK`; o bootstrap é exclusivo da homologação.
4. Provisionar permissões por aplicativo, validar em ambiente isolado e coordenar publicação do cliente com a troca de políticas. Verificar login, leitura, escrita, auditoria e ausência de acesso cruzado.
5. Se houver regressão, interromper a publicação, restaurar o artefato anterior e aplicar a reversão de políticas e privilégios aprovada. Usar restauração de dados somente após avaliar gravações legítimas ocorridas durante a janela. Sanear registros ou histórico público somente com autorização específica.

Ainda pendentes: execução no Supabase completo, testes de navegador e API, administração de usuários e recuperação na interface, auditoria geral, revisão completa de XSS, consistência concorrente de lotes e confirmação das dependências externas. O procedimento de backup e restauração em produção depende de autorização específica.
