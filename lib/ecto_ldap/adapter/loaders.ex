defmodule Ecto.Ldap.Adapter.Loaders do
  import Ecto.Ldap.Adapter.Converter

  @doc """

  Retrieves a function that can convert a value from the LDAP
  data format to a form that Ecto can interpret.

  The functions (or types) returned by these calls will be invoked
  by Ecto while performing the translation of values for LDAP records.


  `:id` fields and unrecognized types are always returned unchanged.

  ### Examples

      iex> Ecto.Ldap.Adapter.loaders(:id, :id)
      [:id]

      iex> Ecto.Ldap.Adapter.loaders(:woo, :woo)
      [:woo]

  Given that LDAP uses ASN.1 GeneralizedTime for its datetime storage format, values
  where the type is `Ecto.DateTime` will be converted to a string and parsed as ASN.1
  GeneralizedTime, assuming UTC ( `"2016040112[34[56[.789]]]Z"` )

  ### Examples

      iex> [conversion_function] = Ecto.Ldap.Adapter.loaders(:datetime, :datetime)
      iex> conversion_function.('20160202000000.000Z')
      { :ok, {{2016, 2, 2}, {0, 0, 0, 0}}}
      iex> conversion_function.('20160401123456.789Z')
      { :ok, {{2016, 4, 1}, {12, 34, 56, 789000}}}
      iex> conversion_function.('20160401123456Z')
      { :ok, {{2016, 4, 1}, {12, 34, 56, 0}}}
      iex> conversion_function.('201604011234Z')
      { :ok, {{2016, 4, 1}, {12, 34, 0, 0}}}
      iex> conversion_function.('2016040112Z')
      { :ok, {{2016, 4, 1}, {12, 0, 0, 0}}}

      iex> [conversion_function] = Ecto.Ldap.Adapter.loaders(Ecto.DateTime, Ecto.DateTime)
      iex> conversion_function.("20160202000000.000Z")
      { :ok, {{2016, 2, 2}, {0, 0, 0, 0}}}
      iex> conversion_function.('20160401123456.789Z')
      { :ok, {{2016, 4, 1}, {12, 34, 56, 789000}}}
      iex> conversion_function.('20160401123456Z')
      { :ok, {{2016, 4, 1}, {12, 34, 56, 0}}}
      iex> conversion_function.('201604011234Z')
      { :ok, {{2016, 4, 1}, {12, 34, 0, 0}}}
      iex> conversion_function.('2016040112Z')
      { :ok, {{2016, 4, 1}, {12, 0, 0, 0}}}


  String and binary types will take the first element if the underlying LDAP attribute
  supports multiple values.

  ### Examples

      iex> Ecto.Ldap.Adapter.loaders(:string, nil)
      [nil]

      iex> [conversion_function] = Ecto.Ldap.Adapter.loaders(:string, :string)
      iex> {:ok, "hello"} = conversion_function.("hello")
      { :ok, "hello"}
      iex> conversion_function.(nil)
      { :ok, nil}
      iex> conversion_function.([83, 195, 182, 114, 101, 110])
      { :ok, "Sören"}
      iex> conversion_function.(['Home, home on the range', 'where the deer and the antelope play'])
      { :ok, "Home, home on the range"}

      iex> [conversion_function] = Ecto.Ldap.Adapter.loaders(:binary, :binary)
      iex> {:ok, "hello"} = conversion_function.("hello")
      { :ok, "hello"}
      iex> conversion_function.(nil)
      { :ok, nil}
      iex> conversion_function.([[1,2,3,4,5], [6,7,8,9,10]])
      { :ok, <<1,2,3,4,5>>}

  Array values will be each be converted.

  ### Examples

      iex> [conversion_function] = Ecto.Ldap.Adapter.loaders({:array, :string}, {:array, :string})
      iex> conversion_function.(["hello", "world"])
      { :ok, ["hello", "world"]}


  """
  @spec loaders(Ecto.Type.primitive, Ecto.Type.t) :: [(term -> {:ok, term} | :error) | Ecto.Type.t]
  def loaders(:id, type), do: [type]
  def loaders(:integer, _type), do: [&load_integer/1]
  def loaders(_primitive, nil), do: [nil]
  def loaders(:string, _type), do: [&load_string/1]
  def loaders(:binary, _type), do: [&load_string/1]
  def loaders(:datetime, _type), do: [&load_date/1]
  def loaders(:naive_datetime, _type), do: [&load_date/1]
  def loaders({:array, :string}, _type), do: [&load_array/1]
  def loaders(_primitive, type), do: [type]

  def load_integer(value) do
    {:ok, trim_converted(convert_from_erlang(value))}
  end

  def load_string(value) do
    {:ok, trim_converted(convert_from_erlang(value))}
  end

  def load_array(array) do
    {:ok, convert_from_erlang(array)}
  end

  def load_date(value) do
    value
    |> to_string
    |> Timex.parse!("{ASN1:GeneralizedTime:Z}")
    |> Timex.Ecto.DateTime.dump
  end
end
