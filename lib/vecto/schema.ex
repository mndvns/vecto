defmodule Vecto.Schema do
  @moduledoc """
  A wrapper around `Ecto.Schema` that provides inline field
  options and better schema reflection.
  """

  @keys [:default, :virtual, :editable, :required, :displayed, :primary_key]

  defmacro __using__(_opts) do
    quote location: :keep do
      Module.register_attribute(__MODULE__, :ecto_primary_keys, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :ecto_fields, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :ecto_field_sources, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :ecto_assocs, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :ecto_embeds, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :ecto_raw, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :ecto_autogenerate, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :ecto_autoupdate, accumulate: true, persist: true)

      @primary_key {:id, :binary_id, autogenerate: true}
      @timestamps_opts inserted_at: :created_at
      @foreign_key_type :binary_id
      @schema_prefix nil
      @field_source_mapper & &1
      @ecto_autogenerate_id nil

      import Ecto.Schema, only: [embedded_schema: 1]
      import unquote(__MODULE__), only: [schema: 2]

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro schema(name, do: {:__block__, _env, blocks}) do
    conf = Enum.reduce(@keys, %{blocks: []}, &Map.put(&2, &1, []))

    conf =
      Enum.reduce(blocks, conf, fn
        {:field, _env, [name | args]}, acc ->
          {type, _} = List.pop_at(args, 0, :string)
          {opts, _} = List.pop_at(args, 1, [])

          {opts, acc} = pop_opt(:editable, true, name, opts, acc)
          {opts, acc} = pop_opt(:required, false, name, opts, acc)
          {opts, acc} = pop_opt(:displayed, true, name, opts, acc)

          acc = opt_value(:default, :none, name, opts, acc)
          acc = opt_flag(:virtual, false, name, opts, acc)
          acc = opt_flag(:primary_key, false, name, opts, acc)

          block = quote(do: field(unquote_splicing([name, type, opts])))
          update_in(acc[:blocks], &[block | &1 || []])

        block, acc ->
          update_in(acc[:blocks], &[block | &1 || []])
      end)
      |> Enum.map(fn {key, list} -> {key, Enum.reverse(list)} end)

    Module.put_attribute(__CALLER__.module, :model_table, name)

    for key <- @keys, do: Module.put_attribute(__CALLER__.module, :"model_#{key}", conf[key])

    quote([location: :keep], do: Ecto.Schema.schema(unquote(to_string(name)), do: unquote(conf[:blocks])))
  end

  defmacro schema(name, do: block) do
    quote [location: :keep], do: schema(unquote(name), do: unquote({:__block__, nil, [block]}))
  end

  defmacro __before_compile__(_env) do
    get_attr = &Module.get_attribute(__CALLER__.module, &1)
    put_attr = &Module.put_attribute(__CALLER__.module, &1, &2)

    [
      # merge alternate attributes with model-defined attributes.
      # for example, if a module defines `@editabled_keys`, we
      # must merge them with the `@model_editable` attribute
      # that was set in the `schema/2` macro.
      for key <- @keys do
        list1 = get_attr.(:"#{key}_keys") || []
        list2 = get_attr.(:"model_#{key}") || []
        merged = Enum.uniq(list1 ++ list2) |> Enum.sort()
        put_attr.(:"model_#{key}", merged)
        quote(do: def(unquote(:"__#{key}__")(), do: unquote(merged)))
      end,

      # define aggregated reflecting function `__field__(name)`.
      for {name, type} <- get_attr.(:ecto_fields) do
        flags = for key <- @keys -- [:default] do
          attrs = get_attr.(:"model_#{key}")
          member? = Enum.member?(attrs, name)
          {key, member?}
        end

        attrs = [
          name: name,
          type: type,
          default: get_attr.(:model_default)[name]
        ] ++ flags

        quote(do: def(__field__(unquote(name)), do: unquote(attrs)))
      end,

      # return non-defined fields with `nil`
      quote(do: def(__field__(_name), do: nil))
    ]
  end

  defp opt_flag(key, default, name, opts, acc) do
    case Keyword.get(opts, key, default) do
      true -> Map.update(acc, key, [name], &[name | &1])
      false -> acc
    end
  end

  defp opt_value(key, default, name, opts, acc) do
    case Keyword.get(opts, key, default) do
      :none -> acc
      value -> Map.update(acc, key, [{name, value}], &Keyword.put(&1, name, value))
    end
  end

  defp pop_opt(key, default, name, opts, acc) do
    case Keyword.pop(opts, key, default) do
      {true, opts} -> {opts, Map.update(acc, key, [name], &[name | &1])}
      {false, opts} -> {opts, acc}
    end
  end
end
