require Logger

defmodule TwitterFeed.Flow.TweetConsumer do
  @moduledoc """
  Consumes Tweets from producer and saves them to database.
  """

  use GenStage

  alias TwitterFeed.Model.Tweet

  def start_link(arg) do
    GenStage.start_link(__MODULE__, arg)
  end

  def init(_arg) do
    {:consumer, :ignore}
  end

  def handle_subscribe(:producer, options, _from, state) do
    Logger.info("Subscribing #{inspect(self())} with #{inspect(options)}")
    {:automatic, state}
  end

  def handle_events(tweets, _from, state) do
    Tweet.upsert_many!(tweets)
    {:noreply, [], state}
  end
end
