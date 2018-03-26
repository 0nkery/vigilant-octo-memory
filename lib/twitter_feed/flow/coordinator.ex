defmodule TwitterFeed.Flow.CoordinatorState do
  defstruct accounts: [], consumers: []
end

defmodule TwitterFeed.Flow.Coordinator do
  @moduledoc """
  Creates new Producers and notifies Consumers about the new ones.
  """

  use GenServer

  alias TwitterFeed.Model.TwitterAccount
  alias TwitterFeed.Flow.CoordinatorState

  @default_consumer_count 10

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(_opts) do
    consumer_count =
      Application.get_env(:twitter_feed, TwitterFeed.Repo)
      |> Keyword.get(:pool_size, @default_consumer_count)

    consumers =
      Enum.map(0..consumer_count, fn _idx ->
        {:ok, consumer} =
          DynamicSupervisor.start_child(
            TwitterFeed.ConsumerSupervisor,
            TwitterFeed.Flow.TweetConsumer
          )

        consumer
      end)

    Process.send_after(self(), :update, 1)

    {:ok, %CoordinatorState{consumers: consumers}}
  end

  def handle_info(:update, state) do
    new_accounts = TwitterAccount.all()

    Enum.each(new_accounts, fn account ->
      if !Enum.member?(state.accounts, account) do
        {:ok, producer} =
          DynamicSupervisor.start_child(
            TwitterFeed.ProducerSupervisor,
            {TwitterFeed.Flow.TweetProducer, [account]}
          )

        notify_consumers_about_producer(state.consumers, producer)
      end
    end)

    Process.send_after(self(), :update, 1000 * 60)

    {:noreply, %{state | accounts: new_accounts}}
  end

  defp notify_consumers_about_producer(consumers, producer) do
    Enum.each(consumers, fn consumer ->
      {:ok, _tag} = GenStage.sync_subscribe(consumer, to: producer, cancel: :transient)
    end)
  end
end
