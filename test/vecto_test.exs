defmodule Test.Vecto do
  use ExUnit.Case

  defmodule User do
    use Vecto

    schema "users" do
      field(:name)
      field(:email)
    end
  end

  test "`Access`" do
    conf = %User{name: "mike", email: "example@mike.com"}
    assert "x", conf[:name]
    assert "y", conf[:email]
  end

  @tag :skip
  test "`Enumerable`" do
    conf = %User{name: "mike", email: "example@mike.com"}
    assert match?([__meta__: _, id: _, name: _, email: _], Enum.into(conf, []))
  end

  @tag :skip
  test "`Poison.Encoder`" do
    conf = %User{name: "mike", email: "example@mike.com"}
    encoded = Poison.encode(conf)
    assert match?({:ok, _}, encoded)
  end
end
