defmodule TwitterFeed.Flow.TweetConsumer do
  @moduledoc """
  Consumes Tweets from producer and saves them to database.
  """

  use ConsumerSupervisor

  def start_link(arg) do
    ConsumerSupervisor.start_link(__MODULE__, arg)
  end

  def init(_arg) do
    children = [
      %{
        id: TwitterFeed.TweetHandler,
        start: {TwitterFeed.TweetHandler, :start_link, []},
        restart: :transient
      }
    ]

    opts = [
      strategy: :one_for_one,
      subscribe_to: [
        TwitterFeed.TweetProducer
      ]
    ]

    ConsumerSupervisor.init(children, opts)
  end
end

defmodule TwitterFeed.Flow.TweetHandler do
  def start_link(tweet) do
    Task.start_link(fn ->
      TwitterFeed.Model.Tweet.upsert!(tweet)
    end)
  end
end
