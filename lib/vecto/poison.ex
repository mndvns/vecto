defmodule Vecto.Poison do
  @moduledoc """
  A simple module for encoding models.
  """

  defmacro __using__(_opts) do
    import Vecto.Utils
    if !implemented?(Poison.Encoder) do
      quote do
        defimpl Poison.Encoder do
          def encode(value, opts) do
            module = unquote(__CALLER__.module)
            displayed = module.__displayed__()

            value
            |> Map.from_struct()
            |> Stream.filter(fn
              {k, _v} when is_binary(k) -> true
              {:href, nil} -> false
              {k, _v} -> Enum.member?(displayed, k)
              _ -> false
            end)
            |> Enum.into(%{})
            |> Poison.Encoder.Map.encode(opts)
          end
        end
      end
    end || nil
  end
end
