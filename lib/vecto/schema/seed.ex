defmodule Vecto.Schema.Seed do
  def type(:integer), do: int()
  def type(:float), do: float()
  def type(:string), do: binary()
  def type(:boolean), do: boolean()
  def type(:naive_datetime), do: psql_tstamp()
  def type(:email), do: email()
  def type(:date), do: date()
  def type(:password), do: password()
  def type(:binary_id), do: uuid()

  def uuid() do
    Ecto.UUID.generate()
  end

  def int(max \\ 100) do
    :rand.uniform(max)
  end

  def float(max \\ 100) do
    :rand.uniform(max) / 100
  end

  def binary(size \\ 12) do
    Base.url_encode64(:crypto.strong_rand_bytes(size))
  end

  def boolean() do
    :rand.uniform() > 1
  end

  def psql_tstamp() do
    Ecto.DateTime.utc() |> Ecto.DateTime.to_string()
  end

  def date() do
    Date.utc_today() |> Date.to_string()
  end

  def email() do
    "#{binary()}@#{binary(6)}.com"
  end

  def password() do
    binary() <> "Sj1#"
  end

  def schema(module, params, keys) do
    params = Vecto.Query.Utils.sanitize(params, module)
    param_keys = Keyword.keys(params)

    required_keys = module.__required__()

    (keys ++ required_keys)
    |> Stream.uniq()
    |> Stream.filter(fn key ->
      Enum.find(param_keys, &(&1 != key))
    end)
    |> Stream.map(fn k ->
      {k, module.__type__(k) |> type()}
    end)
    |> Enum.into([])
    # |> module.insert()
  end
end
