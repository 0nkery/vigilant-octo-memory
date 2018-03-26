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

  @spec upsert_many!(list(map())) :: Integer.t()
  def upsert_many!(tweets) do
    tweets = Enum.map(tweets, fn tweet ->
      %Tweet{
        id: tweet_map["id"],
        data: tweet_map,
        twitter_account_id: tweet_map["user"]["id"]
      }
    end)

    Repo.insert_all(Tweet, tweets, on_conflict: :replace_all, conflicting_target: :id)
  end
end
