# Preparação da versão de segurança — Render / Neon

Estado em 22/09/2026: **utilizador pediu para avançar com deploy; publicação ainda não executada, janela de interrupção por confirmar**.

## Verificação de produção antes da publicação

- Utilizador forneceu privadamente os valores atuais do Render em `.env.security-production` (ignorado pelo Git, modo 0600).
- Chave Render decifra o artefacto `config/data_encryption.yml.enc`; não foi necessário trocar ou regenerar chaves.
- Ligação fornecida confirmada apenas em transação READ ONLY: TLS ativo, PostgreSQL 18.6, `neondb`, `neondb_owner`, endpoint `ep-silent-recipe-zas4nfjp-pooler.c-2.eu-west-2.aws.neon.tech`.
- Dez migrações pendentes, iguais às ensaiadas; role `bread_app` ainda não existe nesta base. Nenhuma alteração de produção executada.
- `origin/main` atualizado por fetch e é antepassado da versão local; sem divergência remota a sobrescrever.
- Antes da migração: interromper escritas da versão antiga, obter backup atual, criar conta restrita e coordenar a alteração de DATABASE_URL no Render. A mudança de credencial no painel requer intervenção do utilizador.

## Confirmado localmente

- Branch de trabalho: `develop`; último commit de base: `f1ffebc`. A versão inclui alterações funcionais anteriores e segurança, ainda sem commit.
- `render.yaml` declara agora `autoDeployTrigger: "off"`, plano `free`, build `bin/render-build.sh` e health check `/up`. A alteração foi alinhada com o painel após autorização.
- O build não executa migrações sem `RUN_DATABASE_MIGRATIONS=1`. A conta administrativa deve ficar apenas no processo isolado de migração, nunca no serviço web.
- `config/master.key` e o backup SQLite encriptado estão ignorados pelo Git. `config/data_encryption.yml.enc` é um artefacto encriptado que precisa de ser incluído na versão, ou substituído em produção pelo conjunto completo das três variáveis de chaves.
- Nenhuma credencial foi regenerada. O snapshot remoto e a branch de testes criados posteriormente estão registados abaixo; não foi criada conta de base de dados ou serviço Render.

## Consulta dos painéis após login — 22/09/2026

O utilizador iniciou sessão. Consulta efetuada apenas em leitura, sem revelar/copiar valores de segredos:

- Render: serviço `bread-delivery`, ID `srv-d9mtkodaeets73ap9s10`, Free, Frankfurt, gerido por Blueprint. Repositório `franciscoapedrosa/bread-delivery`, branch **main** (diferente da branch local `develop`). Commit publicado `a3d65d8b452bd89073d25ac754ac2b558e021c96`; a lista consultada mostrava quatro deploys concluídos, sem execução pendente visível.
- Auto-Deploy na consulta inicial: **On Commit**, posteriormente alterado para **Off** com autorização. Build `bin/render-build.sh`, start `bin/rails server -b 0.0.0.0`, health check `/up`. Pre-deploy e manutenção integrada indisponíveis no plano atual.
- Variáveis visíveis no Render: `APP_HOST`, `DATABASE_URL`, `RAILS_LOG_TO_STDOUT`, `RAILS_MASTER_KEY`, `RAILS_MAX_THREADS`, `SEED_PASSWORD`, `WEB_CONCURRENCY`. As três variáveis `ACTIVE_RECORD_ENCRYPTION_*` não aparecem. Não foram verificados valores, equivalência da master key com a local, nem eventual configuração via Rails credentials. Nenhum grupo de variáveis ligado visível.
- Neon: projeto `Bread Delivery` (`ancient-recipe-90602954`), Free, Londres. Apenas uma branch: `production` (`br-polished-frog-za2ecud7`), PostgreSQL **18**. O ensaio PostgreSQL anterior foi feito em versão 17; acrescentar validação em 18 antes de publicar.
- O painel da branch indicava estado arquivado por inatividade desde 15/09/2026, com reativação automática por consulta. Não foram executadas queries nem aberta a aplicação pública para a reativar deliberadamente.
- Roles visíveis: apenas `neondb_owner`, proprietário de `neondb`. `bread_app` ainda não aparece. Sem leitura do segredo `DATABASE_URL`, não se confirmou qual a conta/base usada efetivamente pelo Render.
- Backup & Restore na consulta inicial: histórico de **6 horas**, nenhum snapshot nem agendamento. O primeiro snapshot foi posteriormente criado conforme o registo abaixo; ainda falta testar a recuperação antes de migrar.

**Alteração autorizada e concluída:** Auto-Deploy do serviço Render acima alterado de On Commit para **Off**, com gravação terminada e valor confirmado no painel. `render.yaml` local alinhado com `off`, ainda sem commit/push, para não reintroduzir a configuração anterior numa futura sincronização do Blueprint.

## Backup remoto — 22/09/2026

