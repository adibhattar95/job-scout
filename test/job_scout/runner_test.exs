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

  test "loads a saved profile and preferences from a legacy snapshot", %{store: store} do
    record = %{
      profile: %{
        name: "Alex Morgan",
        summary: "Built internal APIs in Elixir.",
        skills: ["Elixir"],
        roles: ["Software Engineer"],
        evidence: [%{"id" => "e1", "quote" => "Built internal APIs in Elixir."}]
      },
      preferences: %{
        roles: ["Backend Engineer"],
        countries: ["IN"],
        work_mode: "remote",
        sponsorship: "unknown"
      },
      saved_at: "2026-09-22T10:00:00Z"
    }

    assert :ok = JobScout.Store.put("candidate", "legacy", record, store)
    assert {:ok, profile, preferences, nil} = JobScout.Runner.load_candidate(store: store)
    assert profile.name == "Alex Morgan"
    assert preferences.roles == ["Backend Engineer"]
    assert preferences.countries == ["IN"]
  end
end
