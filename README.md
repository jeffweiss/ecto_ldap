# EctoLdap
[![Build Status](https://travis-ci.org/jeffweiss/ecto_ldap.svg?branch=master)](https://travis-ci.org/jeffweiss/ecto_ldap)
[![Hex.pm Version](http://img.shields.io/hexpm/v/ecto_ldap.svg?style=flat)](https://hex.pm/packages/ecto_ldap)
[![Coverage Status](https://coveralls.io/repos/github/jeffweiss/ecto_ldap/badge.svg?branch=master)](https://coveralls.io/github/jeffweiss/ecto_ldap?branch=master)

**Ecto Adapter for LDAP**

## Installation

[From Hex](https://hex.pm/docs/publish), the package can be installed as follows:

  1. Add ecto_ldap to your list of dependencies in `mix.exs`:

        def deps do
          [{:ecto_ldap, "~> 0.3"}]
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

## Usage

Use the `ecto_ldap` adapter, just as you would any other Ecto backend.

### Example Schema


        defmodule User do
          use Ecto.Schema
          import Ecto.Changeset

          @primary_key {:dn, :string, autogenerate: false}
          schema "users" do
            field :objectClass, {:array, :string}
            field :loginShell, :string
            field :mail, :string
            field :mobile, :string
            field :skills, {:array, :string}
            field :sn, :string
            field :st, :string
            field :startDate, Ecto.DateTime
            field :uid, :string
            field :jpegPhoto, :binary
          end

          def changeset(model, params \\ :empty) do
            model
            |> cast(params, ~w(dn), ~w(objectClass loginShell mail mobile skills sn uid))
            |> unique_constraint(:dn)
          end

        end

### Example Queries

        Repo.get User, "uid=jeff.weiss,ou=users,dc=example,dc=com"

        Repo.get_by User, uid: "jeff.weiss"

        Repo.all User, st: "OR"

        Ecto.Query.from(u in User, where: like(u.mail, "%@example.com"))

        Ecto.Query.from(u in User, where: "inetOrgPerson" in u.objectClass and not is_nil(u.jpegPhoto), select: u.uid)
