use Mix.Config

config :twitter_feed, TwitterFeed.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "twitter_feed_repo",
  username: "postgres",
  password: "pass",
  hostname: "db",
  pool_size: 8

config :twitter_feed, ecto_repos: [TwitterFeed.Repo]
