# Helper script for iex testing
# $ iex -S mix

Code.require_file "test/support/test_repo.ex", __DIR__
Code.require_file "test/support/test_user.ex", __DIR__

require Ecto.Query

alias Ecto.Ldap.Adapter
alias Ecto.Ldap.TestRepo
alias Ecto.Ldap.TestUser
alias Ecto.Query

TestRepo.start_link
