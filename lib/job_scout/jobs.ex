defmodule JobScout.Jobs do
  @moduledoc "Runs one explicit role/location search and merges source results."
  alias JobScout.Jobs.{JSearch, Ranker, Remotive}
  alias JobScout.Store

  @country_names %{
    "AE" => "United Arab Emirates",
    "AU" => "Australia",
    "CA" => "Canada",
    "DE" => "Germany",
    "FR" => "France",
    "GB" => "United Kingdom",
    "IN" => "India",
    "NL" => "Netherlands",
    "SG" => "Singapore",
    "US" => "United States"
  }

  @european_countries ~w(AT BE CH CZ DE DK ES FI FR GB IE IT LU NL NO PL PT SE)

  def locations(preferences), do: preferences.cities ++ preferences.countries

  def search(profile, preferences, role, location, opts \\ []) do
    if role in preferences.roles and location in locations(preferences) do
      store = Keyword.get(opts, :store, Store)
      jsearch = Keyword.get(opts, :jsearch, JSearch)
      remotive = Keyword.get(opts, :remotive, Remotive)
      source_opts = Keyword.get(opts, :source_options, []) |> Keyword.put(:store, store)

      {jsearch_jobs, jsearch_status} =
        case jsearch.search(role, location, preferences.work_mode, source_opts) do
          {:ok, jobs, mode} -> {jobs, mode}
          {:error, reason} -> {[], reason}
        end

      {remote_jobs, remotive_status} =
        if preferences.work_mode in ["any", "remote"] do
          case remotive.fetch(source_opts) do
            {:ok, jobs, mode} ->
              eligible = Enum.filter(jobs, &remote_eligible?(&1.location, location))
              {eligible, mode}

            {:error, reason} ->
              {[], reason}
          end
        else
          {[], :not_applicable}
        end

      jobs =
        (jsearch_jobs ++ remote_jobs)
        |> Enum.uniq_by(fn job ->
          {String.downcase(job.title), String.downcase(job.company),
           String.downcase(job.location)}
        end)
        |> Ranker.rank(profile, role, location)
        |> Enum.take(20)

      {:ok,
       %{
         jobs: jobs,
         role: role,
         location: location,
         jsearch: %{status: jsearch_status, count: length(jsearch_jobs)},
         remotive: %{status: remotive_status, count: length(remote_jobs)},
         jsearch_usage: Store.jsearch_usage(store)
       }}
    else
      {:error, :invalid_search_choice}
    end
  end

  defp remote_eligible?(restriction, target) do
    restriction = String.downcase(restriction || "")
    city = target |> String.split(",", parts: 2) |> hd() |> String.downcase()
    code = target_code(target)
    country = Map.get(@country_names, code, "") |> String.downcase()

    Enum.any?(["worldwide", "anywhere", "global"], &String.contains?(restriction, &1)) or
      (city != "" and String.contains?(restriction, city)) or
      (country != "" and String.contains?(restriction, country)) or
      (code == "GB" and Regex.match?(~r/\buk\b/u, restriction)) or
      (code == "US" and Regex.match?(~r/\busa\b/u, restriction)) or
      (code in @european_countries and
         Enum.any?(["europe", "emea", "european union"], &String.contains?(restriction, &1)))
  end

  defp target_code(target) do
    case Regex.run(~r/(?:^|,\s*)([A-Z]{2})$/u, target) do
      [_, code] -> code
      _ -> nil
    end
  end
end
