defmodule Test.Vecto.Query do
  use ExUnit.Case

  defmodule User do
    use Vecto.Schema
    use Vecto.Query, table: :users

    schema "users" do
      field :name
      field :email
    end
  end
end
