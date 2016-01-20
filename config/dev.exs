use Mix.Config

config :ecto, Ecto.Ldap.TestRepo,
       adapter: Ecto.Ldap.Adapter,
       url: "ldap+ssl://ldap.puppetlabs.com/dc=com,dc=puppetlabs,ou=users",
       pool_size: 1

config :exldap, :settings,
       server: "LDAP Server goes here",
       base: "dc=puppetlabs,dc=com",
       port: 636,
       ssl: true,
       user_dn: "user_goes_here",
       password: "password_goes_here"
