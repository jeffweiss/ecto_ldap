defmodule Ecto.Ldap.Adapter do
  use GenServer
  require IEx

  @behaviour Ecto.Adapter

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

  def execute(repo, query_metadata, prepared, params, preprocess, options) do
    IO.inspect(repo)
    IO.inspect(query_metadata)
    IO.inspect(prepared)
    IO.inspect(params)
    IO.inspect(preprocess)
    IO.inspect(options)

    {:ok, connection} = Exldap.connect
    # IEx.pry
    {:ok, search_results} = Exldap.search_field(
        connection,
        prepared[:base],
        prepared[:filter_parameter],
        prepared[:filter_criteria])

    IO.inspect search_results

    # :eldap.search(repo.something, prepared)
    # transform results into list of lists

    :wat
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
      ]
      |> Enum.map(&(apply(__MODULE__, &1, [query])))
      |> Enum.filter(&(&1))


      [ {:base, construct_base(query.from)},
        {:filter, construct_filter(query.wheres)},
        {:scope, construct_scope},
        {:attributes, construct_attributes(query.select)},
        {:filter_parameter, extract_parameter(query.wheres)},
        {:filter_criteria, extract_criteria(query.wheres)}
      ]
    {:nocache, query_metadata}
  end

  def construct_base(%{from: from}) do
    {:base, "ou=" <> ou <> "," <> base}
  end
  def constuct_base(_), do: {:base, base}

  defp base, do: Keyword.get(Application.get_env(:exldap, :settings), :base)

  def construct_filter(%{wheres: wheres}) when is_list(wheres) do 
    filter_term = 
      wheres
      |> Stream.map(&Map.get(&1, :expr))
      |> Enum.map(&translate_ecto_lisp_to_eldap_filter/1)
      |> :eldap.and
    {:filter, filter_term}
  end
  def construct_filter(_), do: nil

  def extract_parameter(wheres) do
    [{{_, _, [_ | parameter]}, _, _} | _] = extract_array(wheres)
    case parameter do
      {:&, [], [0]} -> []
      _ -> to_string(hd(parameter))
    end
  end

  def extract_criteria([]), do: []
  def extract_criteria(wheres), do: hd(tl(extract_array(wheres)))

  def extract_array([%Ecto.Query.QueryExpr{expr: {_, _, array}} | _tail]), do: array

  def construct_scope, do: {:scope, :eldap.wholeSubtree}

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

  def translate_value({{:., [], [{:&, [], [0]}, attribute]}, [], []}) when is_atom(attribute) do
    attribute
    |> to_string
    |> to_char_list
  end
  def translate_value(%Ecto.Query.Tagged{value: value}), do: value
  def translate_value(other), do: other
end
