Application.ensure_all_started(:ecto)

children = [
  TwitterFeed.Repo,
  {Task.Supervisor, name: TwitterFeed.TaskSupervisor},
  Supervisor.child_spec(
    {DynamicSupervisor, name: TwitterFeed.ProducerSupervisor, strategy: :one_for_one},
    id: :producer_supervisor
  ),
  Supervisor.child_spec(
    {DynamicSupervisor, name: TwitterFeed.ConsumerSupervisor, strategy: :one_for_one},
    id: :consumer_supervisor
  )
]

opts = [
  strategy: :one_for_one,
  name: TwitterFeed.Supervisor
]

Supervisor.start_link(children, opts)
ExUnit.start()

defmodule TwitterFeedTest.Fixture do
  def tweets do
    [
      %{
        "id" => 1,
        "user" => %{
          "id" => 1
        }
      },
      %{
        "id" => 2,
        "user" => %{
          "id" => 1
        }
      }
    ]
  end

  def twitter_accounts() do
    [
      %{id: 1}
    ]
  end

  def one_more_twitter_account() do
    %TwitterFeed.Model.TwitterAccount{id: 10}
  end
end

defmodule TwitterFeedTest.TwitterClient do
  def start_link() do
    Agent.start(fn -> %{} end, name: __MODULE__)
  end

  def timeline(user_id, options \\ []) do
    called_by = self()

    Agent.update(__MODULE__, fn calls ->
      {_old, calls} =
        Map.get_and_update(calls, called_by, fn calls_list ->
          {calls_list, [{:timeline, user_id, options} | calls_list]}
        end)

      calls
    end)

    tweets =
      case options do
        [] -> TwitterFeedTest.Fixture.tweets()
        _other -> []
      end

    {:ok, tweets}
  end

  def stream(user_ids) do
    called_by = self()

    Agent.update(__MODULE__, fn calls ->
      {_old, calls} =
        Map.get_and_update(calls, called_by, fn calls_list ->
          {calls_list, [{:stream, user_ids} | calls_list]}
        end)

      calls
    end)

    TwitterFeedTest.TweetProducer.start_link()
  end

  def get_calls_for(pid) do
    Agent.get(__MODULE__, fn calls ->
      Map.get(calls, pid)
    end)
  end
end

defmodule TwitterFeedTest.TweetProducer do
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:producer, :ignore}
  end

  def handle_demand(_demand, state) do
    {:noreply, TwitterFeedTest.Fixture.tweets(), state}
  end
end
