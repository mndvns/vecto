use Mix.Config

config :vecto, ecto_repos: [Vecto.Repo]

if Mix.env() == :test do
  config :vecto, Vecto.Repo,
    adapter: Ecto.Adapters.Postgres,
    database: System.get_env("POSTGRES_DB") || "stagingDb",
    username: System.get_env("POSTGRES_USER") || "stagingUser",
    password: System.get_env("POSTGRES_PASSWORD") || "password",
    hostname: System.get_env("POSTGRES_HOST") || "localhost"
end
