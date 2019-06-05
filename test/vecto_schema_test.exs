defmodule Test.Vecto.Schema do
  use ExUnit.Case, async: true

  describe "`Ecto.Schema` macros" do
    defmodule E do
      use Vecto.Schema

      schema "some_table" do
        field(:a, :integer, null: false)
        field(:b, :string, [])
        field(:c, :binary_id)
        timestamps()
      end
    end

    test "function as expected" do
      assert E.__schema__(:fields), [:a, :b, :c]
      assert struct(E, []) |> is_map()
    end
  end

  describe "`Ecto.Schema` options" do
    defmodule O do
      use Vecto.Schema

      schema "_" do
        field(:a, :string, default: "x")
        field(:b, :string, default: "y", virtual: true)
        field(:c, :string, primary_key: true)
      end
    end

    test "are stored on the module" do
      assert O.__default__(), a: "x", b: "y", c: nil
      assert O.__virtual__(), [:b]
      assert O.__primary_key__(), [:c]
    end
  end

  describe "additional options" do
    defmodule L do
      use Vecto.Schema

      schema "_" do
        field(:a, :string)
        field(:b, :string)
      end
    end

    test "fallback to defaults" do
      assert L.__editable__(), [:a, :b]
      assert L.__displayed__(), [:a, :b]
      assert L.__required__(), []
    end

    defmodule C do
      use Vecto.Schema

      schema "_" do
        field(:a, :string, required: true, displayed: true)
        field(:b, :string, editable: false)
        field(:c, :string, editable: false, displayed: false)
      end
    end

    test "can be overriden" do
      assert C.__required__(), [:a]
      assert C.__editable__(), [:a]
      assert C.__displayed__(), [:a, :b]
    end
  end
end
