require Logger

defmodule TwitterFeed.Flow.CoordinatorState do
  defstruct accounts: [],
            consumers: [],
            stream_for_accounts: [],
            previous_stream: nil,
            start_stream_timer: nil,
            stream_ref: nil
end

defmodule TwitterFeed.Flow.Coordinator do
  @moduledoc """
  Creates new Producers and notifies Consumers about the new ones.
  """

  use GenServer

  alias TwitterFeed.Model.TwitterAccount
  alias TwitterFeed.Flow.CoordinatorState

  @default_consumer_count 10
  @start_stream_interval 1000

  @twitter_client_impl Application.fetch_env!(:twitter_feed, :twitter_client)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Notifies coordinator that timeline for given account has been drained.
  Coordinator will try to start stream after some time.
  """
  @spec notify_timeline_drained(GenStage.stage(), TwitterAccount) :: :ok
  def notify_timeline_drained(coordinator, account) do
    GenServer.call(coordinator, {:timeline_drained, account})
  end

  def init(_opts) do
    consumer_count =
      Application.get_env(:twitter_feed, TwitterFeed.Repo)
      |> Keyword.get(:pool_size, @default_consumer_count)

    consumers =
      Enum.map(1..consumer_count, fn _idx ->
        {:ok, consumer} =
          DynamicSupervisor.start_child(
            TwitterFeed.ConsumerSupervisor,
            TwitterFeed.Flow.TweetConsumer
          )

        consumer
      end)

    schedule_update()

    {:ok, %CoordinatorState{consumers: consumers}}
  end

  def handle_call({:timeline_drained, account}, _from, state) do
    # Scheduling stream start only once after some timeout
    # to avoid connection churn if there are too many calls
    # during small time window
    if !is_nil(state.start_stream_timer) do
      Process.cancel_timer(state.start_stream_timer)
    end

    stream_for_accounts = [account | state.stream_for_accounts]

    {:reply, :ok,
     %{
       state
       | stream_for_accounts: stream_for_accounts,
         start_stream_timer: schedule_start_stream(@start_stream_interval)
     }}
  end

  # Look for new accounts in database and start pipeline for them
  def handle_info(:update, state) do
    new_accounts = TwitterAccount.all()

    Enum.each(new_accounts, fn account ->
      if !Enum.member?(state.accounts, account) do
        {:ok, producer} =
          DynamicSupervisor.start_child(
            TwitterFeed.ProducerSupervisor,
            {TwitterFeed.Flow.TweetTimelineProducer, [account, self()]}
          )

        subscribe(state.consumers, producer, cancel: :transient)
      end
    end)

    schedule_update(1000 * 60)

    {:noreply, %{state | accounts: new_accounts}}
  end

  def handle_info(:start_stream, state) do
    {:noreply, start_stream(state)}
  end

  # Monitoring stream - if it dies we start new one.
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    state =
      cond do
        ref == state.stream_ref ->
          state = %{state | previous_stream: nil}
          start_stream(state)

        true ->
          state
      end

    {:noreply, state}
  end

  @spec schedule_update(Integer.t() | nil) :: reference() | term()
  defp schedule_update(after_ms \\ nil) do
    case after_ms  do
      nil -> send(self(), :update)
      after_ms -> Process.send_after(self(), :update, after_ms)
    end
  end

  @spec schedule_start_stream(Integer.t()) :: reference()
  defp schedule_start_stream(after_ms) do
    Process.send_after(self(), :start_stream, after_ms)
  end

  # Given consumers are subscribed to given producer with passed opts.
  @spec subscribe(list(TwitterFeed.Flow.TweetConsumer), GenStage.stage(), Keyword.t()) :: :ok
  defp subscribe(consumers, producer, opts) do
    opts = Keyword.put(opts, :to, producer)

    Enum.each(consumers, fn consumer ->
      {:ok, _tag} = GenStage.sync_subscribe(consumer, opts)
    end)
  end

  # Starts Twitter Streaming API stream stopping previous stream to
  # avoid connection churn. So, there (almost) always exists one instance
  # of such a stream.
  defp start_stream(state) do
    if !is_nil(state.previous_stream) do
      GenStage.stop(state.previous_stream)
    end

    stream_account_ids = Enum.map(state.stream_for_accounts, fn account -> account.id end)
    {:ok, stream} = @twitter_client_impl.stream(stream_account_ids)
    ref = Process.monitor(stream)

    # Using :temporary because tweet stream is not very reliable
    # and can be restarted many times during application lifetime
    subscribe(state.consumers, stream, cancel: :temporary)

    %{state | previous_stream: stream, start_stream_timer: nil, stream_ref: ref}
  end
end
