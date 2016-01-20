# Helper script for iex testing
# $ iex -S mix
# iex(1)> import_file "chuck.exs"

import Supervisor.Spec
tree = [worker(Ecto.Ldap.TestRepo, [])]
opts = [name: Ecto.Ldap.Sup, strategy: :one_for_one]
Supervisor.start_link(tree, opts)

alias Ecto.Ldap.TestRepo
alias Ecto.Ldap.TestModel
