use Mix.Config

config :twitter_feed, TwitterFeed.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "twitter_feed_test_repo",
  hostname: "localhost",
  pool_size: 5

config :twitter_feed, twitter_client: TwitterFeedTest.TwitterClient
