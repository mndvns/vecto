defmodule Vecto.Query do
  require Ecto.Query
  import Vecto.Query.Utils

  @default_definitions [:all, :one, :get, :update, :upsert, :insert, :delete, :changeset]

  defmacro __using__(opts \\ []) do
    define_only = Keyword.get(opts, :define_only, @default_definitions)
    define_except = Keyword.get(opts, :define_except, [])
    definitions = define_only -- define_except
    quote do
      unless Module.defines?(__MODULE__, {:preloads, 0}) do
        def preloads, do: []
        defoverridable preloads: 0
      end

      import Vecto.Query.Helper, only: [define: 1]

      define? = &Enum.member?(unquote(definitions), &1)

      define?.(:all) && define(all(query \\ %{}, limit \\ nil))

      define?.(:one) && define(one(query \\ %{}))
      define?.(:one) && define(one!(query \\ %{}))

      define?.(:get) && define(get(query \\ %{}, limit \\ 1))
      define?.(:get) && define(get!(query \\ %{}, limit \\ 1))

      define?.(:update) && define(update(struct, params \\ nil))
      define?.(:update) && define(update!(struct, params \\ nil))

      define?.(:upsert) && define(upsert(struct, params \\ %{}))
      define?.(:upsert) && define(upsert!(struct, params \\ %{}))

      define?.(:insert) && define(insert(params \\ %{}))
      define?.(:insert) && define(insert!(params \\ %{}))

      define?.(:delete) && define(delete(params))
      define?.(:delete) && define(delete!(params))

      define?.(:changeset) && define(changeset(struct, params))
    end
  end

  def all(module, where \\ %{}, limit \\ nil), do: do_get(:all, false, module, where, limit)

  def one(module, where \\ %{}), do: do_get(:one, false, module, where, 1)
  def one!(module, where \\ %{}), do: do_get(:one, true, module, where, 1)

  def get(module, where \\ %{}, limit \\ 1), do: do_get(:get, false, module, where, limit)
  def get!(module, where \\ %{}, limit \\ 1), do: do_get(:get, true, module, where, limit)

  def update(module, where \\ %{}, params \\ nil), do: do_update(:update, module, where, params)
  def update!(module, where \\ %{}, params \\ nil), do: do_update(:update!, module, where, params)

  def upsert(module, where \\ %{}, params \\ nil), do: do_upsert(false, module, where, params)
  def upsert!(module, where \\ %{}, params \\ nil), do: do_upsert(true, module, where, params)

  def insert(module, params \\ %{}), do: do_insert(:insert, module, params)
  def insert!(module, params \\ %{}), do: do_insert(:insert!, module, params)

  def delete(module, struct), do: do_delete(false, module, struct)
  def delete!(module, struct), do: do_delete(true, module, struct)

  def changeset(module, %{__struct__: module} = struct, params) do
    params = params |> sanitize(module) |> Enum.into(%{})
    IO.inspect UPSERT: {struct, params}
    struct
    |> Ecto.Changeset.cast(params, module.__editable__())
    |> Ecto.Changeset.validate_required(module.__required__())
  end
  def changeset(module, where, params) do
    changeset(module, one!(module, where), params)
  end

  defp do_update(func, module, %Ecto.Changeset{} = changeset, new) do
    result = apply(Vecto.Repo, func, [changeset])
    case result do
      %{__struct__: ^module} -> store_update_struct(result)
      {:ok, result} -> store_update_struct(result)
      {:error, _} -> nil
    end
    result
  end
  defp do_update(func, module, %{__struct__: module, id: id} = struct, nil) do
    do_update(func, module, one!(module, id), Map.from_struct(struct))
  end
  defp do_update(func, module, %{__struct__: module} = struct, new) do
    do_update(func, module, changeset(module, struct, new), new)
  end
  defp do_update(func, module, where, new) do
    do_update(func, module, one!(module, where), new)
  end

  defp do_upsert(bang?, module, where, params) do
    where = sanitize(where, module)
    |> Enum.into(%{})
    |> case do
        %{id: id} -> %{id: id}
        other -> other
      end

    case one(module, where) do
      %{__struct__: ^module} = struct->
        func = if bang?, do: :update!, else: :update
        do_update(func, module, struct, params)
      _other ->
        func = if bang?, do: :insert!, else: :insert
        merged = Keyword.merge(sanitize(where, module), sanitize(params, module))
        do_insert(func, module, merged)
    end
  end

  defp do_insert(func, module, %Ecto.Changeset{data: %{__struct__: module}} = changeset) do
    result = apply(Vecto.Repo, func, [changeset])
    case result do
      %{__struct__: _} = result -> store_put_struct(result)
      {:ok, result} -> store_put_struct(result)
      {:error, _} -> nil
    end
    result
  end
  defp do_insert(func, module, new) do
    do_insert(func, module, changeset(module, Kernel.struct(module, []), new))
  end

  defp do_get(:get, bang?, module, where, 1), do: do_get(:one, bang?, module, where, 1)
  defp do_get(:get, bang?, module, where, nil), do: do_get(:one, bang?, module, where, 1)
  defp do_get(:get, bang?, module, where, limit), do: do_get(:all, bang?, module, where, limit)
  defp do_get(func, bang?, module, where, limit) do
    where = sanitize(where, module)
    stored_map = Enum.into(where, %{}) # for easy deletion and updating later
    func = if bang?, do: :"#{func}!", else: func
    RequestCache.get_or_store({module, func, stored_map, limit}, fn ->
      query = Ecto.Query.from(u in module, select: u, where: ^where, preload: ^module.preloads())
      query = if module.__schema__(:type, :deleted_at), do: Ecto.Query.where(query, [u], is_nil(u.deleted_at)), else: query
      query = if is_nil(limit), do: query, else: Ecto.Query.limit(query, ^limit)
      result = apply(Vecto.Repo, func, [query])
      # store each record if we returned a list
      if is_list(result), do: Enum.map(result, &store_update_struct/1)
      result
    end)
  end

  defp do_delete(bang?, module, %{__struct__: module} = struct) do
    deleted_at? = module.__schema__(:type, :deleted_at)
    if deleted_at? do
      changeset(module, struct, %{})
      |> Ecto.Changeset.put_change(:deleted_at, NaiveDateTime.utc_now())
      |> Vecto.Repo.update!()
    else
      Vecto.Repo.delete!(struct)
    end
  catch
    exception when bang? -> raise exception
    _exception when not(bang?) -> {:error, :cannot_delete}
  else
    _struct ->
      store_delete_struct(struct)
      if bang?, do: struct, else: {:ok, struct}
  end
  defp do_delete(true, module, where) do
    do_delete(true, module, one!(module, where))
  end
  defp do_delete(false, module, where) do
    case one(module, where) do
      nil -> {:error, :cannot_find}
      struct -> do_delete(false, module, struct)
    end
  end

  defp store_put_struct(%{__struct__: module, id: id} = struct) do
    RequestCache.put({module, :one, %{id: id}, 1}, struct)
  end
  defp store_put_struct(%{__struct__: _module} = struct) do
    struct
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
end
