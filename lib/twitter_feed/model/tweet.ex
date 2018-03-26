require Logger

defmodule TwitterFeed.Model.Tweet do
  @moduledoc """
  Tweet holds data about tweet and user it belongs to.
  """

  alias TwitterFeed.Model.Tweet
  alias TwitterFeed.Repo

  use Ecto.Schema

  schema "tweets" do
    field(:data, :map)
    field(:twitter_account_id, :integer)
  end

  @spec upsert_many!(list(map())) :: Integer.t()
  def upsert_many!(tweets) do
    tweets =
      Enum.map(tweets, fn tweet ->
        %{
          id: tweet["id"],
          data: tweet,
          twitter_account_id: tweet["user"]["id"]
        }
      end)

    Repo.insert_all(Tweet, tweets)
  end
end
