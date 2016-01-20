defmodule Ecto.Ldap.Storage do
  @behaviour Ecto.Adapter.Storage

  def storage_up(_), do: {:error, :already_up}
  def storage_down(_), do: {:error, :already_down}
end
