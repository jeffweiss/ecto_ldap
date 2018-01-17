Code.require_file "../../deps/ecto/integration_test/support/repo.exs", __DIR__
defmodule Ecto.Ldap.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto
end
