defmodule Ecto.Ldap.Adapter do
  use GenServer
  require IEx

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

  def update(schema_meta, fields, filters) do
    GenServer.call(__MODULE__, {:update, schema_meta, fields, filters})
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
    search_response = :eldap.search(handle, search_options)
    ldap_disconnect(handle)

    {:reply, search_response, state}
  end

  def handle_call({:update, schema_meta, fields, filters}, _from, state) do

    {:ok, handle} = ldap_connect(state)
    [base] = Keyword.get(filters, :dn)

    modify_operations =
      for {attribute, value} <- fields do
        generate_modify_operation(attribute, value)
      end

    result = :eldap.modify(handle, base, modify_operations)
    ldap_disconnect(handle)

    {:reply, result, state}
  end

  def generate_modify_operation(attribute, []) do
    :eldap.mod_replace(convert_to_erlang(attribute), [])
  end
  def generate_modify_operation(attribute, value) when is_list(value) do
    :eldap.mod_replace(convert_to_erlang(attribute), value)
  end

  def handle_call(:base, _from, state) do
    base = Keyword.get(state, :base) |> to_char_list
    {:reply, base, state}
  end

  def ldap_connect(state) do
    user_dn   = Keyword.get(state, :user_dn)  |> to_char_list
    password  = Keyword.get(state, :password) |> to_char_list
    hostname  = Keyword.get(state, :hostname) |> to_char_list
    port      = Keyword.get(state, :port, 636)
    use_ssl   = Keyword.get(state, :ssl, true)

    {:ok, handle} = :eldap.open([hostname], [{:port, port}, {:ssl, use_ssl}])
    :eldap.simple_bind(handle, user_dn, password)
    {:ok, handle}
  end

  def ldap_disconnect(handle), do: :eldap.close(handle)

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

  def prepare(:update_all, _query), do: raise Exception, "Update is currently unsupported"
  def prepare(:delete_all, _query), do: raise Exception, "Delete is currently unsupported"

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

  def convert_to_erlang(list) when is_list(list), do: Enum.map(list, &convert_to_erlang/1)
  def convert_to_erlang(string) when is_binary(string), do: :binary.bin_to_list(string)
  def convert_to_erlang(atom) when is_atom(atom), do: atom |> Atom.to_string |> convert_to_erlang
  def convert_to_erlang(num) when is_number(num), do: num

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
  # {:==, [], [{{:., [], [{:&, [], [0]}, :sn]}, [ecto_type: :string], []}, {:^, [], [0]}]}, ['Weiss', 'jeff.weiss@puppetlabs.com']
  def translate_ecto_lisp_to_eldap_filter({op, [], [value1, {:^, [], [idx]}]}, params) do
    translate_ecto_lisp_to_eldap_filter({op, [], [value1, Enum.at(params, idx)]}, params)
  end

  def translate_ecto_lisp_to_eldap_filter({:==, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:>=, _, [value1, value2]}, _) do
    :eldap.greaterOrEqual(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:<=, _, [value1, value2]}, _) do
    :eldap.lessOrEqual(translate_value(value1), translate_value(value2))
  end
  def translate_ecto_lisp_to_eldap_filter({:in, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value2), translate_value(value1))
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
  def translate_value(other), do: other

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
        |> prune_attributes(fields)
        |> generate_models(preprocess, count)
      end

    {count, result_set}
  end

  def translate_options_to_filter([]), do: []
  def translate_options_to_filter(list) when is_list(list) do
    for {attr, value} <- list do
      translate_ecto_lisp_to_eldap_filter({:==, [], [attr, value]}, [])
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
    Enum.map fields, fn
      {:&, _, [idx]} = field ->
        {_source, model} = elem(sources, idx)
        {field, length(model.__schema__(:fields))}
      field ->
        {field, 0}
    end
  end

  def process_entry({:eldap_entry, dn, attributes}) when is_list(attributes) do
    List.flatten(
      [dn: dn], 
      Enum.map(attributes, fn {key, value} ->
        {key |> to_string |> String.to_atom, value}
      end))
  end

  def prune_attributes(attributes, fields) do
    for field <- fields, do: Keyword.get(attributes, field)
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

  def update(repo, schema_meta, fields, filters, _autogen_id, returning, options) do
    case update(schema_meta, fields, filters) do
      :ok ->
        {:ok, fields}
      error ->
        IO.inspect error
        {:invalid, []}
    end
  end

  def load(:id, value), do: {:ok, value}
  def load(:string, value), do: {:ok, convert_from_erlang(value)}
  def load({:array, :string}, []), do: {:ok, []}
  def load({:array, :string}, value), do: {:ok, convert_from_erlang(value)}

  def dump(:string, value) when is_list(value), do: {:ok, convert_to_erlang(value)}
  def dump(:string, value), do: {:ok, [convert_to_erlang(value)]}
  def dump(_, value), do: {:ok, convert_to_erlang(value)}

  def convert_from_erlang(list=[head|_]) when is_list(head), do: Enum.map(list, &convert_from_erlang/1)
  def convert_from_erlang(string) when is_list(string), do: :binary.list_to_bin(string)
  def convert_from_erlang(other), do: other

end
