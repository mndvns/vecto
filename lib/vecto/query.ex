defmodule Vecto.Query do
  @default_funcs [:one, :all, :get, :update, :insert, :changeset]

  defmacro __using__(opts) do
    except = Keyword.get(opts, :except, [])
    funcs = Keyword.get(opts, :only, @default_funcs) -- except

    quote location: :keep do
      alias __MODULE__, as: M
      alias Vecto.Repo, as: R
      import Ecto.Query, only: [from: 2]

      has? = &Enum.member?(unquote(funcs), &1)
      over = &defoverridable(Enum.map(&2, fn arity -> {&1, arity} end))
      over? = &Module.overridable?(M, {&1, &2})
      undef? = &(not(Module.defines?(M, {&1, &2}))) or over?.(&1, &2)
      undefs? = &Enum.all?(Enum.map(&2, fn arity -> undef?.(&1, arity) end))

      if has?.(:one) do
        if undefs?.(:one, [0, 1]) do
          def one(query \\ %{}), do: __one__(:one, query)
          over.(:one, [0, 1])
        end
        if undefs?.(:one!, [0, 1]) do
          def one!(query \\ %{}), do: __one__(:one!, query)
          over.(:one!, [0, 1])
        end
      end

      if has?.(:all) do
        if undefs?.(:all, [0, 1, 2]) do
          def all(query \\ %{}, limit \\ nil), do: __all__(:all, query, limit)
          over.(:all, [0, 1, 2])
        end
        if undefs?.(:all!, [0, 1, 2]) do
          def all!(query \\ %{}, limit \\ nil), do: __all__(:all!, query, limit)
          over.(:all!, [0, 1, 2])
        end
      end

      if has?.(:get) do
        if undefs?.(:get, [0, 1, 2]) do
          def get(query \\ %{}, limit \\ 1), do: __get__(false, query, limit)
          over.(:get, [0, 1, 2])
        end
        if undefs?.(:get!, [0, 1, 2]) do
          def get!(query \\ %{}, limit \\ 1), do: __get__(true, query, limit)
          over.(:get!, [0, 1, 2])
        end
      end

      if has?.(:update) do
        if undefs?.(:update, [2, 3]) do
          def update(struct, changeset, new \\ nil), do: __update__(:update, changeset, new)
          over.(:update, [2, 3])
        end
        if undefs?.(:update!, [2, 3]) do
          def update!(struct, changeset, new \\ nil), do: __update__(:update!, changeset, new)
          over.(:update!, [2, 3])
        end
      end

      if has?.(:insert) do
        if undef?.(:insert, 1) do
          def insert(changeset), do: __insert__(:insert, changeset)
          over.(:insert, [1])
        end
        if undef?.(:insert, 1) do
          def insert!(changeset), do: __insert__(:insert!, changeset)
          over.(:insert!, [1])
        end
      end

      if has?.(:one) or has?.(:get) do
        def __one__(func, map) when is_map(map), do: __one__(func, Enum.into(map, []))
        def __one__(func, id) when is_binary(id), do: __one__(func, [id: id])
        def __one__(func, kw), do: find(:one, kw, func, [from(u in M, where: ^kw, limit: 1)])
      end

      if has?.(:all) or has?.(:get) do
        def __all__(func, map, lim) when is_map(map), do: __all__(func, Enum.into(map, []), lim)
        def __all__(func, id, lim) when is_binary(id), do: __all__(func, [id: id], lim)
        def __all__(func, kw, nil), do: find({:all, nil}, kw, func, [from(u in M, where: ^kw)])
        def __all__(func, kw, lim), do: find({:all, lim}, kw, func, [from(u in M, where: ^kw, limit: ^lim)])
      end

      if has?.(:get) do
        def __get__(false, query, 1), do: __one__(:one, query)
        def __get__(true, query, 1), do: __one__(:one!, query)
        def __get__(false, query, limit), do: __all__(:all, query, limit)
        def __get__(true, query, limit), do: __all__(:all!, query, limit)
      end

      if has?.(:insert) do
        def __insert__(func, %{__struct__: Ecto.Changeset} = changeset) do
          RequestCache.clear()
          apply(R, func, [changeset])
        end

        def __insert__(func, %{__struct__: M} = struct) do
          __insert__(func, Map.from_struct(struct))
        end

        def __insert__(func, map) when is_map(map) do
          __insert__(func, Kernel.struct(M) |> changeset(map))
        end

        def __insert__(func, keywords) do
          __insert__(func, Enum.into(keywords, %{}))
        end
      end

      if has?.(:update) do
        def __update__(func, %{__struct__: Ecto.Changeset} = changeset) do
          RequestCache.clear()
          apply(R, func, [changeset])
        end

        def __update__(func, %{__struct__: M} = struct, new \\ nil) do
          [struct, map] = cond do
            is_nil(new)           -> [__one__(true, struct.id), Map.from_struct(struct)]
            is_struct(new)        -> [struct, Map.from_struct(new)]
            is_pure_map(new)      -> [struct, new]
            Keyword.keyword?(new) -> [struct, Enum.into(new, %{})]
          end

          __update__(func, changeset(struct, map))
        end
      end

      if has?.(:changeset) and undef?.(:changeset, 2) do
        def changeset(%{__struct__: M} = struct, params) do
          struct
          |> Ecto.Changeset.cast(params, M.__editable__())
          |> Ecto.Changeset.validate_required(params, M.__required__())
        end
        over.(:changeset, [2])
      end

      # checks the cache for the value. if it doesn't exist, then call the repo
      defp find(ident, query, func, args) do
        RequestCache.find(M, query, ident, fn _ -> apply(R, func, args) end)
      end

      defp is_pure_map(value), do: is_map(value) and not(Map.has_key?(value, :__struct__))
      defp is_struct(value), do: is_map(value) and Map.has_key?(value, :__struct__)
    end
  end
end
