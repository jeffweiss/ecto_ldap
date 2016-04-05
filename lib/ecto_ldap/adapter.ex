defmodule Ecto.Ldap.Adapter do
  use GenServer

  @behaviour Ecto.Adapter

  ####
  #
  # GenServer API
  #
  ####
  def start_link(_repo, opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
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

  def update(dn, modify_operations) do
    GenServer.call(__MODULE__, {:update, dn, modify_operations})
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
    {:ok, handle}   = ldap_connect(state)
    search_response = ldap_api(state).search(handle, search_options)
    ldap_api(state).close(handle)

    {:reply, search_response, state}
  end

  def handle_call({:update, dn, modify_operations}, _from, state) do
    {:ok, handle}   = ldap_connect(state)
    update_response = ldap_api(state).modify(handle, dn, modify_operations)
    ldap_api(state).close(handle)

    {:reply, update_response, state}
  end

  def handle_call(:base, _from, state) do
    base = Keyword.get(state, :base) |> to_char_list
    {:reply, base, state}
  end

  def ldap_api(state) do
    Keyword.get(state, :ldap_api, :eldap)
  end

  def ldap_connect(state) do
    user_dn   = Keyword.get(state, :user_dn)  |> to_char_list
    password  = Keyword.get(state, :password) |> to_char_list
    hostname  = Keyword.get(state, :hostname) |> to_char_list
    port      = Keyword.get(state, :port, 636)
    use_ssl   = Keyword.get(state, :ssl, true)

    {:ok, handle} = ldap_api(state).open([hostname], [{:port, port}, {:ssl, use_ssl}])
    ldap_api(state).simple_bind(handle, user_dn, password)
    {:ok, handle}
  end

  ####
  #
  # Ecto.Adapter.API
  #
  ####
  defmacro __before_compile__(_env) do
    quote do
    end
  end

  def prepare(:all, query) do
    query_metadata = 
      [
        :construct_filter,
        :construct_base,
        :construct_scope,
        :construct_attributes,
      ]
      |> Enum.map(&(apply(__MODULE__, &1, [query])))
      |> Enum.filter(&(&1))

    {:nocache, query_metadata}
  end

  def prepare(:update_all, _query), do: raise "Update is currently unsupported"
  def prepare(:delete_all, _query), do: raise "Delete is currently unsupported"

  def construct_filter(%{wheres: wheres}) when is_list(wheres) do
    filter_term = 
      wheres
      |> Enum.map(&Map.get(&1, :expr))
    {:filter, filter_term}
  end

  def construct_filter(wheres, params) when is_list(wheres) do
    filter_term =
      wheres
      |> Enum.map(&(translate_ecto_lisp_to_eldap_filter(&1, params)))
      |> :eldap.and
    {:filter, filter_term}
  end

  def construct_base(%{from: {from, _}}) do
    {:base, to_char_list("ou=" <> from <> "," <> to_string(base)) }
  end
  def constuct_base(_), do: {:base, base}

  def construct_scope(_), do: {:scope, :eldap.wholeSubtree}

  def construct_attributes(%{select: select, sources: sources}) do
    case select.fields do
      [{:&, [], [0]}] -> 
        { :attributes,
          sources |> ordered_fields |> Enum.map(&convert_to_erlang/1) }
      attributes -> 
        {
          :attributes,
          attributes
          |> Enum.map(&extract_select/1)
          |> Enum.map(&convert_to_erlang/1)
        }
    end
  end

  def extract_select({{:., _, [{:&, _, _}, select]}, _, _}), do: select

  def translate_ecto_lisp_to_eldap_filter({:or, _, list_of_subexpressions}, params) do
    list_of_subexpressions
    |> Enum.map(&(translate_ecto_lisp_to_eldap_filter(&1, params)))
    |> :eldap.or
  end
  def translate_ecto_lisp_to_eldap_filter({:and, _, list_of_subexpressions}, params) do
    list_of_subexpressions
    |> Enum.map(&(translate_ecto_lisp_to_eldap_filter(&1, params)))
    |> :eldap.and
  end
  def translate_ecto_lisp_to_eldap_filter({:not, _, [subexpression]}, params) do
    :eldap.not(translate_ecto_lisp_to_eldap_filter(subexpression, params))
  end
  # {:==, [], [{{:., [], [{:&, [], [0]}, :sn]}, [ecto_type: :string], []}, {:^, [], [0]}]}, ['Weiss', 'jeff.weiss@puppetlabs.com']
  def translate_ecto_lisp_to_eldap_filter({op, [], [value1, {:^, [], [idx]}]}, params) do
    translate_ecto_lisp_to_eldap_filter({op, [], [value1, Enum.at(params, idx)]}, params)
  end
  def translate_ecto_lisp_to_eldap_filter({op, [], [value1, {:^, [], [idx,len]}]}, params) do
    translate_ecto_lisp_to_eldap_filter({op, [], [value1, Enum.slice(params, idx, len)]}, params)
  end

  def translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, "%" <> value2]}, _) do
    like_with_leading_wildcard(value1, value2)
  end
  def translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, [37|value2]]}, _) do
    like_with_leading_wildcard(value1, convert_from_erlang(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, value2]}, _) when is_list(value2) do
    like_without_leading_wildcard(value1, convert_from_erlang(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, value2]}, _) when is_binary(value2) do
    like_without_leading_wildcard(value1, value2)
  end
  def translate_ecto_lisp_to_eldap_filter({:like, a, b}, params) do
    translate_ecto_lisp_to_eldap_filter({:ilike, a, b}, params)
  end
  def translate_ecto_lisp_to_eldap_filter({:==, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:!=, _, [value1, value2]}, _) do
    :eldap.not(:eldap.equalityMatch(translate_value(value1), translate_value(value2)))
  end
  def translate_ecto_lisp_to_eldap_filter({:>=, _, [value1, value2]}, _) do
    :eldap.greaterOrEqual(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:<=, _, [value1, value2]}, _) do
    :eldap.lessOrEqual(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:in, _, [value1, value2]}, _) when is_list(value2) do
    for value <- value2 do
      :eldap.equalityMatch(translate_value(value1), translate_value(value))
    end
    |> :eldap.or
  end
  def translate_ecto_lisp_to_eldap_filter({:in, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value2), translate_value(value1))
  end
  def translate_ecto_lisp_to_eldap_filter({:is_nil, _, [value]}, _) do
    :eldap.not(:eldap.present(translate_value(value)))
  end

  defp like_with_leading_wildcard(value1, value2) do
    case String.last(value2) do
      "%" -> :eldap.substrings(translate_value(value1), [{:any, translate_value(String.slice(value2, 0..-2))}])
      _ -> :eldap.substrings(translate_value(value1), [{:final, translate_value(value2)}])
    end
  end
  defp like_without_leading_wildcard(value1, value2) do
    case String.last(value2) do
      "%" -> :eldap.substrings(translate_value(value1), [{:initial, translate_value(String.slice(value2, 0..-2))}])
      _ -> :eldap.substrings(translate_value(value1), [{:any, translate_value(value2)}])
    end
  end

  def translate_value({{:., [], [{:&, [], [0]}, attribute]}, _ecto_type, []}) when is_atom(attribute) do
    translate_value(attribute)
  end
  def translate_value(%Ecto.Query.Tagged{value: value}), do: value
  def translate_value(atom) when is_atom(atom) do
    atom
    |> to_string
    |> to_char_list
  end
  def translate_value(other), do: convert_to_erlang(other)

  def execute(_repo, query_metadata, prepared, params, preprocess, options) do
    {:filter, filter} = construct_filter(Keyword.get(prepared, :filter), params)
    options_filter = :eldap.and(translate_options_to_filter(options))
    full_filter = :eldap.and([filter, options_filter])

    search_response =
      prepared
      |> Keyword.put(:filter, full_filter)
      |> replace_dn_search_with_objectclass_present
      |> merge_search_options(prepared)
      |> search

    fields = ordered_fields(query_metadata.sources)
    count = count_fields(query_metadata.select.fields, query_metadata.sources)

    {:ok, {:eldap_search_result, results, []}} = search_response

    result_set =
      for entry <- results do
        entry
        |> process_entry
        |> prune_attributes(fields, count)
        |> generate_models(preprocess, count)
      end

    {count, result_set}
  end

  def translate_options_to_filter([]), do: []
  def translate_options_to_filter(list) when is_list(list) do
    for {attr, value} <- list do
      translate_ecto_lisp_to_eldap_filter({:==, [], [attr, convert_to_erlang(value)]}, [])
    end
  end

  def merge_search_options({filter, []}, full_search_terms) do
    full_search_terms
    |> Keyword.put(:filter, filter)
  end
  def merge_search_options({filter, [base: dn]}, full_search_terms) do
    full_search_terms
    |> Keyword.put(:filter, filter)
    |> Keyword.put(:base, dn)
    |> Keyword.put(:scope, :eldap.baseObject)
  end
  def merge_search_options(_, _) do
    raise "Unable to search across multiple base DNs"
  end

  def replace_dn_search_with_objectclass_present(search_options) when is_list(search_options)do
    {filter, dns} =
      search_options
      |> Keyword.get(:filter)
      |> replace_dn_filters
    {filter, dns |> List.flatten |> Enum.uniq}
  end

  def replace_dn_filters([]), do: {[], []}
  def replace_dn_filters([head|tail]) do
    {h, hdns} = replace_dn_filters(head)
    {t, tdns} = replace_dn_filters(tail)
    {[h|t], [hdns|tdns]}
  end
  def replace_dn_filters({:equalityMatch, {:AttributeValueAssertion, 'dn', dn}}) do
    {:eldap.present('objectClass'), {:base, dn}}
  end
  def replace_dn_filters({conjunction, list}) when is_list(list) do
    {l, dns} = replace_dn_filters(list)
    {{conjunction, l}, dns}
  end
  def replace_dn_filters(other), do: {other, []}

  def ordered_fields(sources) do
    {_, model} = elem(sources, 0)
    model.__schema__(:fields)
  end

  def count_fields(fields, sources) do
    fields
    |> Enum.map(fn
      {:&, _, [idx]} = field ->
        {_source, model} = elem(sources, idx)
        {field, length(model.__schema__(:fields))}
      field ->
        {field, 0}
    end)
  end

  def process_entry({:eldap_entry, dn, attributes}) when is_list(attributes) do
    List.flatten(
      [dn: dn], 
      Enum.map(attributes, fn {key, value} ->
        {key |> to_string |> String.to_atom, value}
      end))
  end

  def prune_attributes(attributes, fields, [{{:&, [], [0]}, _}]) do
    for field <- fields, do: Keyword.get(attributes, field)
  end
  def prune_attributes(attributes, all_fields, selected_fields) do
    for {{{:., [], [{:&, [], [0]}, field]}, [ecto_type: _], []}, 0} <- selected_fields do
      Keyword.get(attributes, field)
    end
  end

  def generate_models(row, preprocess, fields) do
    Enum.map_reduce(fields, row, fn
      {field, 0}, [h|t] ->
        {preprocess.(field, h, nil), t}
      {field, count}, acc ->
        case split_and_not_nil(acc, count, true, []) do
          {nil, rest} -> {nil, rest}
          {val, rest} -> {preprocess.(field, val, nil), rest}
        end
    end) |> elem(0)
  end

  def split_and_not_nil(rest, 0, true, _acc), do: {nil, rest}
  def split_and_not_nil(rest, 0, false, acc), do: {:lists.reverse(acc), rest}

  def split_and_not_nil([nil|t], count, all_nil?, acc) do
    split_and_not_nil(t, count - 1, all_nil?, [nil|acc])
  end

  def split_and_not_nil([h|t], count, _all_nil?, acc) do
    split_and_not_nil(t, count - 1, false, [h|acc])
  end

  def update(repo, schema_meta, fields, filters, _autogenerate_id, returning, options) do

    dn = Keyword.get(filters, :dn)

    modify_operations =
      for {attribute, value} <- fields do
        type = schema_meta.model.__schema__(:type, attribute)
        generate_modify_operation(attribute, value, type)
      end

    case update(dn, modify_operations) do
      :ok ->
        {:ok, fields}
      {:error, reason} ->
        {:invalid, [reason]}
    end
  end

  def generate_modify_operation(attribute, nil, _) do
    :eldap.mod_replace(convert_to_erlang(attribute), [])
  end
  def generate_modify_operation(attribute, [], {:array, _}) do
    :eldap.mod_replace(convert_to_erlang(attribute), [])
  end

  def generate_modify_operation(attribute, value, {:array, _}) do
    :eldap.mod_replace(convert_to_erlang(attribute), value)
  end

  def generate_modify_operation(attribute, value, _) do
    :eldap.mod_replace(convert_to_erlang(attribute), [value])
  end


  @doc """
  Convert a value from its data-store representation to something that Ecto expects.
  `:id` fields are always returned unchanged.

  ### Examples

    iex> Ecto.Ldap.Adapter.load(:id, "uid=jeff.weiss,ou=users,dc=example,dc=com")
    {:ok, "uid=jeff.weiss,ou=users,dc=example,dc=com"}

    iex> Ecto.Ldap.Adapter.load(:id, 123456)
    {:ok, 123456}

    iex> Ecto.Ldap.Adapter.load(:id, nil)
    {:ok, nil}


  Given that LDAP uses ASN.1 GeneralizedTime for its datetime storage format, values
  where the type is `Ecto.DateTime` will be converted to a string and parsed as ASN.1
  GeneralizedTime, assuming UTC ( "2016040112[34[56[.789]]]Z" )

  ### Examples
    iex> Ecto.Ldap.Adapter.load(:datetime, ['20160401123456.789Z'])
    {:ok, {{2016, 4, 1}, {12, 34, 56, 789000}}}

    iex> Ecto.Ldap.Adapter.load(:datetime, ['20160401123456Z'])
    {:ok, {{2016, 4, 1}, {12, 34, 56, 0}}}

    iex> Ecto.Ldap.Adapter.load(:datetime, ['201604011234Z'])
    {:ok, {{2016, 4, 1}, {12, 34, 0, 0}}}

    iex> Ecto.Ldap.Adapter.load(:datetime, ['2016040112Z'])
    {:ok, {{2016, 4, 1}, {12, 0, 0, 0}}}

    iex> Ecto.Ldap.Adapter.load(Ecto.DateTime, ['20160401123456.789Z'])
    {:ok, {{2016, 4, 1}, {12, 34, 56, 789000}}}

    iex> Ecto.Ldap.Adapter.load(Ecto.DateTime, ['20160401123456Z'])
    {:ok, {{2016, 4, 1}, {12, 34, 56, 0}}}

    iex> Ecto.Ldap.Adapter.load(Ecto.DateTime, ['201604011234Z'])
    {:ok, {{2016, 4, 1}, {12, 34, 0, 0}}}

    iex> Ecto.Ldap.Adapter.load(Ecto.DateTime, ['2016040112Z'])
    {:ok, {{2016, 4, 1}, {12, 0, 0, 0}}}

  String and binary types will take the first element if the underlying LDAP attribute
  supports multiple values.

  ### Examples

    iex> Ecto.Ldap.Adapter.load(:string, nil)
    {:ok, nil}

    iex> Ecto.Ldap.Adapter.load(:binary, nil)
    {:ok, nil}

    iex> Ecto.Ldap.Adapter.load(:string, [83, 195, 182, 114, 101, 110])
    {:ok, "Sören"}

    iex> Ecto.Ldap.Adapter.load(:string, ['Home, home on the range', 'where the deer and the antelope play'])
    {:ok, "Home, home on the range"}

    iex> Ecto.Ldap.Adapter.load(:binary, [[1,2,3,4,5], [6,7,8,9,10]])
    {:ok, <<1,2,3,4,5>>}

  Array values will be each be converted

  ### Examples

    iex> Ecto.Ldap.Adapter.load({:array, :string}, [])
    {:ok, []}

    iex> Ecto.Ldap.Adapter.load({:array, :string}, ['Home, home on the range', 'where the deer and the antelope play'])
    {:ok, ["Home, home on the range", "where the deer and the antelope play"]}

  """
  def load(:id, value), do: {:ok, value}
  def load(_, nil), do: {:ok, nil}
  def load(:string, value), do: {:ok, trim_converted(convert_from_erlang(value))}
  def load(:binary, value), do: {:ok, trim_converted(convert_from_erlang(value))}
  def load(:datetime, value), do: load(Ecto.DateTime, value)
  def load(Ecto.DateTime, [value]) do
    value
    |> to_string
    |> Timex.parse!("{ASN1:GeneralizedTime:Z}")
    |> Timex.Ecto.DateTime.dump
  end
  def load({:array, :string}, value) do
    {:ok, value |> Enum.map(&convert_from_erlang/1) }
  end

  defp trim_converted(list) when is_list(list), do: hd(list)
  defp trim_converted(other), do: other

  @doc """
  Convert from Ecto datatype to datatype that can be handled via `eldap`.

  `nil`s are simply passed straight through regardless of Ecto datatype.

  ### Examples

    iex> Ecto.Ldap.Adapter.dump(:string, nil)
    {:ok, nil}

    iex> Ecto.Ldap.Adapter.dump(:datetime, nil)
    {:ok, nil}

  Strings are converted to Erlang character lists.

  ### Examples

    iex> Ecto.Ldap.Adapter.dump(:string, "bob")
    {:ok, 'bob'}

    iex> Ecto.Ldap.Adapter.dump(:string, "Sören")
    {:ok, [83, 195, 182, 114, 101, 110]}

    iex> Ecto.Ldap.Adapter.dump(:string, "José")
    {:ok, [74, 111, 115, 195, 169]}

    iex> Ecto.Ldap.Adapter.dump({:array, :string}, ["list", "of", "skills"])
    {:ok, ['list', 'of', 'skills']}

    iex> Ecto.Ldap.Adapter.dump(:integer, 3)
    {:ok, 3}

    iex> Ecto.Ldap.Adapter.dump(:string, :atom)
    {:ok, 'atom'}

  Ecto.DateTimes are converted to a stringified ASN.1 GeneralizedTime format in UTC. Currently,
  fractional seconds are truncated.

  ### Examples

    iex> Ecto.Ldap.Adapter.dump(Ecto.DateTime, {{2016, 4, 1}, {12, 34, 56, 789000}})
    {:ok, '20160401123456Z'}

    iex> Ecto.Ldap.Adapter.dump(Ecto.DateTime, {{2016, 4, 1}, {12, 34, 56, 0}})
    {:ok, '20160401123456Z'}

  """
  def dump(_, nil), do: {:ok, nil}
  def dump(:string, value), do: {:ok, convert_to_erlang(value)}
  def dump({:array, :string}, value) when is_list(value), do: {:ok, convert_to_erlang(value)}
  def dump(Ecto.DateTime, value) when is_tuple(value) do
    with {:ok, v} <- Timex.Ecto.DateTime.load(value), {:ok, d} <- Timex.format(v, "{ASN1:GeneralizedTime:Z}") do
      {:ok, convert_to_erlang(d)}
    end
  end
  def dump(_, value), do: {:ok, convert_to_erlang(value)}

  defp convert_from_erlang(list=[head|_]) when is_list(head), do: Enum.map(list, &convert_from_erlang/1)
  defp convert_from_erlang(string) when is_list(string), do: :binary.list_to_bin(string)
  defp convert_from_erlang(other), do: other

  defp convert_to_erlang(list) when is_list(list), do: Enum.map(list, &convert_to_erlang/1)
  defp convert_to_erlang(string) when is_binary(string), do: :binary.bin_to_list(string)
  defp convert_to_erlang(atom) when is_atom(atom), do: atom |> Atom.to_string |> convert_to_erlang
  defp convert_to_erlang(num) when is_number(num), do: num

end
