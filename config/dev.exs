use Mix.Config

config :ecto, Ecto.Ldap.TestRepo,
  adapter: Ecto.Ldap.Adapter,
  hostname: "ldap.example.com",
  base: "dc=example,dc=com",
  port: 636,
  ssl: true,
  user_dn: "uid=sample_user,ou=users,dc=example,dc=com",
  password: "password",
  pool_size: 1
