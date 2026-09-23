defmodule JobScout.JobsRankerTest do
  use ExUnit.Case, async: true
  alias JobScout.Jobs.{Job, Ranker}

  test "ranks matching role and documented skills above unrelated titles" do
    profile = %JobScout.Profile{skills: ["Python", "SQL"]}

    {:ok, matching} =
      Job.new(%{
        id: "one",
        source: "fixture",
        title: "Senior Data Scientist",
        company: "A",
        location: "London, GB",
        url: "https://example.com/1",
        description: "Build ranking systems using Python and SQL."
      })

    {:ok, unrelated} =
      Job.new(%{
        id: "two",
        source: "fixture",
        title: "Sales Manager",
        company: "B",
        location: "London, GB",
        url: "https://example.com/2",
        description: "Develop sales plans."
      })

    assert [result] = Ranker.rank([unrelated, matching], profile, "Data Scientist", "London, GB")
    assert result.title == "Senior Data Scientist"
    assert result.matched_skills == ["Python", "SQL"]
  end

  test "rejects unsafe job links" do
    assert {:error, :invalid_job} =
             Job.new(%{
               id: "unsafe",
               source: "fixture",
               title: "Engineer",
               url: "javascript:alert(1)"
             })
  end
end
