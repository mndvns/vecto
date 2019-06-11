defmodule Vecto.Utils do
  defmacro implemented?(prefix) do
    prefix = prefix |> Code.eval_quoted() |> elem(0)
    parts = __CALLER__.module |> Module.split()
    [prefix | parts] |> Module.concat() |> Code.ensure_loaded?()
  end
end
