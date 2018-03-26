defmodule TwitterFeed.Repo.Migrations.CreateTweet do
  use Ecto.Migration

  def change do
    create table(:tweets) do
      add :data, :map
      add :twitter_account_id, :bigint
    end
  end
end
