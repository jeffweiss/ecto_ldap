defmodule Ecto.Ldap.TestUser do
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
    field :startDate, :naive_datetime
    field :uid, :string
    field :jpegPhoto, :binary
    field :uidNumber, :integer
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(dn), ~w(objectClass loginShell mail mobile skills sn uid))
    |> unique_constraint(:dn)
  end

end
