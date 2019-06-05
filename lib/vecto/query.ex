defmodule Vecto.Query do
  @default_funcs [:one, :all, :get, :update, :insert, :changeset]

  defmacro __using__(opts) do
    except = Keyword.get(opts, :except, [])
    funcs = Keyword.get(opts, :only, @default_funcs) -- except

    quote location: :keep do
      alias __MODULE__, as: M
      alias Vecto.Repo, as: R
      import Ecto.Query, only: [from: 2]
      import Vecto.Query

      over = &defoverridable(Enum.map(&2, fn arity -> {&1, arity} end))
      has? = &Enum.member?(unquote(funcs), &1)
      over? = &Module.overridable?(M, {&1, &2})
      undef? = &(not(Module.defines?(M, {&1, &2}))) or over?.(&1, &2)
      undefs? = &Enum.all?(Enum.map(&2, fn arity -> undef?.(&1, arity) end))

      if has?.(:one) do
        undefs?.(:one, 0..1) && def one(query \\ %{}), do: __one__(:one, query)
        undefs?.(:one!, 0..1) && def one!(query \\ %{}), do: __one__(:one!, query)
      end

      if has?.(:all) do
        undefs?.(:all, 0..2) && def all(query \\ %{}, limit \\ nil), do: __all__(:all, query, limit)
        undefs?.(:all!, 0..2) && def all!(query \\ %{}, limit \\ nil), do: __all__(:all!, query, limit)
      end

      if has?.(:get) do
        undefs?.(:get, 0..2) && def get(query \\ %{}, limit \\ 1), do: __get__(false, query, limit)
        undefs?.(:get!, 0..2) && def get!(query \\ %{}, limit \\ 1), do: __get__(true, query, limit)
      end

      if has?.(:update) do
        undefs?.(:update, 2..3) && def update(struct, changeset, new \\ nil), do: __update__(:update, changeset, new)
        undefs?.(:update!, 2..3) && def update!(struct, changeset, new \\ nil), do: __update__(:update!, changeset, new)
      end

      if has?.(:insert) do
        undef?.(:insert, 1) && def insert(changeset), do: __insert__(:insert, changeset)
        undef?.(:insert, 1) && def insert!(changeset), do: __insert__(:insert!, changeset)
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
        def __update__(func, query, new \\ nil)

        def __update__(func, %{__struct__: Ecto.Changeset} = changeset, _new) do
          RequestCache.clear()
          apply(R, func, [changeset])
        end

        def __update__(func, %{__struct__: M} = struct, new) do
          [struct, map] = cond do
            is_nil(new)           -> [__one__(true, struct.id), Map.from_struct(struct)]
            is_struct(new)        -> [struct, Map.from_struct(new)]
            is_pure_map(new)      -> [struct, new]
            Keyword.keyword?(new) -> [struct, Enum.into(new, %{})]
          end

          __update__(func, changeset(struct, map))
        end

        def __update__(func, query, new) do
          __update__(func, changeset(%{}, query), new)
        end
      end


      if has?.(:changeset) and undef?.(:changeset, 2) do
        def changeset(struct, params \\ nil)
        def changeset(%{__struct__: __MODULE__} = struct, params) do
          struct
          |> Ecto.Changeset.cast(params, __editable__())
          |> Ecto.Changeset.validate_required(__required__())
        end

        def changeset(query, params) do
          changeset(one(query), params)
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
