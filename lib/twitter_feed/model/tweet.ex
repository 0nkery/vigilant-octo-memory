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

  @spec upsert!(map()) :: Tweet
  def upsert!(tweet_map) do
    tweet = %Tweet{
      id: tweet_map.id,
      data: tweet_map,
      twitter_account_id: tweet_map.user.id
    }

    Repo.insert!(tweet, on_conflict: :replace_all, conflicting_target: :id)
  end
end
