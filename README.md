# Vecto

Vecto is a utility wrapper for ecto models.

## Features

* wraps `Ecto.Schema` to give inline field options and improved reflection
* creates `Ecto.Repo` convenience methods (similar to [`Ecto.Rut`](https://github.com/sheharyarn/ecto_rut))
* implements `Enumerable` and `Poison.Encode` protocols as well as the `Access` behaviour
* all of the above are opt-in

## Schema

The schema interface mirrors `Ecto.Schema` without collisions.

```
defmodule User do
  use Vecto

  schema "users" do
    field :name, :string
  end
end
```

You can make fields required inline or make them uneditable (they
default to editable). Ecto's built-in field options like `virtual` and `default`
have not changed..

```
defmodule User do
  use Vecto

  schema "users" do
    field :name, :string, required: true
    field :password, :string, editable: false
    field :href, :string, virtual: true
  end
end
```

When encoding with `Poison`, Vecto removes any fields that have `displayed` set to false.

```
defmodule User do
  use Vecto

  schema "users" do
    field :name, :string, required: true
    field :password, :string, editable: false
    field :href, :string, virtual: true, displayed: false
  end
end
```

Now, when a `%User{}` is JSON encoded, the `href` key is not included.

## Querying *`TODO`*

## Casting and validation *`TODO`*

## Reflecting *`TODO`*

## Installation

```elixir
def deps do
  [
    {:vecto, "~> 0.1.0"}
  ]
end
```
