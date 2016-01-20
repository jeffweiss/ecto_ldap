# Code.require_file "../../deps/ecto/integration_test/support/models.exs", __DIR__
defmodule Ecto.Ldap.TestModel do
  use Ecto.Model

  schema "model" do
    field :x, :integer
    field :y, :integer, default: 5
    field :z, {:array, :integer}
  end
end
