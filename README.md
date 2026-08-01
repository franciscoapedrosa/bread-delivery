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
