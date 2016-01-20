defmodule Ecto.Ldap.Adapter do
  use GenServer
  @behaviour Ecto.Adapter

  def execute(repo, query_metadata, prepared, params, preprocess, options) do
    IO.inspect(repo)
    IO.inspect(query_metadata)
    IO.inspect(prepared)
    IO.inspect(params)
    IO.inspect(preprocess)
    IO.inspect(options)

    {:ok, connection} = Exldap.connect
    {:ok, search_results} = Exldap.search_field(
        connection,
        "ou=users,dc=puppetlabs,dc=com",
        "mail",
        'jeff.weiss@puppetlabs.com')

    IO.inspect search_results

    # :eldap.search(repo.something, prepared)
    # transform results into list of lists

    :wat
  end

  def prepare(:all, query) do
    IO.inspect(query)
    search_options =
      [ {:base, "ou=users,dc=puppetlabs,dc=com"},
        {:filter, :eldap.equalityMatch(:mail, 'jeff.weiss@puppetlabs.com')},
        {:scope, :eldap.wholeSubtree()},
        {:attributes, [:dn, :mobile]}
      ]
    {:nocache, search_options}
  end

  def prepare(:update_all, query) do
  end

  def prepare(:delete_all, query) do
    raise ArgumentError, "We don't delete"
  end

  defmacro __before_compile__(env) do
    quote do
    end
  end

  def start_link(repo, opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {:ok, opts}
  end
end