- Após o utilizador indicar para avançar com backup/ambiente de testes, o botão Create em Backup & Restore criou imediatamente um snapshot, sem formulário intermédio. O painel confirmou sucesso.
- Nome apresentado: `production at 2026-09-22 10:52:09 UTC (manual)`; origem `production`; expiração apresentada: **never**. O painel passou a mostrar um snapshot, sem agendamento. Não foram substituídos dados nem alteradas ligações da aplicação.
- O snapshot contém os dados reais existentes nessa data, incluindo dados pessoais no estado anterior à migração. Não confundir com uma exportação independente do fornecedor nem com recuperação já ensaiada.
- O plano atual permite um snapshot manual; a interface agora pede upgrade para mais snapshots. Não foi aceite nenhum upgrade. Antes do deploy efetivo, avaliar a atualidade deste backup e obter autorização para qualquer substituição; não apagar o único backup de segurança por rotina.
- O menu oferece **Multi-step restore**, que cria uma nova branch a partir do snapshot, e **One-step restore**, que substitui a branch mantendo nome/ligação. Não usar One-step restore para o ensaio.
- A recuperação numa branch separada foi posteriormente autorizada e executada conforme o registo seguinte. Nenhum deploy, push, mudança de variável, criação de role ou migração da aplicação foi executado.

## Branch de testes restaurada — 22/09/2026

- Com autorização explícita do utilizador, executado **Multi-step restore** a partir do snapshot de 10:52:09 UTC. A confirmação do Neon indicou que `production` permaneceria inalterada; o painel devolveu `Snapshot was successfully restored`.
- Branch criada: **`security-test-2026-09-22`**, ID **`br-purple-night-zap4uosc`**, no projeto `ancient-recipe-90602954`. O nome automático foi alterado para identificar claramente o ambiente de testes. Criação indicada pelo painel: 22/09/2026 às 11:56:28, hora de Lisboa; PostgreSQL 18; sem expiração indicada.
- A lista de branches confirma a coexistência de `production` (Default, ID original `br-polished-frog-za2ecud7`) e da cópia de testes. O contador do cabeçalho ainda mostrava 1, embora ambas as linhas estivessem presentes.
- **Não** utilizada a opção `Migrate connections and settings`; não alterados DATABASE_URL, Render, branch default, acessos, passwords ou plano. O projeto permanece no Free. A cópia usa os recursos incluídos do projeto, pelo que os testes devem respeitar as quotas partilhadas.
- A criação/restauração ao nível do Neon está confirmada; a leitura dos dados, integridade, execução das migrações e validação da aplicação/RLS nesta cópia **ainda não foram realizadas**. Não declarar recuperação funcional completa apenas com a mensagem de sucesso do fornecedor.
- **Paragem atual:** preparar ligação segura e conta restrita exclusivamente na branch de testes, com aprovação antes de criar credenciais/permissões ou executar migrações. A nova branch contém dados reais anteriores à migração; não expor publicamente nem ativar emails/jobs externos durante ensaios.

### Ligação local para o ensaio

- No diálogo de conexão da branch de testes, foi selecionada a ligação direta (pooling desativado apenas na apresentação do snippet). Host observado: `ep-silent-butterfly-za3t0sy6.c-2.eu-west-2.aws.neon.tech`; base `neondb`; role `neondb_owner`. Nenhuma password revelada ou alterada.
- Preparado `.env.security-staging`, ignorado pelo Git e com permissões 0600, com `STAGING_DATABASE_URL` vazio para preenchimento privado pelo utilizador. Não executar o ficheiro como shell nem imprimir o seu conteúdo após preenchimento.
- Antes de qualquer ligação, validar o hostname exato acima, base, utilizador e TLS. Nunca usar esta cópia com `RAILS_ENV=test`/fixtures ou `db:reset`. Não confundir a variável privada com autorização para migrar produção.
- Para reduzir consumo, não repetir a suite SQLite já aprovada: concentrar o próximo ensaio na compatibilidade PostgreSQL 18, migrações e isolamento por conta restrita na cópia. A ligação ainda não foi efetuada.

## Acesso e restantes verificações

Login já efetuado pelo utilizador. Continuar sem enviar palavras-passe, tokens ou URLs com credenciais na conversa.

Na continuação, completar os itens ainda não confirmados **sem guardar alterações**:

- Serviço Render correto, repositório/branch ligados, commit ativo, plano, comandos de build/start/pre-deploy, auto-deploy efetivo e eventuais deploys pendentes.
- Projeto/base/branch Neon usados pelo serviço, versão PostgreSQL, conta atual e permissões, capacidade/janela de recuperação e isolamento do ambiente de testes.
- Existência (sem revelar valores) das chaves de encriptação e compatibilidade com o artefacto da versão. Confirmar cópia de recuperação das chaves fora do repositório.
- Configuração efetiva de envio de emails para validar recuperação de conta. O ficheiro local não configura SMTP; não assumir entrega de emails em produção.

## Aprovações e próximos passos

**Auto-deploy já desativado com autorização.** Não fazer push sem rever o destino e os gatilhos do Blueprint; editar apenas o YAML local não alteraria a configuração já ativa.

Os passos seguintes também exigem autorização antes de serem executados:

