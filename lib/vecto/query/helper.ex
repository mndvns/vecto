defmodule Vecto.Query.Helper do
  defmacro define({name, _, args}) do
    module = __CALLER__.module

    {args, pairs} = Enum.reduce(args, {[], []}, fn
      {:\\, _, [{name, _, _}, default]}, {args, pairs} -> {args, pairs ++ [{name, default}]}
      {name, _, _}, {args, pairs} -> {args ++ [name], pairs}
    end)

    keys = args ++ Enum.map(pairs, &elem(&1, 0))

    arity = length(keys)
    argn = length(args)

    vars = Enum.map(keys, &Macro.var(&1, nil))
    vals = Enum.map(pairs, &elem(&1, 1))

    Enum.map(argn..arity, fn n ->
      if not(Module.defines?(module, {name, n})) do
        nvars = Enum.take(vars, n)
        last? = n == arity
        quote do
          def unquote(name)(unquote_splicing(nvars)) do
            unquote(if last? do
              quote do: Vecto.Query.unquote(name)(__MODULE__, unquote_splicing(nvars))
            else
              nval = Enum.at(vals, argn - n)
              quote do: unquote(name)(unquote_splicing(nvars), unquote(nval))
            end)
          end
          defoverridable [{unquote(name), unquote(n)}]
        end
      end || nil
    end)
  end
end
