defmodule JobScout.StoreTest do
  use ExUnit.Case, async: true
  alias JobScout.Store

  setup do
    path = Path.join(System.tmp_dir!(), "scout-test-#{System.unique_integer([:positive])}")
    store = start_supervised!({Store, name: nil, path: path})
    on_exit(fn -> File.rm_rf!(path) end)
    %{store: store, path: path}
  end

  test "concurrent reservations cannot exceed the allowance", %{store: store} do
    results =
      1..20
      |> Task.async_stream(fn _ -> Store.reserve("2026-09", 5, store) end)
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 5
    assert Enum.count(results, &(&1 == {:error, :quota_exhausted})) == 15
    assert {:ok, 5} = Store.usage("2026-09", store)
  end

  test "reservations survive restart", %{store: store, path: path} do
    assert {:ok, 1} = Store.reserve("period", 1, store)
    stop_supervised!(Store)
    restarted = start_supervised!({Store, name: nil, path: path})
    assert {:error, :quota_exhausted} = Store.reserve("period", 1, restarted)
  end

  test "corrupt quota records fail closed", %{store: store} do
    assert :ok = Store.put("quota", "period", %{"attempts" => "invalid"}, store)
    assert {:error, :invalid_quota_ledger} = Store.reserve("period", 180, store)
  end

  test "finds the newest saved candidate and ignores other records", %{store: store} do
    assert {:error, :enoent} = Store.latest_candidate(store)

    assert :ok =
             Store.put(
               "candidate",
               "old",
               %{
                 profile: %{},
                 preferences: %{},
                 saved_at: "2026-09-20T10:00:00Z"
               },
               store
             )

    assert :ok = Store.put("run", "run", %{status: "completed"}, store)

    latest = %{
      profile: %{"name" => "Alex"},
      preferences: %{},
      saved_at: "2026-09-22T10:00:00Z"
    }

    assert :ok = Store.put("candidate", "new", latest, store)
    assert {:ok, %{"profile" => %{"name" => "Alex"}}} = Store.latest_candidate(store)
  end

  test "JSearch allowance counts a rolling 31-day window atomically", %{store: store} do
    today = ~D[2026-09-23]
    assert :ok = Store.put("quota", "jsearch:2026-08-24", %{"attempts" => 178}, store)
    assert :ok = Store.put("quota", "jsearch:2026-08-23", %{"attempts" => 10}, store)
    assert {:ok, 178} = Store.jsearch_usage(store, today)
    assert {:ok, 179} = Store.reserve_jsearch(store, today)
    assert {:ok, 180} = Store.reserve_jsearch(store, today)
    assert {:error, :quota_exhausted} = Store.reserve_jsearch(store, today)
    assert {:ok, 180} = Store.jsearch_usage(store, today)
  end
end
