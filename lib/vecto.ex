defmodule Vecto do
  defmacro __using__(opts \\ []) do
    quote location: :keep do
      use Vecto.Schema

      unquote(
        # by default, using this module will implement
        # commonly-used protocols and behaviours.
        if Keyword.get(opts, :protocols, true) do
          quote location: :keep do
            use Vecto.Poison
            use Vecto.Enumerable
            use DelegateAccess, to: Map, only: [fetch: 2, get_and_update: 3, pop: 2]
          end
        end
      )
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      use Vecto.Query, table: @model_table
    end
  end
end
