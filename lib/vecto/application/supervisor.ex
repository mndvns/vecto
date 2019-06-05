defmodule Vecto.Application.Supervisor do
  use Supervisor

  def start_link() do
    {:ok, _sup} = Supervisor.start_link(__MODULE__, [], name: :vecto_supervisor)
  end

  def init(_) do
    processes = [
      worker(Vecto.Repo, []),
      worker(RequestCache, [])
    ]

    {:ok, {{:one_for_one, 10, 10}, processes}}
  end
end
