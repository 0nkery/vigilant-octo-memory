defmodule TwitterFeed.Model.TwitterAccount do
  @moduledoc """
  Account holds data about Twitter account.
  """

  alias __MODULE__
  alias TwitterFeed.Repo

  use Ecto.Schema

  schema "twitter_accounts" do
    has_many(:tweets, TwitterFeed.Model.Tweet)
  end

  @spec all() :: list(TwitterAccount)
  def all() do
    Repo.all(TwitterAccount)
  end
end
