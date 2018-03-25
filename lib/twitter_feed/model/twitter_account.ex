defmodule TwitterFeed.Model.TwitterAccount do
  @moduledoc """
  Account holds data about Twitter account.
  """

  alias TwitterFeed.Model.{Tweet, TwitterAccount}
  alias TwitterFeed.Repo

  use Ecto.Schema

  schema "twitter_accounts" do
    has_many(:tweets, Tweet)
  end

  @spec all() :: list(TwitterAccount)
  def all() do
    TwitterAccount |> Repo.all()
  end

  @spec latest_tweet(TwitterAccount) :: Tweet
  def latest_tweet(account) do
    Ecto.assoc(account, :tweets)
    |> Ecto.Query.last()
    |> Repo.one()
  end

  @spec first_tweet(TwitterAccount) :: Tweet
  def first_tweet(account) do
    Ecto.assoc(account, :tweets)
    |> Ecto.Query.first()
    |> Repo.one()
  end
end
