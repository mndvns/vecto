defmodule Vecto.Query.Utils do
  alias Vecto.Schema.Field

  def sanitize(%{__struct__: module} = struct) do
    sanitize(struct, module)
  end

  def sanitize(nil, module) do
    [] |> sanitize(module)
  end
  def sanitize(id, module) when is_binary(id) do
    [id: id] |> sanitize(module)
  end
  def sanitize(%{__struct__: module} = struct, module) do
    struct |> Map.from_struct() |> sanitize(module)
  end
  def sanitize(map, module) when is_map(map) do
    map |> Enum.into([]) |> sanitize(module)
  end
  def sanitize(list, module) when is_list(list) do
    list
    |> Enum.reduce([], &sanitize(&1, module, &2))
    |> Enum.reverse()
  end

  defp sanitize({key, nil}, _module, acc) do
    acc
  end
  defp sanitize({key, value}, module, acc) when is_atom(key) do
    case {module.__field__(key), value} do
      {nil, _value} -> nil
      {%Field{virtual: true}, _value} -> nil
      # {%Field{default: ^value}, ^value} -> nil
      {%Field{type: :naive_datetime}, %Ecto.DateTime{} = value} -> Ecto.DateTime.to_string(value)
      {%Field{type: :naive_datetime}, %NaiveDateTime{} = value} -> to_string(value)
      {_field, value} -> value
    end
    |> case do
      nil -> acc
      value -> [{key, value} | acc]
    end
  end
  defp sanitize({key, value}, module, acc) when is_binary(key) do
    String.to_existing_atom(key)
  catch
    _, _ -> acc
  else
    atom -> sanitize({atom, value}, module, acc)
  end
  defp sanitize(_kv, _module, acc) do
    acc
  end
end
