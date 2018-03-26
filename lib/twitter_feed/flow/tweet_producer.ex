require Logger

defmodule TwitterFeed.Flow.TweetProducerState do
  @retry_step 1000
  @retry_coefficient 2

  @enforce_keys [:queue, :account]
  defstruct [
    :queue,
    :account,
    oldest: :start,
    newest: :start,
    retry_after: 0,
    subscribed_to_stream: false,
    pending_demand: 0
  ]

  def update_retry_after(state) do
    %{state | retry_after: @retry_coefficient * state.retry_after + @retry_step}
  end
end

defmodule TwitterFeed.Flow.TweetProducer do
  @moduledoc """
  Streams Tweets from given Twitter account.
  """

  alias TwitterFeed.Model.TwitterAccount
  alias TwitterFeed.TwitterClient
  alias TwitterFeed.Flow.TweetProducerState

  use GenStage

  def start_link([account]) do
    GenStage.start_link(__MODULE__, account)
  end

  def init(account) do
    Logger.info("Handling tweets for #{inspect(account)}")

    state = %TweetProducerState{
      queue: :queue.new(),
      account: account
    }

    {:producer_consumer, state}
  end

  def handle_info(:fetch_tweets, state) do
    state = fetch_tweets(state)
    Logger.debug("State for #{inspect(self())} after fetching tweets - #{inspect(state)}")
    {:noreply, state}
  end

  def handle_events(tweets, _from, %TweetProducerState{queue: queue} = state) do
    queue = Enum.reduce(tweets, queue, fn tweet, queue -> :queue.in(tweet, queue) end)
    {:noreply, [], %{state | queue: queue}}
  end

  def handle_demand(incoming_demand, state) do
    demand = incoming_demand + state.pending_demand

    Logger.info("Demand for #{inspect(self())} - #{demand}")

    if demand > 2 * :queue.len(state.queue) do
      Process.send_after(self(), :fetch_tweets, state.retry_after)
    end

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

  defp fetch_tweets(
         %TweetProducerState{oldest: :stop, newest: :stop, subscribed_to_stream: false} = state
       ) do
    Logger.info("Switching to Twitter Stream API for #{inspect(state.account)}")

    {:ok, tweet_stream} = TwitterClient.stream([state.account.id])
    {:ok, _tag} = GenStage.sync_subscribe(tweet_stream, cancel: :transient)

    %{state | subscribed_to_stream: true}
  end

  defp fetch_tweets(%TweetProducerState{oldest: :start, newest: :start} = state) do
    first_tweet = TwitterAccount.first_tweet(state.account)
    latest_tweet = TwitterAccount.latest_tweet(state.account)

    case {first_tweet, latest_tweet} do
      {nil, nil} ->
        case TwitterClient.timeline(state.account.id) do
          {:ok, []} ->
            %{state | oldest: :stop, newest: :stop}

          {:ok, tweets} ->
            queue =
              Enum.reduce(tweets, state.queue, fn tweet, queue -> :queue.in(tweet, queue) end)

            %{
              state
              | queue: queue,
                oldest: List.last(tweets)["id"],
                newest: List.first(tweets)["id"]
            }

          {:error, :service_unavailable} ->
            TweetProducerState.update_retry_after(state)
        end

      {first, latest} ->
        state = %{state | oldest: first.id, newest: latest.id}
        fetch_tweets(state)
    end
  end

  defp fetch_tweets(%TweetProducerState{oldest: oldest, newest: newest} = state)
       when is_integer(oldest) and is_integer(newest) do
    oldest_response = TwitterClient.timeline(state.account.id, max_id: oldest)

    state =
      case oldest_response do
        {:ok, []} ->
          %{state | oldest: :stop}

        {:ok, tweets} ->
          queue = Enum.reduce(tweets, state.queue, fn tweet, queue -> :queue.in(tweet, queue) end)

          %{
            state
            | queue: queue,
              oldest: List.last(tweets)["id"]
          }

        {:error, :service_unavailable} ->
          TweetProducerState.update_retry_after(state)
      end

    newest_response = TwitterClient.timeline(state.account.id, since_id: newest)

    state =
      case newest_response do
        {:ok, []} ->
          %{state | newest: :stop}

        {:ok, tweets} ->
          queue = Enum.reduce(tweets, state.queue, fn tweet, queue -> :queue.in(tweet, queue) end)

          %{
            state
            | queue: queue,
              oldest: List.first(tweets)["id"]
          }

        {:error, :service_unavailable} ->
          TweetProducerState.update_retry_after(state)
      end

    state
  end
end
