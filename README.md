# EctoLdap

**Ecto Adapter for LDAP**

## TODO
1. Implement attribute updates
2. Implement connection pool upon adapter startup


## Installation

If [available in Hex](https://hex.pm/docs/publish) (currently unavailable), the package can be installed as:

  1. Add ecto_ldap to your list of dependencies in `mix.exs`:

        def deps do
          [{:ecto_ldap, "~> 0.1.6"}]
        end

  2. Ensure ecto_ldap is started before your application:

        def application do
          [applications: [:ecto_ldap]]
        end

  3. Specify Ecto.Ldap.Adapter as the adapter for your application's Repo:

        config :my_app, MyApp.Repo,
          adapter: Ecto.Ldap.Adapter,
          hostname: "ldap.example.com",
          base: "dc=example,dc=com",
          port: 636,
          ssl: true,
          user_dn: "uid=sample_user,ou=users,dc=example,dc=com",
          password: "password",
          pool_size: 1

