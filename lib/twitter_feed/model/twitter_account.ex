defmodule TwitterFeed.Model.TwitterAccount do
  @moduledoc """
  Account holds data about Twitter account.
  """

  use Ecto.Schema

  schema "twitter_accounts" do
    has_many(:tweets, TwitterFeed.Model.Tweet)
  end
end
