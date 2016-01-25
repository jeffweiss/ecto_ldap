defmodule Ecto.Ldap.Adapter do
  use GenServer
  require IEx

  @behaviour Ecto.Adapter


  ####
  #
  # GenServer API
  #
  ####
  def start_link(repo, opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    IO.inspect opts
    {:ok, opts}
  end

  ####
  #
  # Client API
  #
  ####
  def search(search_options) do
    GenServer.call(__MODULE__, {:search, search_options})
  end

  def base do
    GenServer.call(__MODULE__, :base)
  end

  ####
  #
  #
  # GenServer server API
  #
  ####
  def handle_call({:search, search_options}, _from, state) do
    IO.inspect(state)
    {:ok, handle} = :eldap.open(['ldap.puppetlabs.com'], [{:port, 636}, {:ssl, true}])
    :eldap.simple_bind(handle, Keyword.get(state, :user_dn) |> to_char_list, Keyword.get(state, :password) |> to_char_list)
    whatever = :eldap.search(handle, search_options)
    :eldap.close(handle)
    {:reply, whatever, state}
  end
  def handle_call(:base, _from, state) do
    {:reply, Keyword.get(state, :base) |> to_char_list, state}
  end


  ####
  #
  # Ecto.Adapter.API
  #
  ####
  defmacro __before_compile__(env) do
    quote do
    end
  end

  def execute(repo, query_metadata, prepared, params, preprocess, options) do
    IO.inspect(repo)
    IO.inspect(query_metadata)
    IO.inspect(prepared)
    IO.inspect(params)
    IO.inspect(preprocess)
    IO.inspect(options)


    something = search(prepared)
    |> IO.inspect
    #transform `something` into whatever the execute contract needs
  end

  def prepare(:all, query) do
    # ou                    == table (`FROM` statement)
    # dc=puppetlabs,dc=com  == database
    # :attributes           == SELECT
    # :filter               == WHERE (equalityMatch / search terms)

    # IO.puts "I'm being prepared!"
    IO.inspect(query)
    # IEx.pry
    query_metadata = 
      [
        :construct_filter,
        :construct_base,
        :construct_scope,
        # :construct_attributes,
      ]
      |> Enum.map(&(apply(__MODULE__, &1, [query])))
      |> Enum.filter(&(&1))

    {:nocache, query_metadata}
  end

  def construct_filter(%{wheres: wheres}) when is_list(wheres) do 
    filter_term = 
      wheres
      |> Stream.map(&Map.get(&1, :expr))
      |> Enum.map(&translate_ecto_lisp_to_eldap_filter/1)
      |> :eldap.and
    {:filter, filter_term}
  end
  def construct_filter(_), do: nil

  def construct_base(%{from: {from, _}}) do
    {:base, to_char_list("ou=" <> from <> "," <> to_string(base)) }
  end
  def constuct_base(_), do: {:base, base}

  def construct_scope(_), do: {:scope, :eldap.wholeSubtree}

  def construct_attributes(_) do
  end

  #   def extract_parameter(wheres) do
  #     [{{_, _, [_ | parameter]}, _, _} | _] = extract_array(wheres)
  #     case parameter do
  #       {:&, [], [0]} -> []
  #       _ -> to_string(hd(parameter))
  #     end
  #   end

  def construct_attributes(%Ecto.Query.SelectExpr{fields: fields}) do
    case fields do
      [{:&, [], [0]}] -> []
      _ -> fields
    end
  end

  def prepare(:update_all, query), do: raise UndefinedFunctionError, "Update is currently unsupported"
  def prepare(:delete_all, query), do: raise UndefinedFunctionError, "Delete is currently unsupported"

  def translate_ecto_lisp_to_eldap_filter({:or, _, list_of_subexpressions}) do
    list_of_subexpressions
    |> Enum.map(&translate_ecto_lisp_to_eldap_filter/1)
    |> :eldap.or
  end
  def translate_ecto_lisp_to_eldap_filter({:and, _, list_of_subexpressions}) do
    list_of_subexpressions
    |> Enum.map(&translate_ecto_lisp_to_eldap_filter/1)
    |> :eldap.and
  end
  def translate_ecto_lisp_to_eldap_filter({:==, _, [value1, value2]}) do
    :eldap.equalityMatch(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:>=, _, [value1, value2]}) do
    :eldap.greaterOrEqual(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:<=, _, [value1, value2]}) do
    :eldap.lessOrEqual(translate_value(value1), translate_value(value2))
  end

  def translate_value({{:., [], [{:&, [], [0]}, attribute]}, _, []}) when is_atom(attribute) do
    attribute
    |> to_string
    |> to_char_list
  end
  def translate_value(%Ecto.Query.Tagged{value: value}), do: value
  def translate_value(other), do: other
end
