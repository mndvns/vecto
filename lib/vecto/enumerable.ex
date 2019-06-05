defmodule Vecto.Enumerable do
  @moduledoc """
  A dumb generic `Enumerable` protocol implementation.
  """

  defmacro __using__(_opts) do
    quote bind_quoted: [module: __MODULE__] do
      defimpl Enumerable do
        defdelegate count(enum), to: module
        defdelegate slice(enum), to: module
        defdelegate map(enum, fun), to: module
        defdelegate member?(enum, kv), to: module
        defdelegate reduce(enum, acc, fun), to: module
      end
    end
  end

  def count(map), do: {:ok, Map.from_struct(map) |> map_size()}

  def member?(map, {key, value}), do: {:ok, match?(%{^key => ^value}, map)}
  def member?(_map, _other), do: {:ok, false}

  def slice(map) do
    map = Map.from_struct(map)
    {:ok, map_size(map), &Enumerable.List.slice(:maps.to_list(map), &1, &2)}
  end

  def map(enumerable, fun) do
    reducer = fn x, acc -> {:cont, [fun.(x) | acc]} end
    Enumerable.reduce(enumerable, {:cont, []}, reducer) |> elem(1) |> :lists.reverse()
  end

  def reduce(%{__struct__: _} = enum, acc, fun), do: Map.from_struct(enum) |> reduce(acc, fun)
  def reduce(map, acc, fun) when is_map(map), do: Enum.into(map, []) |> reduce(acc, fun)
  def reduce(_list, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(list, &1, fun)}
  def reduce([], {:cont, acc}, _fun), do: {:done, acc}
  def reduce([head | tail], {:cont, acc}, fun), do: reduce(tail, fun.(head, acc), fun)
end
