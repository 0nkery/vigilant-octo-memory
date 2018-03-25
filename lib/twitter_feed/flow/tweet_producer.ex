require Logger

defmodule TwitterFeed.Flow.TweetProducerState do
  @enforce_keys [:queue]
  defstruct [:queue, pending_demand: 0]
end

defmodule TwitterFeed.Flow.TweetProducer do
  @moduledoc """
  Streams Tweets from Twitter accounts listed in database.
  """

  alias TwitterFeed.Model.{TwitterAccount, Tweet}
  alias TwitterFeed.TwitterClient
  alias TwitterFeed.Flow.TweetProducerState

  use GenStage

  def start_link(options) do
    GenStage.start_link(__MODULE__, :ok, options)
  end

  def init(_arg) do
    queue = :queue.new()

    accounts = TwitterAccount.all()

    queue =
      Task.Supervisor.async_stream(TwitterFeed.TaskSupervisor, accounts, fn account ->
        save_tweets_from_timeline(account)
      end)
      |> Enum.flat_map(fn tweets -> tweets end)
      |> Enum.reduce(queue, fn tweet, queue -> :queue.in(tweet, queue) end)

    {:ok, tweet_stream} =
      Enum.map(accounts, fn account -> account.id end)
      |> TwitterClient.stream()

    {:producer_consumer, %TweetProducerState{queue: queue}, subscribe_to: [tweet_stream]}
  end

  def handle_events(tweets, _from, %TweetProducerState{queue: queue} = state) do
    queue = Enum.reduce(tweets, queue, fn tweet, queue -> :queue.in(tweet, queue) end)
    {:noreply, [], %{state | queue: queue}}
  end

  def handle_demand(incoming_demand, state) do
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

  @spec save_tweets_from_timeline(TwitterAccount) :: list(map())
  defp save_tweets_from_timeline(account) do
    first = TwitterAccount.first_tweet(account)
    latest = TwitterAccount.latest_tweet(account)

    new_tweets_before =
      Task.Supervisor.async(TwitterFeed.TaskSupervisor, fn ->
        get_tweets_before_first(account, first)
      end)

    new_tweets_after =
      Task.Supervisor.async(TwitterFeed.TaskSupervisor, fn ->
        get_tweets_after_latest(account, latest)
      end)

    Task.await(new_tweets_before, :infinity) ++ Task.await(new_tweets_after, :infinity)
  end

  @spec get_tweets_before_first(TwitterAccount, Tweet | Integer.t() | nil | map()) :: list(map())
  defp get_tweets_before_first(account, %Tweet{id: id}) do
    get_tweets_before_first(account, id)
  end

  defp get_tweets_before_first(account, nil) do
    get_tweets_before_first(account, nil)
  end

  defp get_tweets_before_first(account, %{"id" => id}) do
    get_tweets_before_first(account, id)
  end

  defp get_tweets_before_first(account, id) do
    {:ok, tweets} = TwitterClient.timeline_before(account.id, id)

    if Enum.count(tweets) == 0 do
      tweets
    else
      tweets ++ get_tweets_before_first(account, List.last(tweets))
    end
  end

  @spec get_tweets_after_latest(TwitterAccount, Tweet | Integer.t() | nil | map()) :: list(map())
  defp get_tweets_after_latest(account, %Tweet{id: id}) do
    get_tweets_after_latest(account, id)
  end

  defp get_tweets_after_latest(account, nil) do
    get_tweets_after_latest(account, nil)
  end

  defp get_tweets_after_latest(account, %{"id" => id}) do
    get_tweets_after_latest(account, id)
  end

  defp get_tweets_after_latest(account, id) do
    {:ok, tweets} = TwitterClient.timeline_after(account.id, id)

    if Enum.count(tweets) == 0 do
      tweets
    else
      tweets ++ get_tweets_after_latest(account, List.first(tweets))
    end
  end
end
