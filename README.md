# EctoLdap

**Ecto Adapter for LDAP**

## TODO
1.  Implement connection pool upon adapter startup
2.  Remove all hardcoding in favor of configuration
3.  Migrate existing `eldap` wrapper into EctoLdap to remove dependency on `:exldap`


## Installation

If [available in Hex](https://hex.pm/docs/publish) (currently unavailable), the package can be installed as:

  1. Add ecto_ldap to your list of dependencies in `mix.exs`:

        def deps do
          [{:ecto_ldap, "~> 0.0.1"}]
        end

  2. Ensure ecto_ldap is started before your application:

        def application do
          [applications: [:ecto_ldap]]
        end
