defmodule Vecto.Schema.Field do
  defstruct [
    name: nil,
    type: nil,
    default: nil,
    virtual: nil,
    editable: nil,
    required: nil,
    displayed: nil,
    primary_key: nil,
  ]
end
