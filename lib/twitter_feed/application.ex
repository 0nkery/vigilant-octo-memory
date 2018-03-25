defmodule TwitterFeed.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      TwitterFeed.Repo,
      {Task.Supervisor, name: TwitterFeed.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: TwitterFeed.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
