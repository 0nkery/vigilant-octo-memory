defmodule TwitterFeed.Repo.Migrations.CreateTwitterAccount do
  use Ecto.Migration

  def change do
    create table(:twitter_accounts)
  end
end
