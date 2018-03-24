# Some accounts which post way too many tweets...
accounts = [
  %TwitterFeed.Model.TwitterAccount{twitter_id: 15518784},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 1367531},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 59804598},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 15007299},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 124172948},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 19286574},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 255409050},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 63299591},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 6529402},
  %TwitterFeed.Model.TwitterAccount{twitter_id: 15518000},
]

Enum.each(accounts, fn(acc) ->
  TwitterFeed.Repo.insert!(acc, on_conflict: :replace_all, conflict_target: :twitter_id)
end)
