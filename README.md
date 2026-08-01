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
