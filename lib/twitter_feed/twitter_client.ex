require Logger

defmodule TwitterFeed.TwitterClient do
  @moduledoc """
  Twitter client built on top of Twittex.Client.Base.

  It uses pool for requests and provides back-off functionality
  in case if Twitter responds with any erroneous status code.
  """

  use Twittex.Client.Base, pool: true

  @initial_sleep 1000
  @max_timeline_entries 200

  @doc """
  Returns a collection of most recent Tweets posted by the user
  with the given `user_id` since Tweet with `since_id`.
  """
  @spec timeline_after(Integer.t(), Integer.t()) ::
          {:ok, list(map())} | {:error, HTTPoison.Error.t()}
  def timeline_after(user_id, since_id) do
    timeline(user_id, since_id: since_id)
  end

  @doc """
  Returns a collection of Tweets posted by the user with the given `user_id`
  before Tweet with `max_id`.
  """
  @spec timeline_before(Integer.t(), Integer.t()) ::
          {:ok, list(map())} | {:error, HTTPoison.Error.t()}
  def timeline_before(user_id, max_id) do
    timeline(user_id, max_id: max_id)
  end

  #  Returns a collection of the Tweets posted by the user
  #  with the given `user_id` with given `options`.
  #
  #  In case of an erroneous response from Twitter client will `sleep_before_retry`.
  @spec timeline(Integer.t(), Keyword.t(), Integer.t()) ::
          {:ok, list(map())} | {:error, HTTPoison.Error.t()}
  defp timeline(user_id, options, sleep_before_retry \\ @initial_sleep) do
    response =
      get(
        ("/statuses/user_timeline.json?" <>
           URI.encode_query(%{
             user_id: user_id,
             count: @max_timeline_entries
           }))
        |> Enum.into(options)
      )

    case response do
      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in [420, 503] ->
        Logger.error(
          "Got #{status_code} response from Twitter. Retrying in #{sleep_before_retry} ms"
        )

        :timer.sleep(sleep_before_retry)
        timeline(user_id, options, 2 * sleep_before_retry)

      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code > 200 ->
        Logger.error("Got #{status_code} response from Twitter")
        :timer.sleep(sleep_before_retry)
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
    url =
      "https://stream.twitter.com/1.1/statuses/filter.json?" <>
        URI.encode_query(%{delimited: "length"} |> Enum.into(user_ids))

    stage(:post, url)
  end
end
