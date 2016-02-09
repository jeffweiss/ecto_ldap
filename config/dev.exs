use Mix.Config

config :ecto, Ecto.Ldap.TestRepo,
       adapter: Ecto.Ldap.Adapter,
       hostname: "HOSTNAME_GOES_HERE",
       base: "BASE_GOES_HERE",
       port: 636,
       ssl: true,
       user_dn: "USER_DN_GOES_HERE",
       password: "PASSWORD_GOES_HERE",
       pool_size: 1
