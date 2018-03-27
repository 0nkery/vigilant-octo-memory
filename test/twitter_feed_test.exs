defmodule TwitterFeedTest do
  use ExUnit.Case

  alias TwitterFeed.{Repo, Model.TwitterAccount, Model.Tweet}
  alias TwitterFeedTest.Fixture

  setup_all do
    Repo.insert_all(
      TwitterAccount,
      Fixture.twitter_accounts(),
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

  test "coordinator starts consumers as defined by DB pool_size variable" do
    consumers_count =
      Application.get_env(:twitter_feed, TwitterFeed.Repo)
      |> Keyword.get(:pool_size)

    children = DynamicSupervisor.count_children(TwitterFeed.ConsumerSupervisor)
    assert children.active == consumers_count
  end

  test "coordinator starts producer for every account in database" do
    children = DynamicSupervisor.count_children(TwitterFeed.ProducerSupervisor)
    assert children.active == Repo.aggregate(TwitterAccount, :count, :id)
  end

  test "coordinator updates producers from db", context do
    Repo.insert!(Fixture.one_more_twitter_account())

    send(context.coordinator, :update)
    Process.sleep(100)

    children = DynamicSupervisor.count_children(TwitterFeed.ProducerSupervisor)
    assert children.active == Repo.aggregate(TwitterAccount, :count, :id)
  end

  test "coordinator starts stream after producer is going to stop", context do
    :ok =
      TwitterFeed.Flow.Coordinator.notify_timeline_drained(
        context.coordinator,
        Fixture.one_more_twitter_account()
      )

    Process.sleep(2000)

    [{:stream, user_ids} | nil] = TwitterFeedTest.TwitterClient.get_calls_for(context.coordinator)

    assert Enum.member?(user_ids, Fixture.one_more_twitter_account.id)
  end

  test "consumers are writing to db" do
    assert Enum.count(Fixture.tweets()) == Repo.aggregate(Tweet, :count, :id)
  end
end
