defmodule JobScout.TestJobs do
  alias JobScout.Jobs.Job

  def search(_profile, _preferences, role, location) do
    {:ok, job} =
      Job.new(%{
        id: "test-job",
        source: "Remotive",
        title: role,
        company: "Example Co",
        location: location,
        url: "https://remotive.com/remote-jobs/test-job",
        description: "A fixture job using Elixir.",
        remote: true
      })

    {:ok,
     %{
       jobs: [%{job | relevance: 80, matched_skills: ["Elixir"]}],
       role: role,
       location: location,
       jsearch: %{status: :not_configured, count: 0},
       remotive: %{status: :cached, count: 1},
       jsearch_usage: {:ok, 0}
     }}
  end
end
