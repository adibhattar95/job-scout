defmodule JobScout.Profile do
  @moduledoc "Validated candidate facts. Search preferences are kept separately."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:summary, :string)
    field(:roles, {:array, :string}, default: [])
    field(:skills, {:array, :string}, default: [])
    field(:seniority, :string)
    field(:evidence, {:array, :map}, default: [])
  end

  def changeset(profile \\ %__MODULE__{}, attrs) do
    profile
    |> cast(attrs, [:name, :summary, :roles, :skills, :seniority, :evidence])
    |> validate_length(:summary, max: 2000)
  end

  def parse(attrs, resume) when is_map(attrs) do
    with {:ok, profile} <- changeset(attrs) |> apply_action(:insert) do
      evidence = Enum.filter(profile.evidence, &valid_evidence?(&1, resume))

      if evidence == [] do
        {:error, :unsupported_evidence}
      else
        {:ok, %{profile | evidence: evidence}}
      end
    else
      {:error, _} -> {:error, :invalid_profile}
    end
  end

  def parse(_, _), do: {:error, :invalid_profile}

  defp valid_evidence?(%{"quote" => quote, "id" => id}, resume)
       when is_binary(quote) and is_binary(id) do
    String.trim(quote) != "" and String.trim(id) != "" and
      String.contains?(normalize_whitespace(resume), normalize_whitespace(quote))
  end

  defp valid_evidence?(_, _), do: false

  defp normalize_whitespace(text), do: String.replace(text, ~r/\s+/u, " ")

  @doc "Builds a minimal source-backed profile when the model provides no usable quotes."
  def recover_unsupported_evidence(attrs, resume) when is_map(attrs) do
    quote =
      resume
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.find(&(String.length(&1) >= 30 and not String.contains?(&1, "@")))
      |> case do
        nil -> String.trim(resume)
        line -> line
      end
      |> String.slice(0, 200)

    safe_attrs = %{
      "name" => sourced_text(attrs["name"], resume),
      "summary" => nil,
      "roles" => sourced_list(attrs["roles"], resume),
      "skills" => sourced_list(attrs["skills"], resume),
      "seniority" => sourced_text(attrs["seniority"], resume),
      "evidence" => [%{"id" => "source-1", "quote" => quote}]
    }

    parse(safe_attrs, resume)
  end

  defp sourced_list(values, resume) when is_list(values),
    do: Enum.filter(values, &mentioned?(&1, resume))

  defp sourced_list(_, _), do: []

  defp sourced_text(value, resume),
    do: if(mentioned?(value, resume), do: value, else: nil)

  defp substantive_summary?(summary) when is_binary(summary) do
    String.length(String.trim(summary)) >= 60 and
      length(String.split(summary, ~r/\s+/, trim: true)) >= 6
  end

  defp substantive_summary?(_), do: false

  @doc "Fills a missing or title-only summary using only terms present in the source resume."
  def ensure_summary(%__MODULE__{} = profile, resume) do
    if not substantive_summary?(profile.summary) do
      role = Enum.find(profile.roles, &mentioned?(&1, resume))

      skills =
        profile.skills
        |> Enum.filter(&mentioned?(&1, resume))
        |> Enum.take(6)

      summary =
        case {role, skills} do
          {role, [_ | _] = skills} when is_binary(role) ->
            "#{role} with skills in #{natural_list(skills)}."

          {role, []} when is_binary(role) ->
            role <> "."

          {nil, [_ | _] = skills} ->
            "Skills include #{natural_list(skills)}."

          {nil, []} ->
            profile.evidence
            |> hd()
            |> Map.fetch!("quote")
            |> String.replace(~r/\s+/u, " ")
            |> String.slice(0, 200)
        end

      %{profile | summary: summary}
    else
      profile
    end
  end

  defp mentioned?(value, resume) when is_binary(value) do
    if String.length(value) in 1..80 do
      pattern = "(?<![[:alnum:]])" <> Regex.escape(value) <> "(?![[:alnum:]])"
      Regex.match?(Regex.compile!(pattern, "iu"), resume)
    else
      false
    end
  end

  defp mentioned?(_, _), do: false

  defp natural_list([one]), do: one
  defp natural_list([first, second]), do: first <> " and " <> second

  defp natural_list(many) do
    many
    |> Enum.drop(-1)
    |> Enum.join(", ")
    |> Kernel.<>(", and " <> List.last(many))
  end

  def to_map(profile), do: Map.from_struct(profile) |> Map.drop([:__meta__])

  def json_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["name", "summary", "roles", "skills", "seniority", "evidence"],
      properties: %{
        name: %{type: "string"},
        summary: %{
          type: "string",
          minLength: 60,
          maxLength: 500,
          description:
            "One or two factual sentences of at least 12 words, synthesized from documented experience and skills. Never empty or just a title."
        },
        roles: %{
          type: "array",
          description:
            "Explicit job titles held by the candidate; not responsibilities or desired roles",
          items: %{type: "string"}
        },
        skills: %{type: "array", items: %{type: "string"}},
        seniority: %{type: "string"},
        evidence: %{
          type: "array",
          items: %{
            type: "object",
            additionalProperties: false,
            required: ["id", "quote"],
            properties: %{id: %{type: "string"}, quote: %{type: "string"}}
          }
        }
      }
    }
  end
end
