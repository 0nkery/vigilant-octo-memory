defmodule TwitterFeed.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      TwitterFeed.Repo,
      {Task.Supervisor, name: TwitterFeed.TaskSupervisor},
      TwitterFeed.TwitterClient.child_spec(),
      {TwitterFeed.Flow.TweetProducer, name: TwitterFeed.TweetProducer},
      TwitterFeed.Flow.TweetConsumer
    ]

    opts = [
      strategy: :one_for_one,
      name: TwitterFeed.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
