defmodule Vecto.Query do
  require Ecto.Query

  def one(module, where \\ %{}), do: find(:one, false, module, where, 1)
  def one!(module, where \\ %{}), do: find(:one, true, module, where, 1)

  def all(module, where \\ %{}, limit \\ nil), do: find(:all, false, module, where, limit)
  def all!(module, where \\ %{}, limit \\ nil), do: find(:all, true, module, where, limit)

  def get(module, where \\ %{}, limit \\ 1), do: find(:get, false, module, where, limit)
  def get!(module, where \\ %{}, limit \\ 1), do: find(:get, true, module, where, limit)

  def update(module, where \\ %{}, params \\ nil), do: change(:update, module, where, params)
  def update!(module, where \\ %{}, params \\ nil), do: change(:update!, module, where, params)

  def upsert(module, where \\ %{}, params \\ nil), do: change_or_create(false, module, where, params)
  def upsert!(module, where \\ %{}, params \\ nil), do: change_or_create(true, module, where, params)

  def insert(module, params \\ %{}), do: create(:insert, module, params)
  def insert!(module, params \\ %{}), do: create(:insert!, module, params)

  def delete(module, struct), do: remove(:delete, module, struct)
  def delete!(module, struct), do: remove(:delete!, module, struct)

  def changeset(module, %{__struct__: module} = struct, params) do
    params = params |> sanitize(module) |> Enum.into(%{})
    struct
    |> Ecto.Changeset.cast(params, module.__editable__())
    |> Ecto.Changeset.validate_required(module.__required__())
  end
  def changeset(module, where, params) do
    changeset(module, one!(module, where), params)
  end

  defp change(func, module, %Ecto.Changeset{} = changeset, _new) do
    result = apply(Vecto.Repo, func, [changeset])
    case result do
      %{__struct__: ^module} -> store_update_struct(result)
      {:ok, result} -> store_update_struct(result)
      {:error, _} -> nil
    end
    result
  end
  defp change(func, module, %{__struct__: module, id: id} = struct, nil) do
    change(func, module, one!(module, id), Map.from_struct(struct))
  end
  defp change(func, module, %{__struct__: module} = struct, new) do
    change(func, module, changeset(module, struct, new), new)
  end
  defp change(func, module, where, new) do
    change(func, module, one!(module, where), new)
  end

  defp change_or_create(bang, module, where, params) do
    where = sanitize(where, module)
    |> Enum.into(%{})
    |> case do
        %{id: id} -> %{id: id}
        other -> other
      end

    case one(module, where) do
      %{__struct__: ^module} = struct->
        func = if bang, do: :update!, else: :update
        change(func, module, struct, params)
      _other ->
        func = if bang, do: :insert!, else: :insert
        merged = Keyword.merge(sanitize(where, module), sanitize(params, module))
        create(func, module, merged)
    end
  end

  defp create(func, module, %Ecto.Changeset{data: %{__struct__: module}} = changeset) do
    result = apply(Vecto.Repo, func, [changeset])
    case result do
      %{__struct__: ^module} -> store_put_struct(result)
      {:ok, result} -> store_put_struct(result)
      {:error, _} -> nil
    end
    result
  end
  defp create(func, module, new) do
    create(func, module, changeset(module, Kernel.struct(module), new))
  end

  defp find(:get, bang, module, where, nil), do: find(:one, bang, module, where, 1)
  defp find(:get, bang, module, where, limit), do: find(:all, bang, module, where, limit)
  defp find(func, bang, module, where, limit) do
    where = sanitize(where, module)
    stored_map = Enum.into(where, %{}) # for easy deletion and updating later
    func = if bang, do: :"#{func}!", else: func
    RequestCache.get_or_store({module, func, stored_map, limit}, fn ->
      query = Ecto.Query.from(u in module, where: ^where)
      query = if is_nil(limit), do: query, else: Ecto.Query.limit(query, ^limit)
      result = apply(Vecto.Repo, func, [query])
      # store each record if we returned a list
      if is_list(result), do: Enum.map(result, &store_update_struct/1)
      result
    end)
  end

  defp remove(func, module, %{__struct__: module} = struct) do
    result = apply(Vecto.Repo, func, [struct])
    case result do
      {:ok, _} -> store_delete_struct(struct)
      {:error, _} -> nil
    end
    result
  end
  defp remove(func, module, where) do
    remove(func, module, one!(module, where))
  end

  defp store_put_struct(%{__struct__: module, id: id} = struct) do
    RequestCache.put({module, :one, %{id: id}, 1}, struct)
  end

  defp store_update_struct(%{__struct__: _, id: id} = struct) do
    RequestCache.all()
    |> Enum.filter(fn {_key, value} -> is_map(value) and Map.get(value, :id) == id end)
    |> Enum.each(fn {key, _} -> RequestCache.put(key, struct) end)
    store_put_struct(struct)
  end

  defp store_delete_struct(%{__struct__: _, id: id}) do
    RequestCache.all()
    |> Enum.filter(fn {_key, value} -> is_map(value) and Map.get(value, :id) == id end)
    |> Enum.each(fn {key, _} -> RequestCache.delete(key) end)
  end

  defp sanitize(id, module) when is_binary(id) do
    [id: id] |> sanitize(module)
  end
  defp sanitize(%{__struct__: module} = struct, module) do
    struct |> Map.from_struct() |> sanitize(module)
  end
  defp sanitize(enum, module) do
    reject_keys = [:__meta__ | module.__virtual__()]
    Enum.reject(enum, fn {key, value} -> is_nil(value) or key in reject_keys end)
  end

  @default_definitions [:one, :all, :get, :update, :upsert, :insert, :delete, :changeset]

  defmacro __using__(opts) do
    define_except = Keyword.get(opts, :define_except, [])
    define_only = Keyword.get(opts, :define_only, @default_definitions)
    definitions = define_only -- define_except

    quote location: :keep do
      alias __MODULE__, as: M
      alias Vecto.Repo, as: R
      alias Vecto.Query, as: Q

      should_define? = &Enum.member?(unquote(definitions), &1)

      if should_define?.(:one) do
        def one(query \\ %{}), do: Q.one(M, query)
        def one!(query \\ %{}), do: Q.one!(M, query)
      end

      if should_define?.(:all) do
        def all(query \\ %{}, limit \\ nil), do: Q.all(M, query, limit)
        def all!(query \\ %{}, limit \\ nil), do: Q.all!(M, query, limit)
      end

      if should_define?.(:get) do
        def get(query \\ %{}, limit \\ 1), do: Q.get(M, query, limit)
        def get!(query \\ %{}, limit \\ 1), do: Q.get!(M, query, limit)
      end

      if should_define?.(:update) do
        def update(struct, params \\ nil), do: Q.update(M, struct, params)
        def update!(struct, params \\ nil), do: Q.update!(M, struct, params)
      end

      if should_define?.(:upsert) do
        def upsert(struct, params \\ nil), do: Q.upsert(M, struct, params)
        def upsert!(struct, params \\ nil), do: Q.upsert!(M, struct, params)
      end

      if should_define?.(:insert) do
        def insert(params \\ %{}), do: Q.insert(M, params)
        def insert!(params \\ %{}), do: Q.insert(M, params)
      end

      if should_define?.(:delete) do
        def delete(struct), do: Q.delete(M, struct)
        def delete!(struct), do: Q.delete!(M, struct)
      end

      if should_define?.(:changeset) do
        def changeset(struct, params), do: Q.changeset(M, struct, params)
        def changeset!(struct, params), do: Q.changeset(M, struct, params)
      end
    end
  end
end
