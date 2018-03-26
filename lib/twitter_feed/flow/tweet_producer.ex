require Logger

defmodule TwitterFeed.Flow.TweetProducerState do
  @enforce_keys [:queue, :account]
  defstruct [
    :queue,
    :account,
    oldest: :start,
    newest: :start,
    subscribed_to_stream: false,
    pending_demand: 0
  ]
end

defmodule TwitterFeed.Flow.TweetProducer do
  @moduledoc """
  Streams Tweets from given Twitter account.
  """

  alias TwitterFeed.Model.{TwitterAccount, Tweet}
  alias TwitterFeed.TwitterClient
  alias TwitterFeed.Flow.TweetProducerState

  use GenStage

  def start_link(account, options) do
    IO.inspect(account)
    IO.inspect(options)
    GenStage.start_link(__MODULE__, account, options)
  end

  def init(account) do
    state = %TweetProducerState{
      queue: :queue.new(),
      account: account
    }

    state = fetch_tweets(state)

    {:producer_consumer, state}
  end

  def handle_events(tweets, _from, %TweetProducerState{queue: queue} = state) do
    queue = Enum.reduce(tweets, queue, fn tweet, queue -> :queue.in(tweet, queue) end)
    {:noreply, [], %{state | queue: queue}}
  end

  def handle_demand(incoming_demand, state) do
    demand = incoming_demand + state.pending_demand
    state = if demand > 2 * :queue.len(state.queue), do: fetch_tweets(state), else: state
    dispatch_events(state, incoming_demand + state.pending_demand, [])
  end

  defp dispatch_events(state, 0, tweets) do
    {:noreply, Enum.reverse(tweets), %{state | pending_demand: 0}}
  end

  defp dispatch_events(state, demand, tweets) do
    case :queue.out(state.queue) do
      {{:value, tweet}, queue} ->
        dispatch_events(%{state | queue: queue}, demand - 1, [tweet | tweets])

      {:empty, queue} ->
        {:noreply, Enum.reverse(tweets), %{state | queue: queue, pending_demand: demand}}
    end
  end

  defp fetch_tweets(%TweetProducerState{subscribed_to_stream: true} = state), do: state
  defp fetch_tweets(%TweetProducerState{oldest: :stop, newest: :stop, subscribed_to_stream: false} = state) do
    {:ok, tweet_stream} = TwitterClient.stream([state.account.id])
    {:ok, _tag} = GenStage.sync_subscribe(tweet_stream, cancel: :transient)

    %{state | subscribed_to_stream: true}
  end
  defp fetch_tweets(state) do
    {state, oldest} = fetch_oldest_tweets(state)
    {state, newest} = fetch_newest_tweets(state)
    queue = Enum.reduce(oldest, state.queue, fn tweet, queue -> :queue.in(tweet, queue) end)
    queue = Enum.reduce(newest, queue, fn tweet, queue -> :queue.in(tweet, queue) end)

    %{state | queue: queue}
  end

  defp fetch_oldest_tweets(%TweetProducerState{oldest: :stop} = state), do: {state, []}
  defp fetch_oldest_tweets(%TweetProducerState{oldest: oldest} = state) do
    oldest = case oldest do
      :start -> TwitterAccount.first_tweet(state.account)
      oldest when is_map(oldest) -> oldest
    end
    tweets = get_tweets_before(state.account, oldest)

    state = if Enum.count(tweets) == 0 do
      %{state | oldest: :stop}
    else
      %{state | oldest: List.last(tweets)}
    end

    {state, tweets}
  end

  defp fetch_newest_tweets(%TweetProducerState{newest: :stop} = state), do: {state, []}
  defp fetch_newest_tweets(%TweetProducerState{newest: newest} = state) do
    newest = case newest do
      :start -> TwitterAccount.latest_tweet(state.account)
      newest when is_map(newest) -> newest
    end
    tweets = get_tweets_after(state.account, newest)

    state = if Enum.count(tweets) == 0 do
      %{state | newest: :stop}
    else
      %{state | newest: List.first(tweets)}
    end

    {state, tweets}
  end

  @spec get_tweets_before(TwitterAccount, Tweet | Integer.t() | nil | map()) :: list(map())
  defp get_tweets_before(account, %Tweet{id: id}), do: get_tweets_before(account, id)
  defp get_tweets_before(account, nil), do: get_tweets_before(account, nil)
  defp get_tweets_before(account, %{"id" => id}), do: get_tweets_before(account, id)
  defp get_tweets_before(account, id) do
    {:ok, tweets} = TwitterClient.timeline_before(account.id, id)
    tweets
  end

  @spec get_tweets_after(TwitterAccount, Tweet | Integer.t() | nil | map()) :: list(map())
  defp get_tweets_after(account, %Tweet{id: id}), do: get_tweets_after(account, id)
  defp get_tweets_after(account, nil), do: get_tweets_after(account, nil)
  defp get_tweets_after(account, %{"id" => id}), do: get_tweets_after(account, id)
  defp get_tweets_after(account, id) do
    {:ok, tweets} = TwitterClient.timeline_after(account.id, id)
    tweets
  end
end
