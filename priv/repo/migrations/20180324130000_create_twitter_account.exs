defmodule TwitterFeed.Repo.Migrations.CreateTwitterAccount do
  use Ecto.Migration

  def change do
    create table(:twitter_accounts) do
      add :twitter_id, :integer
    end

    create unique_index(:twitter_accounts, [:twitter_id])
  end
end
