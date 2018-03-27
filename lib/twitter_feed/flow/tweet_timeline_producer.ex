require Logger

defmodule TwitterFeed.Flow.TweetTimelineProducerState do
  @retry_step 1000
  @starting_retry_coefficient 10
  @finish_retry_coefficient 3
  @max_retry_after 1000 * 60 * 15

  @enforce_keys [:queue, :account, :coordinator]
  defstruct [
    :queue,
    :account,
    :coordinator,
    oldest: :start,
    newest: :start,
    retry_after: 0,
    going_to_stop: false,
    pending_demand: 0
  ]

  def update_retry_after(state) do
    retry_after = state.retry_after + @retry_step
    retry_after =
      cond do
        retry_after < @max_retry_after / 2 ->
          retry_after * @starting_retry_coefficient
        retry_after > @max_retry_after ->
          @max_retry_after
        true ->
          retry_after * @finish_retry_coefficient
      end

    %{state | retry_after: retry_after}
  end
end

defmodule TwitterFeed.Flow.TweetTimelineProducer do
  @moduledoc """
  Streams Tweets from given Twitter account.
  """

  alias TwitterFeed.Model.TwitterAccount
  alias TwitterFeed.Flow.TweetTimelineProducerState

  use GenStage

  @twitter_client_impl Application.fetch_env!(:twitter_feed, :twitter_client)
  @coordinator_impl Application.fetch_env!(:twitter_feed, :coordinator)

  def start_link([account, coordinator]) do
    GenStage.start_link(__MODULE__, {account, coordinator})
  end

  def init({account, coordinator}) do
    Logger.info("Streaming tweet timeline for #{inspect(account)}")

    state = %TweetTimelineProducerState{
      queue: :queue.new(),
      account: account,
      coordinator: coordinator
    }

    {:producer, state}
  end

  def handle_info(:fetch_tweets, state) do
    state = state |> fetch_tweets() |> schedule_fetch()
    dispatch_events(state, state.pending_demand, [])
  end

  def handle_demand(incoming_demand, state) do
    state = state |> schedule_fetch()
    dispatch_events(state, incoming_demand + state.pending_demand, [])
  end

  defp schedule_fetch(state) do
    Process.send_after(self(), :fetch_tweets, state.retry_after)
    state
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

  defp fetch_tweets(%TweetTimelineProducerState{going_to_stop: true} = state) do
    if :queue.len(state.queue) == 0 do
      GenStage.stop(self())
    end

    state
  end

  defp fetch_tweets(
         %TweetTimelineProducerState{oldest: :stop, newest: :stop, going_to_stop: false} = state
       ) do
    Logger.info("Switching to Twitter Stream API for #{inspect(state.account)}")

    :ok = @coordinator_impl.notify_producer_stopping(state.coordinator, state.account)

    %{state | going_to_stop: true}
  end

  defp fetch_tweets(%TweetTimelineProducerState{oldest: :start, newest: :start} = state) do
    first_tweet = TwitterAccount.first_tweet(state.account)
    latest_tweet = TwitterAccount.latest_tweet(state.account)

    with {nil, nil} <- {first_tweet, latest_tweet},
         {:ok, [first | _rest] = tweets} <- @twitter_client_impl.timeline(state.account.id) do
      queue = Enum.reduce(tweets, state.queue, fn tweet, queue -> :queue.in(tweet, queue) end)

      %{
        state
        | queue: queue,
          oldest: List.last(tweets)["id"] - 1,
          newest: first["id"]
      }
    else
      {first, latest} ->
        state = %{state | oldest: first.id - 1, newest: latest.id}
        fetch_tweets(state)

      {:ok, []} ->
        %{state | oldest: :stop, newest: :stop}

      {:error, reason} ->
        state = TweetTimelineProducerState.update_retry_after(state)

        Logger.error(
          "Tweet fetch has failed with reason #{inspect(reason)}. Retrying in #{state.retry_after} ms"
        )

        state
    end
  end

  defp fetch_tweets(%TweetTimelineProducerState{oldest: oldest, newest: newest} = state) do
    state =
      with oldest when is_integer(oldest) <- oldest,
           {:ok, [_first | _rest] = tweets} <-
             @twitter_client_impl.timeline(state.account.id, max_id: oldest) do
        queue = Enum.reduce(tweets, state.queue, fn tweet, queue -> :queue.in(tweet, queue) end)

        %{
          state
          | queue: queue,
            oldest: List.last(tweets)["id"] - 1
        }
      else
        :stop ->
          state

        {:ok, []} ->
          %{state | oldest: :stop}

        {:error, reason} ->
          state = TweetTimelineProducerState.update_retry_after(state)

          Logger.error(
            "Tweet fetch has failed with reason #{inspect(reason)}. Retrying in #{
              state.retry_after
            } ms"
          )

          state
      end

    state =
      with newest when is_integer(newest) <- newest,
           {:ok, [first | _rest] = tweets} <-
             @twitter_client_impl.timeline(state.account.id, since_id: newest) do
        queue = Enum.reduce(tweets, state.queue, fn tweet, queue -> :queue.in(tweet, queue) end)

        %{
          state
          | queue: queue,
            newest: first["id"]
        }
      else
        :stop ->
          state

        {:ok, []} ->
          %{state | newest: :stop}

        {:error, reason} ->
          state = TweetTimelineProducerState.update_retry_after(state)

          Logger.error(
            "Tweet fetch has failed with reason #{inspect(reason)}. Retrying in #{
              state.retry_after
            } ms"
          )

          state
      end

    state
  end
end
