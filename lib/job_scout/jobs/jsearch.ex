defmodule JobScout.Jobs.JSearch do
  @moduledoc "One city/country query per click, with a durable 24-hour cache and quota guard."
  alias JobScout.Jobs.Job
  alias JobScout.Store

  @url "https://api.openwebninja.com/jsearch/search-v2"

  def search(role, location, work_mode, opts \\ []) do
    store = Keyword.get(opts, :store, Store)
    now = Keyword.get(opts, :now, DateTime.utc_now())
    query = "#{role} jobs in #{location}"
    cache_key = :crypto.hash(:sha256, "#{query}:#{work_mode}") |> Base.encode16(case: :lower)

    case Store.get("job_cache", "jsearch:" <> cache_key, store) do
      {:ok, %{"fetched_at" => fetched_at, "jobs" => jobs}} when is_list(jobs) ->
        if fresh?(fetched_at, now) do
          {:ok, normalize(jobs), :cached}
        else
          request(role, location, work_mode, cache_key, store, now, opts)
        end

      _ ->
        request(role, location, work_mode, cache_key, store, now, opts)
    end
  end

  def configured? do
    key = Application.get_env(:job_scout, :jsearch_key)
    is_binary(key) and String.trim(key) != ""
  end

  defp request(role, location, work_mode, cache_key, store, now, opts) do
    key = Keyword.get(opts, :key, Application.get_env(:job_scout, :jsearch_key))

    cond do
      not is_binary(key) or String.trim(key) == "" ->
        {:error, :not_configured}

      true ->
        case Store.reserve_jsearch(store, DateTime.to_date(now)) do
          {:ok, _} -> fetch(role, location, work_mode, cache_key, store, now, key, opts)
          {:error, :quota_exhausted} -> {:error, :quota_exhausted}
          _ -> {:error, :quota_unavailable}
        end
    end
  end

  defp fetch(role, location, work_mode, cache_key, store, now, key, opts) do
    params = %{"query" => "#{role} jobs in #{location}"}

    params =
      if code = country_code(location),
        do: Map.put(params, "country", String.downcase(code)),
        else: params

    params = if work_mode == "remote", do: Map.put(params, "work_from_home", "true"), else: params

    request_opts =
      [
        url: @url,
        params: params,
        headers: [{"x-api-key", key}],
        retry: false,
        receive_timeout: 25_000
      ]
      |> Keyword.merge(Keyword.get(opts, :request_options, []))

    case Req.get(request_opts) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        jobs = get_jobs(body)

        if is_list(jobs) do
          cached = %{"fetched_at" => DateTime.to_iso8601(now), "jobs" => jobs}

          case Store.put("job_cache", "jsearch:" <> cache_key, cached, store) do
            :ok -> {:ok, normalize(jobs), :live}
            _ -> {:ok, normalize(jobs), :live}
          end
        else
          {:error, :invalid_response}
        end

      {:ok, %{status: 429}} ->
        {:error, :provider_quota_exhausted}

      _ ->
        {:error, :source_unavailable}
    end
  end

  defp get_jobs(%{"data" => jobs}) when is_list(jobs), do: jobs
  defp get_jobs(%{"data" => %{"jobs" => jobs}}) when is_list(jobs), do: jobs
  defp get_jobs(_), do: nil

  defp country_code(location) do
    case Regex.run(~r/(?:^|,\s*)([A-Z]{2})$/u, location) do
      [_, code] -> code
      _ -> nil
    end
  end

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
        id: job["job_id"],
        source: "JSearch",
        title: job["job_title"],
        company: job["employer_name"],
        location: job["job_location"] || job["job_city"] || "Location not stated",
        url: job["job_apply_link"] || job["job_google_link"],
        description: String.slice(job["job_description"] || "", 0, 5_000),
        posted_at: job["job_posted_at_datetime_utc"],
        remote: job["job_is_remote"]
      })
    end)
    |> Enum.flat_map(fn
      {:ok, job} -> [job]
      _ -> []
    end)
  end
end
