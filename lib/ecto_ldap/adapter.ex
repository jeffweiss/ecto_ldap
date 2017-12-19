defmodule Ecto.Ldap.Adapter do
  use GenServer
  import Supervisor.Spec
  import Ecto.Ldap.Adapter.Converter

  @behaviour Ecto.Adapter

  defdelegate loaders(primitive, type), to: Ecto.Ldap.Adapter.Loaders
  defdelegate dumpers(primitive, type), to: Ecto.Ldap.Adapter.Dumpers

  @moduledoc """
  Allows talking to an LDAP directory as an Ecto data store.

  ## Sample Configuration

      use Mix.Config

      config :my_app, MyApp.Repo,
        adapter: Ecto.Ldap.Adapter,
        hostname: "ldap.example.com",
        base: "dc=example,dc=com",
        port: 636,
        ssl: true,
        user_dn: "uid=sample_user,ou=users,dc=example,dc=com",
        password: "password",
        pool_size: 1

  Currently `ecto_ldap` does not support a `pool_size` larger than `1`. If this
  is a bottleneck for you, please [open an issue](https://github.com/jeffweiss/ecto_ldap/issues/new).

  ## Example schema


      defmodule TestUser do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key {:dn, :string, autogenerate: false}
        schema "users" do
          field :objectClass, {:array, :string}
          field :loginShell, :string
          field :mail, :string
          field :mobile, :string
          field :skills, {:array, :string}
          field :sn, :string
          field :st, :string
          field :startDate, Ecto.DateTime
          field :uid, :string
          field :jpegPhoto, :binary
        end

        def changeset(model, params \\ :empty) do
          model
          |> cast(params, ~w(dn), ~w(objectClass loginShell mail mobile skills sn uid))
          |> unique_constraint(:dn)
        end

      end

  ## Example Usage

      iex> require Ecto.Query
      iex> Ecto.Query.from(u in TestUser, select: u.uid) |> TestRepo.all
      ["jeff.weiss", "manny"]

      iex> TestRepo.all(TestUser, uid: "jeff.weiss") |> Enum.count
      1

      iex> TestRepo.get(TestUser, "uid=jeff.weiss,ou=users,dc=example,dc=com").mail
      "jeff.weiss@example.com"

      iex> TestRepo.get_by(TestUser, uid: "jeff.weiss").loginShell
      "/bin/zsh"

      iex> Ecto.Query.from(u in TestUser, where: u.st == "OR" and "elixir" in u.skills) |> TestRepo.all |> List.first |> Map.get(:uid)
      "jeff.weiss"

      iex> Ecto.Query.from(u in TestUser, where: like(u.sn, "%Weis%")) |> TestRepo.all |> List.first |> Map.get(:uid)
      "jeff.weiss"

  """

  ####
  #
  # GenServer API
  #
  ####
  @doc false
  def start_link(_repo, opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def child_spec(repo, opts) do
    worker(__MODULE__, [repo, opts], name: __MODULE__)
  end

  @doc false
  def init(opts) do
    {:ok, opts}
  end

  ####
  #
  # Client API
  #
  ####
  @doc false
  def search(search_options) do
    GenServer.call(__MODULE__, {:search, search_options})
  end

  @doc false
  def update(dn, modify_operations) do
    GenServer.call(__MODULE__, {:update, dn, modify_operations})
  end

  @doc false
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
    base = Keyword.get(state, :base) |> to_charlist()
    {:reply, base, state}
  end

  @spec ldap_api([{atom, any}]) :: :eldap | module
  defp ldap_api(state) do
    Keyword.get(state, :ldap_api, :eldap)
  end

  @spec ldap_connect([{atom, any}]) :: {:ok, pid}
  defp ldap_connect(state) do
    user_dn   = Keyword.get(state, :user_dn)  |> to_charlist()
    password  = Keyword.get(state, :password) |> to_charlist()
    hostname  = Keyword.get(state, :hostname) |> to_charlist()
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

  @doc false
  def construct_filter(%{wheres: wheres}) when is_list(wheres) do
    filter_term =
      wheres
      |> Enum.map(&Map.get(&1, :expr))
    {:filter, filter_term}
  end

  @doc false
  def construct_filter(wheres, params) when is_list(wheres) do
    filter_term =
      wheres
      |> Enum.map(&(translate_ecto_lisp_to_eldap_filter(&1, params)))
      |> :eldap.and
    {:filter, filter_term}
  end

  @doc false
  def construct_base(%{from: {from, _}}) do
    {:base, to_charlist("ou=" <> from <> "," <> to_string(base())) }
  end
  @doc false
  def constuct_base(_), do: {:base, base()}

  @doc false
  def construct_scope(_), do: {:scope, :eldap.wholeSubtree}

  @doc false
  def construct_attributes(%{select: select, sources: sources}) do
    case select.fields do
      [{:&, [], [0]}] ->
        { :attributes,
          sources
          |> ordered_fields
          |> List.flatten
          |> Enum.map(&convert_to_erlang/1)
        }
      attributes ->
        {
          :attributes,
          attributes
          |> Enum.map(&extract_select/1)
          |> List.flatten
          |> Enum.map(&convert_to_erlang/1)
        }
    end
  end

  defp extract_select({:&, _, [_, select, _]}), do: select
  defp extract_select({{:., _, [{:&, _, _}, select]}, _, _}), do: select

  defp translate_ecto_lisp_to_eldap_filter({:or, _, list_of_subexpressions}, params) do
    list_of_subexpressions
    |> Enum.map(&(translate_ecto_lisp_to_eldap_filter(&1, params)))
    |> :eldap.or
  end
  defp translate_ecto_lisp_to_eldap_filter({:and, _, list_of_subexpressions}, params) do
    list_of_subexpressions
    |> Enum.map(&(translate_ecto_lisp_to_eldap_filter(&1, params)))
    |> :eldap.and
  end
  defp translate_ecto_lisp_to_eldap_filter({:not, _, [subexpression]}, params) do
    :eldap.not(translate_ecto_lisp_to_eldap_filter(subexpression, params))
  end
  # {:==, [], [{{:., [], [{:&, [], [0]}, :sn]}, [ecto_type: :string], []}, {:^, [], [0]}]}, ['Weiss', 'jeff.weiss@puppetlabs.com']
  defp translate_ecto_lisp_to_eldap_filter({op, [], [value1, {:^, [], [idx]}]}, params) do
    translate_ecto_lisp_to_eldap_filter({op, [], [value1, Enum.at(params, idx)]}, params)
  end
  defp translate_ecto_lisp_to_eldap_filter({op, [], [value1, {:^, [], [idx,len]}]}, params) do
    translate_ecto_lisp_to_eldap_filter({op, [], [value1, Enum.slice(params, idx, len)]}, params)
  end
  # {:in, [], [{:^, [], [0]}, {{:., [], [{:&, [], [0]}, :uniqueMember]}, [], []}]}, ['uid=manny,ou=users,dc=puppetlabs,dc=com']
  defp translate_ecto_lisp_to_eldap_filter({op, [], [{:^, [], [idx]}, value2]}, params) do
    translate_ecto_lisp_to_eldap_filter({op, [], [Enum.at(params, idx), value2]}, params)
  end

  defp translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, "%" <> value2]}, _) do
    like_with_leading_wildcard(value1, value2)
  end
  defp translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, [37|value2]]}, _) do
    like_with_leading_wildcard(value1, convert_from_erlang(value2))
  end
  defp translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, value2]}, _) when is_list(value2) do
    like_without_leading_wildcard(value1, convert_from_erlang(value2))
  end
  defp translate_ecto_lisp_to_eldap_filter({:ilike, _, [value1, value2]}, _) when is_binary(value2) do
    like_without_leading_wildcard(value1, value2)
  end
  defp translate_ecto_lisp_to_eldap_filter({:like, a, b}, params) do
    translate_ecto_lisp_to_eldap_filter({:ilike, a, b}, params)
  end
  defp translate_ecto_lisp_to_eldap_filter({:==, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value1), translate_value(value2))
  end
  defp translate_ecto_lisp_to_eldap_filter({:!=, _, [value1, value2]}, _) do
    :eldap.not(:eldap.equalityMatch(translate_value(value1), translate_value(value2)))
  end
  defp translate_ecto_lisp_to_eldap_filter({:>=, _, [value1, value2]}, _) do
    :eldap.greaterOrEqual(translate_value(value1), translate_value(value2))
  end
  defp translate_ecto_lisp_to_eldap_filter({:<=, _, [value1, value2]}, _) do
    :eldap.lessOrEqual(translate_value(value1), translate_value(value2))
  end
  defp translate_ecto_lisp_to_eldap_filter({:in, _, [value1, value2]}, _) when is_list(value2) do
    for value <- value2 do
      :eldap.equalityMatch(translate_value(value1), translate_value(value))
    end
    |> :eldap.or
  end
  defp translate_ecto_lisp_to_eldap_filter({:in, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value2), translate_value(value1))
  end
  defp translate_ecto_lisp_to_eldap_filter({:is_nil, _, [value]}, _) do
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

  defp translate_value({{:., [], [{:&, [], [0]}, attribute]}, _ecto_type, []}) when is_atom(attribute) do
    translate_value(attribute)
  end
  defp translate_value(%Ecto.Query.Tagged{value: value}), do: value
  defp translate_value(atom) when is_atom(atom) do
    atom
    |> to_string()
    |> to_charlist()
  end
  defp translate_value(other), do: convert_to_erlang(other)

  def execute(_repo, query_metadata, {:nocache, prepared}, params, preprocess, options) do
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
    IO.inspect query_metadata
    count = count_fields(query_metadata.select, query_metadata.sources)

    {:ok, {:eldap_search_result, results, []}} = search_response

    result_set =
      for entry <- results do
        entry
        |> process_entry
        |> prune_attributes(fields, count)
        |> generate_models(preprocess, extract_fields(query_metadata))
      end

    {count, result_set}
  end

  defp extract_fields(%{fields: fields}), do: fields
  defp extract_fields(%{select: %{preprocess: [{:source, _, fields}]}}), do: fields

  defp translate_options_to_filter([]), do: []
  defp translate_options_to_filter(list) when is_list(list) do
    for {attr, value} <- list do
      translate_ecto_lisp_to_eldap_filter({:==, [], [attr, convert_to_erlang(value)]}, [])
    end
  end

  defp merge_search_options({filter, []}, full_search_terms) do
    full_search_terms
    |> Keyword.put(:filter, filter)
  end
  defp merge_search_options({filter, [base: dn]}, full_search_terms) do
    full_search_terms
    |> Keyword.put(:filter, filter)
    |> Keyword.put(:base, dn)
    |> Keyword.put(:scope, :eldap.baseObject)
  end
  defp merge_search_options(_, _) do
    raise "Unable to search across multiple base DNs"
  end

  defp replace_dn_search_with_objectclass_present(search_options) when is_list(search_options)do
    {filter, dns} =
      search_options
      |> Keyword.get(:filter)
      |> replace_dn_filters
    {filter, dns |> List.flatten |> Enum.uniq}
  end

  defp replace_dn_filters([]), do: {[], []}
  defp replace_dn_filters([head|tail]) do
    {h, hdns} = replace_dn_filters(head)
    {t, tdns} = replace_dn_filters(tail)
    {[h|t], [hdns|tdns]}
  end
  defp replace_dn_filters({:equalityMatch, {:AttributeValueAssertion, 'dn', dn}}) do
    {:eldap.present('objectClass'), {:base, dn}}
  end
  defp replace_dn_filters({conjunction, list}) when is_list(list) do
    {l, dns} = replace_dn_filters(list)
    {{conjunction, l}, dns}
  end
  defp replace_dn_filters(other), do: {other, []}

  defp ordered_fields(sources) do
    {_, model} = elem(sources, 0)
    model.__schema__(:fields)
  end

  def count_fields(%{preprocess: [{:source, _, fields}]}, _), do: fields
  def count_fields(fields, sources) when is_list(fields), do: fields |> Enum.map(fn field -> count_fields(field, sources) end) |> List.flatten
  def count_fields({{_, _, fields}, _, _}, sources), do: fields |> extract_field_info(sources)
  def count_fields({:&, _, [_idx]} = field, sources), do: extract_field_info(field, sources)

  defp extract_field_info({:&, _, [idx]} = field, sources) do
    {_source, model} = elem(sources, idx)
    [{field, length(model.__schema__(:fields))}]
  end
  defp extract_field_info(field, _sources) do
    [{field, 0}]
  end

  defp process_entry({:eldap_entry, dn, attributes}) when is_list(attributes) do
    List.flatten(
      [dn: dn],
      Enum.map(attributes, fn {key, value} ->
        {key |> to_string |> String.to_atom, value}
      end))
  end

  defp prune_attributes(attributes, all_fields, [{{:&, [], [0]}, _}] = _selected_fields) do
    for field <- all_fields, do: Keyword.get(attributes, field)
  end
  defp prune_attributes(attributes, _all_fields, selected_fields) do
    selected_fields
    |> Enum.map(fn {[{:&, [], _}, field], _} ->
      Keyword.get(attributes, field)
      {field, _type} -> Keyword.get(attributes, field)
      end)
  end

  defp generate_models(row, preprocess, [{:&, [], [_idx, _columns, _count]}] = fields), do:
    Enum.map(fields, fn field -> preprocess.(field, row, nil) end)
  defp generate_models([field_data | data], preprocess, [{{:., [], [{:&, [], [0]}, _field_name]}, [ecto_type: _type], []} = field | remaining_fields]), do:
    generate_models(data, preprocess, remaining_fields, [preprocess.(field, field_data, nil)])
  defp generate_models([field_data | data], preprocess, [field | remaining_fields], mapped_data), do:
    generate_models(data, preprocess, remaining_fields, [preprocess.(field, field_data, nil) | mapped_data])
  defp generate_models([], _preprocess, [], mapped_data), do:
    :lists.reverse(mapped_data)

  def update(_repo, schema_meta, fields, filters, _returning, _options) do

    dn = Keyword.get(filters, :dn)

    modify_operations =
      for {attribute, value} <- fields do
        type = schema_meta.schema.__schema__(:type, attribute)
        generate_modify_operation(attribute, value, type)
      end

    case update(dn, modify_operations) do
      :ok ->
        {:ok, fields}
      {:error, reason} ->
        {:invalid, [reason]}
    end
  end

  defp generate_modify_operation(attribute, nil, _) do
    :eldap.mod_replace(convert_to_erlang(attribute), [])
  end
  defp generate_modify_operation(attribute, [], {:array, _}) do
    :eldap.mod_replace(convert_to_erlang(attribute), [])
  end
  defp generate_modify_operation(attribute, value, {:array, _}) do
    :eldap.mod_replace(convert_to_erlang(attribute), value)
  end
  defp generate_modify_operation(attribute, value, _) do
    :eldap.mod_replace(convert_to_erlang(attribute), [value])
  end

  def autogenerate(_), do: raise ArgumentError, message: "autogenerate not supported"
  def delete(_, _, _, _), do: raise ArgumentError, message: "delete not supported"
  def ensure_all_started(_, _), do: {:ok, []}
  def insert(_, _, _, _, _, _), do: raise ArgumentError, message: "insert not supported"
  def insert_all(_, _, _, _, _, _, _), do: raise ArgumentError, message: "insert_all not supported"
end
