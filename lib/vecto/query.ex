defmodule Vecto.Query do
  defmacro __using__(opts) do
    model = Keyword.get(opts, :model, __CALLER__.module)
    table = Keyword.get(opts, :table)

    quote location: :keep do
      @table unquote(table)
      @model unquote(model)

      alias __MODULE__, as: M
      alias Vecto.Repo, as: R
      import Ecto.Query, only: [from: 2]

      def one(query), do: do_one(:one, query)
      def one!(query), do: do_one(:one!, query)

      def all(query, limit \\ nil), do: do_all(:all, query, limit)
      def all!(query, limit \\ nil), do: do_all(:all!, query, limit)

      def get(query, limit \\ 1), do: do_get(false, query, limit)
      def get!(query, limit \\ 1), do: do_get(true, query, limit)

      def update(struct, changeset, new \\ nil), do: do_update(:update, changeset, new)
      def update!(struct, changeset, new \\ nil), do: do_update(:update!, changeset, new)

      def insert(changeset), do: do_insert(:insert, changeset)
      def insert!(changeset), do: do_insert(:insert!, changeset)

      defp do_get(false, query, 1), do: one(query)
      defp do_get(true, query, 1), do: one!(query)
      defp do_get(false, query, limit), do: all(query, limit)
      defp do_get(true, query, limit), do: all!(query, limit)

      defp do_one(func, map) when is_map(map), do: do_one(func, Enum.into(map, []))
      defp do_one(func, id) when is_binary(id), do: do_one(func, [id: id])
      defp do_one(func, kw), do: find(:one, kw, func, [from(u in M, where: ^kw, limit: 1)])

      defp do_all(func, map, lim) when is_map(map), do: do_all(func, Enum.into(map, []), lim)
      defp do_all(func, id, lim) when is_binary(id), do: do_all(func, [id: id], lim)
      defp do_all(func, kw, nil), do: find({:all, nil}, kw, func, [from(u in M, where: ^kw)])
      defp do_all(func, kw, lim), do: find({:all, lim}, kw, func, [from(u in M, where: ^kw, limit: ^lim)])

      def do_insert(func, %{__struct__: Ecto.Changeset} = changeset) do
        RequestCache.clear()
        apply(R, func, [changeset])
      end

      def do_insert(func, %{__struct__: @model} = struct) do
        do_insert(func, Map.from_struct(struct))
      end

      def do_insert(func, map) when is_map(map) do
        do_insert(func, Kernel.struct(@model) |> changeset(map))
      end

      def do_insert(func, keywords) do
        do_insert(func, ExUtils.Keyword.to_map(keywords))
      end

      defp do_update(func, %{__struct__: Ecto.Changeset} = changeset) do
        RequestCache.clear()
        apply(R, func, [changeset])
      end

      defp do_update(func, %{__struct__: @model} = struct, new \\ nil) do
        [struct, map] =
          cond do
          is_nil(new)               -> [get!(struct.id), Map.from_struct(struct)]
          ExUtils.is_struct?(new)   -> [struct, Map.from_struct(new)]
          ExUtils.is_pure_map?(new) -> [struct, new]
          Keyword.keyword?(new)     -> [struct, ExUtils.Keyword.to_map(new)]
        end

        do_update(func, changeset(struct, map))
      end

      def changeset(struct, params) do
        struct
        |> Ecto.Changeset.cast(params, @model.__editable__())
        |> Ecto.Changeset.validate_required(params, @model.__required__())
      end

      defoverridable [changeset: 2]

      # checks the cache for the value. if it doesn't exist, then call the repo
      defp find(ident, query, func, args) do
        RequestCache.find(@model, query, ident, fn _ -> apply(R, func, args) end)
      end
    end
  end
end
