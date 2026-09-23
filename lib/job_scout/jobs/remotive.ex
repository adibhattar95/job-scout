defmodule JobScout.Jobs.Remotive do
  @moduledoc "Keyless remote listings. Fetch the whole feed at most once every 24 hours."
  alias JobScout.Jobs.Job
  alias JobScout.Store

  @cache_key "remotive:all"
  @url "https://remotive.com/api/remote-jobs"

  def fetch(opts \\ []) do
    store = Keyword.get(opts, :store, Store)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    case Store.get("job_cache", @cache_key, store) do
      {:ok, %{"fetched_at" => fetched_at, "jobs" => jobs}} ->
        if fresh?(fetched_at, now) do
          {:ok, normalize(jobs), :cached}
        else
          request(store, now, opts, jobs)
        end

      _ ->
        request(store, now, opts, nil)
    end
  end

  defp request(store, now, opts, stale_jobs) do
    period = "remotive:" <> (now |> DateTime.to_date() |> Date.to_iso8601())

    case Store.reserve(period, 4, store) do
      {:ok, _} -> fetch(store, now, opts, stale_jobs)
      _ -> stale_or_error(stale_jobs, :rate_limited)
    end
  end

  defp fetch(store, now, opts, stale_jobs) do
    request_opts =
      [url: @url, retry: false, receive_timeout: 25_000]
      |> Keyword.merge(Keyword.get(opts, :request_options, []))

    case Req.get(request_opts) do
      {:ok, %{status: 200, body: %{"jobs" => jobs}}} when is_list(jobs) ->
        cached = %{"fetched_at" => DateTime.to_iso8601(now), "jobs" => jobs}

        case Store.put("job_cache", @cache_key, cached, store) do
          :ok -> {:ok, normalize(jobs), :live}
          _ -> {:ok, normalize(jobs), :uncached}
        end

      _ ->
        stale_or_error(stale_jobs, :source_unavailable)
    end
  end

  defp stale_or_error(jobs, _) when is_list(jobs), do: {:ok, normalize(jobs), :stale}
  defp stale_or_error(_, reason), do: {:error, reason}

  defp fresh?(stamp, now) do
    case DateTime.from_iso8601(stamp) do
      {:ok, then_at, _} -> DateTime.diff(now, then_at, :second) in 0..86_399
      _ -> false
    end
  end

  defp normalize(jobs) do
    jobs
    |> Enum.map(fn job ->
      Job.new(%{
        id: job["id"],
        source: "Remotive",
        title: job["title"],
        company: job["company_name"],
        location: job["candidate_required_location"] || "Worldwide",
        url: job["url"],
        description: plain_text(job["description"] || ""),
        posted_at: job["publication_date"],
        remote: true
      })
    end)
    |> Enum.flat_map(fn
      {:ok, job} -> [job]
      _ -> []
    end)
  end

  defp plain_text(html) do
    html
    |> String.replace(~r/<[^>]*>/u, " ")
    |> String.replace(~r/&(?:nbsp|amp|lt|gt|quot);/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.slice(0, 5_000)
  end
end
