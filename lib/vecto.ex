defmodule Vecto do
  defmacro __using__(opts \\ []) do
    quote location: :keep do
      use Vecto.Schema, unquote(opts)
      use Vecto.Query, unquote(opts)

      # by default, using this module will implement
      # commonly-used protocols and behaviours.
      @vecto_protocols unquote(Keyword.get(opts, :protocols, true))

      @before_compile Vecto
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      if @vecto_protocols do
        use Vecto.Inspect
        use Vecto.Poison
        use Vecto.Enumerable
        use DelegateAccess, to: Map, only: [fetch: 2, get_and_update: 3, pop: 2]
      end
    end
  end
end
