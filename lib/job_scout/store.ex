defmodule JobScout.Store do
  @moduledoc "Single-node, durable local records and serialized quota reservations."
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def put(kind, id, value, server \\ __MODULE__),
    do: GenServer.call(server, {:put, kind, id, value})

  def get(kind, id, server \\ __MODULE__), do: GenServer.call(server, {:get, kind, id})
  def latest_candidate(server \\ __MODULE__), do: GenServer.call(server, :latest_candidate)
  def usage(period, server \\ __MODULE__), do: GenServer.call(server, {:usage, period})

  def reserve(period, limit, server \\ __MODULE__),
    do: GenServer.call(server, {:reserve, period, limit})

  # Conservative local guard for a 200-request monthly JSearch allowance.
  def jsearch_usage(server \\ __MODULE__, today \\ Date.utc_today()),
    do: GenServer.call(server, {:jsearch_usage, today})

  def reserve_jsearch(server \\ __MODULE__, today \\ Date.utc_today()),
    do: GenServer.call(server, {:reserve_jsearch, today})

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :path, Application.get_env(:job_scout, :data_dir, "data/local"))

    with :ok <- File.mkdir_p(path), :ok <- File.chmod(path, 0o700) do
      {:ok, path}
    else
      error -> {:stop, error}
    end
  end

  @impl true
  def handle_call({:put, kind, id, value}, _from, path) do
    {:reply, write(path, kind, id, value), path}
  end

  def handle_call({:get, kind, id}, _from, path), do: {:reply, read(path, kind, id), path}

  def handle_call(:latest_candidate, _from, path) do
    candidate =
      path
      |> Path.join("*.json")
      |> Path.wildcard()
      |> Enum.reduce(nil, fn file, latest ->
        with {:ok, json} <- File.read(file),
             {:ok,
              %{"profile" => profile, "preferences" => preferences, "saved_at" => saved_at} =
                record} <-
               Jason.decode(json),
             true <- is_map(profile) and is_map(preferences) and is_binary(saved_at) do
          if latest == nil or saved_at > latest["saved_at"], do: record, else: latest
        else
          _ -> latest
        end
      end)

    {:reply, if(candidate, do: {:ok, candidate}, else: {:error, :enoent}), path}
  end

  def handle_call({:usage, period}, _from, path), do: {:reply, read_usage(path, period), path}

  def handle_call({:reserve, period, limit}, _from, path) when is_integer(limit) and limit > 0 do
    result =
      with {:ok, used} <- read_usage(path, period) do
        if used < limit do
          case write(path, "quota", period, %{"attempts" => used + 1}) do
            :ok -> {:ok, used + 1}
            error -> error
          end
        else
          {:error, :quota_exhausted}
        end
      end

    {:reply, result, path}
  end

  def handle_call({:jsearch_usage, today}, _from, path) do
    {:reply, jsearch_usage_for(path, today), path}
  end

  def handle_call({:reserve_jsearch, today}, _from, path) do
    result =
      with {:ok, used} <- jsearch_usage_for(path, today),
           true <- used < 180,
           period = "jsearch:" <> Date.to_iso8601(today),
           {:ok, today_used} <- read_usage(path, period),
           :ok <- write(path, "quota", period, %{"attempts" => today_used + 1}) do
        {:ok, used + 1}
      else
        false -> {:error, :quota_exhausted}
        error -> error
      end

    {:reply, result, path}
  end

  defp jsearch_usage_for(path, today) do
    Enum.reduce_while(0..30, {:ok, 0}, fn days_ago, {:ok, total} ->
      period = "jsearch:" <> (today |> Date.add(-days_ago) |> Date.to_iso8601())

      case read_usage(path, period) do
        {:ok, count} -> {:cont, {:ok, total + count}}
        error -> {:halt, error}
      end
    end)
  end

  defp read_usage(path, period) do
    case read(path, "quota", period) do
      {:ok, %{"attempts" => n}} when is_integer(n) and n >= 0 -> {:ok, n}
      {:error, :enoent} -> {:ok, 0}
      _ -> {:error, :invalid_quota_ledger}
    end
  end

  defp filename(path, kind, id) do
    hash = :crypto.hash(:sha256, "#{kind}:#{id}") |> Base.encode16(case: :lower)
    Path.join(path, hash <> ".json")
  end

  defp read(path, kind, id) do
    with {:ok, data} <- File.read(filename(path, kind, id)), do: Jason.decode(data)
  end

  defp write(path, kind, id, value) do
    target = filename(path, kind, id)
    temporary = target <> ".tmp"

    with {:ok, json} <- Jason.encode(value),
         :ok <- File.write(temporary, json, [:sync]),
         :ok <- File.chmod(temporary, 0o600),
         :ok <- File.rename(temporary, target),
         do: :ok
  end
end
