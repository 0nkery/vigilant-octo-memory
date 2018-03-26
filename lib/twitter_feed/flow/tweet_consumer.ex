defmodule TwitterFeed.Flow.TweetConsumer do
  @moduledoc """
  Consumes Tweets from producer and saves them to database.
  """

  use GenStage

  alias TwitterFeed.Model.Tweet

  def start_link(arg) do
    GenStage.start_link(__MODULE__, arg)
  end

  def subscribe_to(consumer, producer) do
    GenServer.call(consumer, {:subscribe, producer})
  end

  def init(_arg) do
    {:consumer, :ignore}
  end

  def handle_events(tweets, _from, state) do
    Tweet.upsert_many!(tweets)

    {:noreply, [], state}
  end

  def handle_call({:subscribe, producer}, _from, state) do
    {:ok, _tag} = GenStage.sync_subscribe(producer, cancel: :transient)
    {:reply, :ok, [], state}
  end
end
