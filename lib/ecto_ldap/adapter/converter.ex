defmodule Ecto.Ldap.Adapter.Converter do

  @spec convert_from_erlang(any) :: any
  def convert_from_erlang(list=[head|_]) when is_list(head), do: Enum.map(list, &convert_from_erlang/1)
  def convert_from_erlang(string) when is_list(string), do: :binary.list_to_bin(string)
  def convert_from_erlang(other), do: other

  @spec convert_to_erlang(list | String.t | atom | number) :: list | number
  def convert_to_erlang(list) when is_list(list), do: Enum.map(list, &convert_to_erlang/1)
  def convert_to_erlang(string) when is_binary(string), do: :binary.bin_to_list(string)
  def convert_to_erlang(atom) when is_atom(atom), do: atom |> Atom.to_string |> convert_to_erlang
  def convert_to_erlang(num) when is_number(num), do: num

  @spec trim_converted(any) :: any
  def trim_converted(list) when is_list(list), do: hd(list)
  def trim_converted(other), do: other

end
