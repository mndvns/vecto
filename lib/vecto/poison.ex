defmodule Vecto.Poison do
  @moduledoc """
  A simple module for encoding models.
  """

  defmacro __using__(_opts) do
    quote do
      defimpl Poison.Encoder do
        def encode(value, opts) do
          mod = unquote(__CALLER__.module)

          value
          |> Map.drop([:__meta__, :__struct__])
          |> Map.take(mod.__displayed__())
          |> Poison.Encoder.Map.encode(opts)
        end
      end
    end
  end
end
