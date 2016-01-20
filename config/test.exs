use Mix.Config

config :ecto,
       adapter: Ecto.Ldap.Adapter,
       url: "ldap+ssl://ldap.puppetlabs.com/dc=com,dc=puppetlabs,ou=users",
       pool_size: 1
