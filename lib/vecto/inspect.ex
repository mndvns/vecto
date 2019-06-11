defmodule Vecto.Inspect do
  defmacro __using__(_opts) do
    module = __CALLER__.module

    quote do
      defimpl Inspect do
        import Inspect.Algebra

        @module unquote(inspect(module))

        def inspect(struct, opts) do
          body = struct
          |> Map.drop([:__meta__, :__struct__])
          |> Enum.into([])
          |> Vecto.Inspect.sort()
          |> to_doc(opts)

          concat(["##{@module}<", body, ">"])
        end
      end
    end
  end

  def sort(kw) do
    Enum.sort(kw, fn
      {:id, _}, _ -> true
      _, {:id, _} -> false
      {k1, _}, {k2, _} ->
        k1s = String.ends_with?(to_string(k1), "_at")
        k2s = String.ends_with?(to_string(k2), "_at")
        cond do
          k1s and not(k2s) -> false
          k2s and not(k1s) -> true
          true -> k1 <= k2
        end
    end)
  end
end
