defmodule TwitterFeed.Model.TwitterAccount do
  @moduledoc """
  Account holds data about Twitter account.
  """

  alias TwitterFeed.Model.{Tweet, TwitterAccount}
  alias TwitterFeed.Repo

  use Ecto.Schema

  import Ecto.Query

  schema "twitter_accounts" do
  end

  @spec all() :: list(TwitterAccount)
  def all() do
    TwitterAccount |> Repo.all()
  end

  @spec latest_tweet(TwitterAccount) :: Tweet
  def latest_tweet(account) do
    from(t in Tweet, where: t.twitter_account_id == ^account.id)
    |> Ecto.Query.last()
    |> Repo.one()
  end

  @spec first_tweet(TwitterAccount) :: Tweet
  def first_tweet(account) do
    from(t in Tweet, where: t.twitter_account_id == ^account.id)
    |> Ecto.Query.first()
    |> Repo.one()
  end
end