1. Criar ambiente/branch de testes isolado e backup recuperável da base de produção. Uma branch que copie dados reais também contém dados pessoais; confirmar acessos, retenção e eventuais custos.
2. Criar a conta restrita `bread_app` com `NOSUPERUSER NOBYPASSRLS NOINHERIT`, sem propriedade ou pertença à conta proprietária. Definir credenciais em privado e verificar permissões efetivas; o nome da conta, por si só, não garante isolamento.
3. Disponibilizar as mesmas chaves de dados ao processo de migração e ao runtime da versão. Não regenerar chaves se já existirem dados encriptados.
4. Escolher executor isolado para migrações. **Render Free não suporta one-off jobs**: não assumir que o job descrito em `SECURITY.md` pode correr nesse serviço. Usar um processo local supervisionado ou runner isolado autorizado, ou aprovar outro serviço/plano; nunca colocar a conta proprietária no web runtime para contornar esta limitação.
5. Ensaiar migração e recuperação no ambiente isolado. Não executar `db:reset`, `db:schema:load` ou testes com fixtures sobre produção. Os testes automáticos destrutivos de preparação de schema usam apenas uma base explicitamente descartável.
6. Rever a versão completa, guardar commit e validar CI sem publicar produção. Fazer push apenas depois de verificar os gatilhos e autorizar o destino.
7. Aprovar janela de manutenção: parar escritas/instâncias antigas, confirmar backup e chaves, executar migrações com proprietário e iniciar a nova versão com a conta restrita. Não misturar instâncias antigas que esperam texto simples com a base já encriptada.
8. Validar login, bloqueio/recuperação, cada perfil, pedidos/aprovação/entrega e RLS com a conta restrita. Manter rollback planeado: repor só código antigo não desfaz a migração de dados; a recuperação exige backup, chaves e versão compatíveis.

## Evidência e limites

- Decisão do utilizador: avançar sem serviço de email nesta versão; recuperação assistida pelo administrador em Utilizadores → Editar. O login indica para contactar o administrador, sem link de recuperação por email. Os endpoints de recuperação existentes não foram removidos. Envio SMTP não é condição para esta versão, mas não deve ser anunciado como funcional. Confirmar acesso do administrador e conservar um procedimento técnico para recuperar a própria conta administrativa.

### Continuação do ensaio Neon — 22/09/2026

Este registo substitui as indicações anteriores de ligação/migração ainda pendentes na branch de testes; não altera o estado de produção.

- Conta `bread_app` criada exclusivamente na branch `security-test-2026-09-22`, com credencial local ignorada pelo Git e permissões 0600.
- Migração concluída com sucesso: dez migrações, incluindo duas anteriores de planeamento de rotas/veículos que também faltavam na cópia.
- `bin/verify-security-staging` executado com `RAILS_ENV=production` e conta restrita: TLS confirmado pelo cliente PostgreSQL, verificação de privilégios aprovada e RLS nas dez tabelas. Sem contexto, users/customers/routes não devolvem registos; contexto restaurado após leitura autorizada.
- Quatro emails e dez campos de clientes confirmados encriptados e decifrados com sucesso; hashes de passwords bcrypt. A cópia não tinha campos de ScheduledStop para validar, pelo que esse backfill não ficou exercitado com dados reais.
- Formulário de login respondeu 200; `/customers` JSON sem autenticação respondeu 401. Envio de email desativado durante esta verificação. Sem alterações aos registos.
- Ensaio autenticado `bin/verify-security-staging-flows` concluído no Neon com conta restrita, configuração de produção e CSRF ativo: login de cliente/admin/distribuidor/padeiro; isolamento do cliente; recusa 403 de gestão de utilizadores aos perfis não autorizados; aprovação de 8 pães e marcação como entregue; consulta de produção pelo padeiro; bloqueio após cinco passwords erradas; recuperação por token e nova password; rate limit HTTP 429 com Retry-After 900. Emails capturados apenas em memória, sem SMTP. Todos os registos/alterações do ensaio revertidos numa transação (sequências PostgreSQL podem avançar).
- Limites deste ensaio: quantidade inicial criada pelo setup, não submetida pelo formulário do cliente; nenhum envio real de email; não é um teste de concorrência ou da infraestrutura Render. Não usar este script contra produção.
- Produção continua sem migração ou deploy. Compatibilidade da chave Render, recuperação das chaves e configuração de email continuam por confirmar.

- Nova passagem local: 95 testes, 457 asserções, sem falhas/erros; 10 testes PostgreSQL omitidos nesta execução SQLite. A validação PostgreSQL anterior está descrita em `SECURITY.md`; isto não equivale a testar Neon.
- Brakeman: zero alertas e zero erros. Não constitui garantia de ausência de vulnerabilidades.
- Problemas locais de estilo foram corrigidos mecanicamente. Verificação final RuboCop: 104 ficheiros, zero infrações; `git diff --check` sem erros. Testes repetidos após as correções com o mesmo resultado acima.
- As configurações remotas observadas estão registadas acima. Compatibilidade das chaves, conexão efetiva/conta/TLS, recuperação testada do backup e envio real de email continuam **por confirmar**.

Referências: [deploys Render](https://render.com/docs/deploys), [limites do Render Free](https://render.com/docs/free), [implementação e migração](SECURITY.md).
