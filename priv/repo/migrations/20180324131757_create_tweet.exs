defmodule TwitterFeed.Repo.Migrations.CreateTweet do
  use Ecto.Migration

  def change do
    create table(:tweets) do
      add :data, :map
      add :account_id, references(:twitter_accounts)
    end
  end
end