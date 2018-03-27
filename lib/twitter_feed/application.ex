defmodule TwitterFeed.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      TwitterFeed.Repo,
      {Task.Supervisor, name: TwitterFeed.TaskSupervisor},
      TwitterFeed.TwitterClient.child_spec(),
      Supervisor.child_spec(
        {DynamicSupervisor, name: TwitterFeed.ProducerSupervisor, strategy: :one_for_one},
        id: :producer_supervisor
      ),
      Supervisor.child_spec(
        {DynamicSupervisor, name: TwitterFeed.ConsumerSupervisor, strategy: :one_for_one},
        id: :consumer_supervisor
      ),
      {TwitterFeed.Flow.Coordinator, name: TwitterFeed.Coordinator}
    ]

    opts = [
      strategy: :one_for_one,
      name: TwitterFeed.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
