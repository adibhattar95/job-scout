defmodule JobScout.RunnerTest do
  use ExUnit.Case, async: true

  setup do
    path = Path.join(System.tmp_dir!(), "runner-test-#{System.unique_integer([:positive])}")
    store = start_supervised!({JobScout.Store, name: nil, path: path})
    on_exit(fn -> File.rm_rf!(path) end)
    %{store: store}
  end

  test "persists run metadata without resume content", %{store: store} do
    resume = "Alex built software using Elixir and PostgreSQL for internal teams."

    assert {:ok, _, run} =
             JobScout.Runner.extract(resume, adapter: JobScout.TestLLM, store: store)

    assert {:ok, saved} = JobScout.Store.get("run", run.id, store)
    assert saved["status"] == "completed"
    refute Jason.encode!(saved) =~ resume
    assert saved["usage"]["model"] == "fixture"
  end

  test "rejects short input before contacting a model", %{store: store} do
    assert {:error, :resume_too_short} =
             JobScout.Runner.extract("short", adapter: JobScout.TestLLM, store: store)
  end
end
