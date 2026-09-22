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
    with {:ok, profile} <- changeset(attrs) |> apply_action(:insert),
         true <-
           profile.evidence != [] and Enum.all?(profile.evidence, &valid_evidence?(&1, resume)) do
      {:ok, profile}
    else
      false -> {:error, :unsupported_evidence}
      {:error, _} -> {:error, :invalid_profile}
    end
  end

  def parse(_, _), do: {:error, :invalid_profile}

  defp valid_evidence?(%{"quote" => quote, "id" => id}, resume)
       when is_binary(quote) and is_binary(id) do
    String.trim(quote) != "" and String.trim(id) != "" and String.contains?(resume, quote)
  end

  defp valid_evidence?(_, _), do: false

  def to_map(profile), do: Map.from_struct(profile) |> Map.drop([:__meta__])

  def json_schema do
    %{
      type: "object",
      additionalProperties: false,
      required: ["name", "summary", "roles", "skills", "seniority", "evidence"],
      properties: %{
        name: %{type: "string"},
        summary: %{type: "string"},
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
