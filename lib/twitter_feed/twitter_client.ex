require Logger

defmodule TwitterFeed.TwitterClient do
  @moduledoc """
  Twitter client built on top of Twittex.Client.Base.

  It uses pool for requests and provides back-off functionality
  in case if Twitter responds with any erroneous status code.
  """

  use Twittex.Client.Base, pool: true

  @max_timeline_entries 200

  @doc """
  Returns a collection of the Tweets posted by the user
  with the given `user_id` with given `options`.
  """
  @spec timeline(Integer.t(), Keyword.t()) :: {:ok, list(map())} | {:error, HTTPoison.Error.t()}
  def timeline(user_id, options \\ []) do
    options = Map.new(options)
    query = Map.merge(options, %{user_id: user_id, count: @max_timeline_entries, include_rts: 1})

    url = "/statuses/user_timeline.json?" <> URI.encode_query(query)

    response =
      Task.Supervisor.async(TwitterFeed.TaskSupervisor, fn ->
        try do
          get(url)
        catch
          :exit, {:timeout, _} ->
            {:error, :timeout}
        end
      end)
      |> Task.await()

    case response do
      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in [420, 503] ->
        Logger.error("Got #{status_code} response from Twitter")
        {:error, :service_unavailable}

      {:ok, %HTTPoison.Response{status_code: status_code} = response} when status_code > 200 ->
        Logger.error("Got #{status_code} response from Twitter")
        {:error, response}

      anything_else ->
        anything_else
    end
  end

  @doc """
  Returns a stream of relevant Tweets for given `user_ids`.
  """
  @spec stream(list(integer())) :: {:ok, Enumerable.t()} | {:error, HTTPoison.Error.t()}
  def stream(user_ids) do
    user_ids = Enum.join(user_ids, ",")

    url =
      "https://stream.twitter.com/1.1/statuses/filter.json?" <>
        URI.encode_query(%{
          delimited: "length",
          follow: user_ids
        })

    stage(:post, url)
  end
end
