use Mix.Config

config :twitter_feed, TwitterFeed.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "twitter_feed_repo",
  username: "postgres",
  password: "pass",
  hostname: "db",
  pool_size: 8

config :twitter_feed,
       ecto_repos: [TwitterFeed.Repo],
       twitter_client: TwitterFeed.TwitterClient,
       coordinator: TwitterFeed.Flow.Coordinator

config :twittex,
       consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
       consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET"),
       token: System.get_env("TWITTER_OWNER_TOKEN"),
       token_secret: System.get_env("TWITTER_OWNER_TOKEN_SECRET")

import_config "#{Mix.env()}.exs"
