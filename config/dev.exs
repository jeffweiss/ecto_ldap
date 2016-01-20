use Mix.Config

config :ecto, Ecto.Ldap.TestRepo,
       adapter: Ecto.Ldap.Adapter,
       url: "ldap+ssl://ldap.puppetlabs.com/dc=com,dc=puppetlabs,ou=users"
