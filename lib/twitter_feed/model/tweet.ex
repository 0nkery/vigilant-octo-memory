defmodule TwitterFeed.Model.Tweet do
  @moduledoc """
  Tweet holds data about tweet and user it belongs to.
  """

  alias TwitterFeed.Model.{TwitterAccount, Tweet}
  alias TwitterFeed.Repo

  use Ecto.Schema

  schema "tweets" do
    field(:data, :map)
    belongs_to(:twitter_account, TwitterAccount)
  end

  @spec latest_for_account(TwitterAccount) :: {Tweet}
  def latest_for_account(account) do
    q =
      from(
        x in Tweet,
        where: x.twitter_account_id = ^account.id,
        order_by: [desc: x.id],
        limit: 1
      )

    Repo.one(q)
  end

  @spec upsert!(map()) :: {Tweet}
  def upsert!(tweet_map) do
    tweet = %Tweet{
      id: tweet_map.id,
      data: tweet_map,
      twitter_account_id: tweet_map.user.id
    }

    Repo.insert!(tweet)
  end
end
