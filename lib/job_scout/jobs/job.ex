defmodule JobScout.Jobs.Job do
  @moduledoc "A source-neutral listing; its URL always points back to the source."

  @enforce_keys [:id, :source, :title, :company, :location, :url]
  defstruct [
    :id,
    :source,
    :title,
    :company,
    :location,
    :url,
    :description,
    :posted_at,
    :remote,
    :relevance,
    matched_skills: []
  ]

  def new(attrs) do
    with title when is_binary(title) and title != "" <- attrs[:title],
         url when is_binary(url) <- attrs[:url],
         %URI{scheme: scheme, host: host} <- URI.parse(url),
         true <- scheme in ["http", "https"] and is_binary(host) do
      {:ok,
       struct!(__MODULE__, %{
         id: to_string(attrs[:id] || url),
         source: attrs[:source],
         title: title,
         company: attrs[:company] || "Unknown company",
         location: attrs[:location] || "Location not stated",
         url: url,
         description: attrs[:description] || "",
         posted_at: attrs[:posted_at],
         remote: attrs[:remote],
         relevance: 0,
         matched_skills: []
       })}
    else
      _ -> {:error, :invalid_job}
    end
  end
end
