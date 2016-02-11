defmodule Ecto.Ldap.TestUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:dn, :string, autogenerate: false}
  schema "users" do
    field :objectClass, :string
    field :languages, {:array, :string}
    field :mail, :string
    field :mobile, :string
    field :skills, {:array, :string}
    field :sn, :string
    field :uid, :string
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(dn), ~w(languages objectClass mail mobile skills sn uid))
    |> unique_constraint(:dn)
  end

end
