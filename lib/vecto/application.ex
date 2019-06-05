defmodule Vecto.Application do
  use Application

  def start(_, _) do
    Vecto.Application.Supervisor.start_link()
  end
end
