defmodule Ecto.Ldap.Adapter.Dumpers do
  import Ecto.Ldap.Adapter.Converter

  @doc """

  Returns a function that can convert a value from the Ecto
  data format to a form that `:eldap` can interpret.

  The functions (or types) returned by these calls will be invoked
  by Ecto while performing the translation of values to valid `eldap` data.

  `nil`s are simply passed straight through regardless of Ecto datatype.
  Additionally, `:id`, `:binary`, and other unspecified datatypes are directly
  returned to Ecto for native translation.

  ### Examples

      iex> Ecto.Ldap.Adapter.dumpers(:id, :id)
      [:id]

      iex> Ecto.Ldap.Adapter.dumpers(:string, nil)
      { :ok, nil}

      iex> Ecto.Ldap.Adapter.dumpers(:binary, :binary)
      [:binary]

      iex> Ecto.Ldap.Adapter.dumpers(:woo, :woo)
      [:woo]

      iex> Ecto.Ldap.Adapter.dumpers(:integer, :integer)
      [:integer]


  Strings are converted to Erlang character lists.

  ### Examples

      iex> [conversion_function] = Ecto.Ldap.Adapter.dumpers({:in, :string}, {:in, :string})
      iex> conversion_function.(["yes", "no"])
      { :ok, {:in, ['yes', 'no']}}

      iex> [conversion_function] = Ecto.Ldap.Adapter.dumpers(:string, :string)
      iex> conversion_function.("bob")
      { :ok, 'bob'}
      iex> conversion_function.("Sören")
      { :ok, [83, 195, 182, 114, 101, 110]}
      iex> conversion_function.("José")
      { :ok, [74, 111, 115, 195, 169]}
      iex> conversion_function.(:atom)
      { :ok, 'atom'}

      iex> [conversion_function] = Ecto.Ldap.Adapter.dumpers({:array, :string}, {:array, :string})
      iex> conversion_function.(["list", "of", "skills"])
      { :ok, ['list', 'of', 'skills']}


  Ecto.DateTimes are converted to a stringified ASN.1 GeneralizedTime format in UTC. Currently,
  fractional seconds are truncated.

  ### Examples

      iex> [conversion_function] = Ecto.Ldap.Adapter.dumpers(:datetime, :datetime)
      iex> conversion_function.({{2016, 2, 2}, {0, 0, 0, 0}})
      { :ok, '20160202000000Z'}

      iex> [conversion_function] = Ecto.Ldap.Adapter.dumpers(Ecto.DateTime, Ecto.DateTime)
      iex> conversion_function.({{2016, 4, 1}, {12, 34, 56, 789000}})
      { :ok, '20160401123456Z'}
      iex> conversion_function.({{2016, 4, 1}, {12, 34, 56, 0}})
      { :ok, '20160401123456Z'}

  """
  @spec dumpers(Ecto.Type.primitive, Ecto.Type.t) :: [(term -> {:ok, term} | :error) | Ecto.Type.t]
  def dumpers(_, nil), do: {:ok, nil}
  def dumpers({:in, _type}, {:in, _}), do: [&dump_in/1]
  def dumpers(:string, _type), do: [&dump_string/1]
  def dumpers({:array, :string}, _type), do: [&dump_array/1]
  def dumpers(:datetime, _type), do: [&dump_date/1]
  def dumpers(Ecto.DateTime, _type), do: [&dump_date/1]
  def dumpers(_primitive, type), do: [type]

  def dump_in(value), do: {:ok, {:in, convert_to_erlang(value)}}
  def dump_string(value), do: {:ok, convert_to_erlang(value)}
  def dump_array(value) when is_list(value), do: {:ok, convert_to_erlang(value)}
  def dump_date(value) when is_tuple(value) do
    with {:ok, v} <- Timex.Ecto.DateTime.load(value), {:ok, d} <- Timex.format(v, "{ASN1:GeneralizedTime:Z}") do
      {:ok, convert_to_erlang(d)}
    end
  end
end
