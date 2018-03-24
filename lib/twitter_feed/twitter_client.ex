defmodule TwitterFeed.TwitterClient do
  @moduledoc """
  Twitter client built on top of Twittex.Client.Base.

  It uses pool for requests and provides back-off functionality
  in case if Twitter responds with any erroneous status code.
  """

  use Twittex.Client.Base, pool: true

  @sleep_before_retry 1000

  @doc """
  Returns a collection of the most recent Tweets posted by the user
  with the given `user_id` since Tweet with `since_id`.
  """
  @spec timeline(Integer.t(), Integer.t()) :: {:ok, %{} | {:error, HTTPoison.Error.t()}}
  def timeline(user_id, since_id) do
    response =
      get(
        "/statuses/user_timeline.json?" <>
          URI.encode_query(%{
            user_id: user_id,
            since_id: since_id
          })
      )

    case response do
      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in [420, 503] ->
        :timer.sleep(@sleep_before_retry)
        timeline(user_id, since_id)

      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code > 200 ->
        :timer.sleep(@sleep_before_retry)
        response

      anything_else ->
        anything_else
    end
  end

  @doc """
  Returns a stream of relevant Tweets for given `user_ids`.
  """
  @spec stream(list(integer())) :: {:ok, Enumerable.t()} | {:error, HTTPoison.Error.t()}
  def stream(user_ids) do
    {min_demand, options} = Keyword.pop(options, :min_demand, 500)
    {max_demand, options} = Keyword.pop(options, :max_demand, 1_000)

    url =
      "https://stream.twitter.com/1.1/statuses/filter.json?" <>
        URI.encode_query(%{delimited: "length"} |> Enum.into(user_ids))

    case stage(:post, url) do
      {:ok, stage} ->
        {:ok, GenStage.stream([{stage, [min_demand: min_demand, max_demand: max_demand]}])}

      {:error, error} ->
        {:error, error}
    end
  end
end
