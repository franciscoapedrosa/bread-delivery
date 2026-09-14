# Bread Delivery

Aplicação Rails para gerir clientes, rotas e entregas semanais de pão.

## Requisitos

- Ruby 3.4.4
- SQLite 3
- Bundler 2.6.7

## Preparação

```sh
bin/setup
bin/rails db:seed
```

## Executar

```sh
bin/rails server
```

A aplicação fica disponível em <http://localhost:3000>.

As contas de demonstração criadas por `db:seed` usam a palavra-passe definida
em `SEED_PASSWORD` ou, apenas em desenvolvimento, `password123`.

## Testes e qualidade

```sh
bin/rails test
bin/rubocop
bin/brakeman
```

## Papéis

- **Admin:** gere utilizadores, clientes, rotas e entregas e consulta totais.
- **Distributor:** consulta apenas os seus clientes, rotas e entregas e atualiza
  o estado das entregas que lhe estão atribuídas.
- **Cliente:** pede pão apenas para as datas marcadas pelo administrador e consulta a aprovação.

## Planeamento por rotas e pedidos de pão

1. Em **Utilizadores**, criar uma conta com função Cliente, nome e morada completa.
   Também é possível associar a conta a um cliente antigo ainda sem utilizador.
2. Em **Rotas → Clientes e percurso**, adicionar os clientes e indicar a ordem.
3. Em **Entregas → Marcar dia de entrega**, escolher rota, data, distribuidor e ordem da rota no dia.
   Cada marcação tem uma data concreta; não se repete automaticamente na semana seguinte.
4. O cliente entra em **O meu pão** e envia a quantidade até às 23h do dia anterior, em Europe/Lisbon.
   Pode pedir zero. Uma alteração antes do prazo volta a exigir aprovação.
5. O administrador aprova ou recusa em **Pedidos de pão**. Só pão aprovado de entregas não canceladas entra nos totais.
6. O distribuidor abre **As minhas rotas**, segue os pontos numerados e guarda o estado de cada entrega.

O percurso e a morada ficam guardados na marcação, para alterações futuras à rota não mudarem
entregas já planeadas. O administrador pode editar a morada e ordem de um ponto na própria entrega.
As entregas antigas continuam consultáveis em **Consultar entregas do sistema anterior**.
A migração conserva as associações antigas entre clientes e rotas, mas não inventa datas para elas.

Depois de atualizar o código, executar `bin/rails db:migrate` e reiniciar o servidor.
Se os estilos locais parecerem antigos, verificar se existem ficheiros pré-compilados em `public/assets`.

### Demonstração local opcional

```sh
bin/rails runner db/planning_demo.rb
```

Cria uma rota com dois clientes para amanhã, um pedido aprovado e outro por aprovar.
Só funciona em desenvolvimento. Contas `cliente.demo@example.com` e
`distribuidor.demo@example.com`, palavra-passe `pao-local-2026`.
Este script não é executado na publicação e não altera as palavras-passe de contas existentes.

O botão de direções usa os formatos oficiais de [Google Maps](https://developers.google.com/maps/documentation/urls/get-started),
[Apple Maps](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html)
e [Waze](https://developers.google.com/waze/deeplinks). A navegação depende da aplicação instalada e da morada reconhecida pelo serviço.

Veículos e contas de padeiro ficam para a fase seguinte.

## Publicação gratuita

O projeto inclui um `render.yaml` e `bin/render-build.sh` para publicação de um
serviço gratuito no Render, ligado a uma base de dados PostgreSQL Neon.

No Render, configure estas variáveis sem as guardar no repositório:

- `DATABASE_URL`: connection string fornecida pelo Neon.
- `RAILS_MASTER_KEY`: conteúdo local de `config/master.key`.
- `SEED_PASSWORD`: password inicial das contas de demonstração.
- `APP_HOST`: domínio do serviço, sem `https://`.

O serviço gratuito adormece quando não recebe visitas. A primeira página depois
desse período pode demorar aproximadamente um minuto a carregar.
