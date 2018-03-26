defmodule TwitterFeed.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      TwitterFeed.Repo,
      {Task.Supervisor, name: TwitterFeed.TaskSupervisor},
      TwitterFeed.TwitterClient.child_spec(),
      {TwitterFeed.Flow.TweetProducer, name: TwitterFeed.TweetProducer}
    ]

    consumer_count =
      Application.get_env(:twitter_feed, TwitterFeed.Repo)
      |> Keyword.get(:pool_size, 10)

    children = children ++ List.duplicate(TwitterFeed.Flow.TweetConsumer, consumer_count)

    opts = [
      strategy: :one_for_one,
      name: TwitterFeed.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
