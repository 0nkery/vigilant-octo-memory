defmodule TwitterFeed.Model.Tweet do
  @moduledoc """
  Tweet holds data about tweet and user it belongs to.
  """

  use Ecto.Schema

  schema :tweets do
    field(:data, :map)
    belongs_to(:twitter_account, TwitterFeed.Model.Account)
  end
end
