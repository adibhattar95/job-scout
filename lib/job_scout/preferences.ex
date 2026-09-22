defmodule JobScout.Preferences do
  @moduledoc "User-supplied search constraints, independent of inferred CV facts."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:roles, {:array, :string}, default: [])
    field(:countries, {:array, :string}, default: [])
    field(:work_mode, :string, default: "any")
    field(:sponsorship, :string, default: "unknown")
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:roles, :countries, :work_mode, :sponsorship])
    |> validate_required([:roles, :countries, :work_mode])
    |> require_nonempty(:roles)
    |> require_nonempty(:countries)
    |> validate_inclusion(:work_mode, ["any", "remote", "hybrid", "onsite"])
    |> validate_inclusion(:sponsorship, ["unknown", "required", "not_required"])
    |> validate_change(:countries, fn :countries, countries ->
      if Enum.all?(countries, &Regex.match?(~r/^[A-Z]{2}$/, &1)),
        do: [],
        else: [countries: "use two-letter country codes, for example IN, GB, DE"]
    end)
  end

  defp require_nonempty(changeset, field) do
    if get_field(changeset, field) in [nil, []],
      do: add_error(changeset, field, "must include at least one value"),
      else: changeset
  end

  def from_form(attrs) do
    attrs
    |> Map.update("roles", [], &split/1)
    |> Map.update(
      "countries",
      [],
      &(split(&1) |> Enum.map(fn c -> String.upcase(c) end) |> Enum.uniq())
    )
    |> changeset()
    |> apply_action(:insert)
  end

  defp split(value),
    do:
      value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
end
