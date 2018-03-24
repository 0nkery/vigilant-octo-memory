defmodule TwitterFeed.Model.Account do
  @moduledoc """
  Account holds data about Twitter account.
  """

  use Ecto.Schema

  schema :twitter_accounts do
    field(:twitter_id, :integer)
    has_many(:tweets, TwitterFeed.Model.Tweet)
  end
end
