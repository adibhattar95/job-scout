defmodule JobScout.Jobs.Ranker do
  @moduledoc "Transparent title, skill, and location ranking without an extra model call."

  def rank(jobs, profile, role, location) do
    jobs
    |> Enum.map(&score(&1, profile, role, location))
    |> Enum.filter(&(&1.relevance >= 20))
    |> Enum.sort_by(& &1.relevance, :desc)
  end

  defp score(job, profile, role, location) do
    title = String.downcase(job.title)
    role_words = role |> words() |> Enum.reject(&(&1 in ~w(senior junior lead principal staff)))
    title_words = words(title)
    matching_words = Enum.count(role_words, &(&1 in title_words))

    title_score =
      cond do
        String.contains?(title, String.downcase(role)) -> 55
        role_words == [] -> 0
        true -> round(45 * matching_words / length(role_words))
      end

    text = String.downcase(job.title <> " " <> job.description)

    matched_skills =
      profile.skills
      |> Enum.filter(fn skill -> String.contains?(text, String.downcase(skill)) end)
      |> Enum.take(8)

    skill_score = min(length(matched_skills) * 6, 30)
    location_score = if location_match?(job.location, location) or job.remote, do: 10, else: 0

    %{
      job
      | relevance: min(title_score + skill_score + location_score, 100),
        matched_skills: matched_skills
    }
  end

  defp words(value),
    do: value |> String.downcase() |> String.split(~r/[^\p{L}\p{N}]+/u, trim: true)

  defp location_match?(job_location, target) do
    city = target |> String.split(",", parts: 2) |> hd() |> String.downcase()
    city != "" and String.contains?(String.downcase(job_location), city)
  end
end
