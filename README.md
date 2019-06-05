# Vecto

Vecto is a utility wrapper for ecto models.

## Features

* wraps `Ecto.Schema` to give inline field options and improved reflection
* creates `Ecto.Repo` convenience methods (similar to [`Ecto.Rut`](https://github.com/sheharyarn/ecto_rut))
* implements `Enumerable` and `Poison.Encode` protocols as well as the `Access` behaviour
* all of the above are opt-in

## Usage

The schema interface mirrors `Ecto.Schema` without collisions.

```
defmodule MyModel do
  use Vecto

  schema "my_table" do
    field :id
    field :name
  end
end
```

`TODO: add examples`

## Installation

```elixir
def deps do
  [
    {:vecto, "~> 0.1.0"}
  ]
end
```
