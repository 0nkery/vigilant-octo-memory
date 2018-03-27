defmodule TwitterFeedTestCoordinator do
  use ExUnit.Case

  alias TwitterFeed.{Repo, Model.TwitterAccount}

  @twitter_accounts [
    %{id: 1}
  ]

  @one_more_twitter_account %TwitterAccount{id: 10}

  setup_all do
    Repo.insert_all(
      TwitterAccount,
      @twitter_accounts,
      on_conflict: :replace_all,
      conflict_target: :id
    )

    {:ok, client} = TwitterFeedTest.TwitterClient.start_link()
    {:ok, coordinator} = TwitterFeed.Flow.Coordinator.start_link([])

    Process.sleep(100)

    on_exit(fn ->
      Repo.delete_all(TwitterAccount, [])
    end)

    [client: client, coordinator: coordinator]
  end

  test "starts consumers as defined by DB pool_size variable" do
    consumers_count =
      Application.get_env(:twitter_feed, TwitterFeed.Repo)
      |> Keyword.get(:pool_size)

    children = DynamicSupervisor.count_children(TwitterFeed.ConsumerSupervisor)
    assert children.active == consumers_count
  end

  test "starts producer for every account in database" do
    children = DynamicSupervisor.count_children(TwitterFeed.ProducerSupervisor)
    assert children.active == Repo.aggregate(TwitterAccount, :count, :id)
  end

  test "updates producers from db", context do
    Repo.insert!(@one_more_twitter_account)

    send(context.coordinator, :update)
    Process.sleep(100)

    children = DynamicSupervisor.count_children(TwitterFeed.ProducerSupervisor)
    assert children.active == Repo.aggregate(TwitterAccount, :count, :id)
  end

  test "starts stream after producer is going to stop", context do
    :ok =
      TwitterFeed.Flow.Coordinator.notify_producer_stopping(
        context.coordinator,
        @one_more_twitter_account
      )

    Process.sleep(2000)

    [{:stream, user_ids} | nil] = TwitterFeedTest.TwitterClient.get_calls_for(context.coordinator)

    assert Enum.member?(user_ids, @one_more_twitter_account.id)
  end
end
