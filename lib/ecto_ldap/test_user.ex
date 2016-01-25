defmodule Ecto.Ldap.TestUser do
  use Ecto.Schema

  schema "users" do
    field :dn, :string
    field :objectClass, :string
    field :mail, :string
    field :mobile, :string
    field :sn, :string
  end

end
