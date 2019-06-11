defmodule Vecto.Enumerable do
  @moduledoc """
  A dumb generic `Enumerable` protocol implementation.
  """

  defmacro __using__(_opts) do
    import Vecto.Utils
    if !implemented?(Enumerable) do
      quote do
        defimpl Enumerable do
          defdelegate count(enum), to: Vecto.Enumerable
          defdelegate slice(enum), to: Vecto.Enumerable
          defdelegate map(enum, fun), to: Vecto.Enumerable
          defdelegate member?(enum, kv), to: Vecto.Enumerable
          defdelegate reduce(enum, acc, fun), to: Vecto.Enumerable
        end
      end
    end || nil
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
