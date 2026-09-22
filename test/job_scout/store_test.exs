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
end
