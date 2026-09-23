defmodule JobScout.Preferences do
  @moduledoc "User-supplied search constraints, independent of inferred CV facts."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:roles, {:array, :string}, default: [])
    field(:countries, {:array, :string}, default: [])
    field(:cities, {:array, :string}, default: [])
    field(:work_mode, :string, default: "any")
    field(:sponsorship, :string, default: "unknown")
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:roles, :countries, :cities, :work_mode, :sponsorship])
    |> validate_required([:roles, :work_mode])
    |> require_nonempty(:roles)
    |> require_location()
    |> validate_inclusion(:work_mode, ["any", "remote", "hybrid", "onsite"])
    |> validate_inclusion(:sponsorship, ["unknown", "required", "not_required"])
    |> validate_change(:countries, fn :countries, countries ->
      if Enum.all?(countries, &Regex.match?(~r/^[A-Z]{2}$/, &1)),
        do: [],
        else: [countries: "use two-letter country codes, for example IN, GB, DE"]
    end)
    |> validate_change(:cities, fn :cities, cities ->
      if Enum.all?(cities, &(String.length(&1) <= 120)),
        do: [],
        else: [cities: "keep each city target under 120 characters"]
    end)
  end

  defp require_location(changeset) do
    if get_field(changeset, :countries) in [nil, []] and
         get_field(changeset, :cities) in [nil, []],
       do: add_error(changeset, :cities, "enter at least one country or city"),
       else: changeset
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
    |> Map.update("cities", [], &split_cities/1)
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

  defp split_cities(value) do
    value
    |> String.split(~r/[\n;]+/, trim: true)
    |> Enum.map(&(String.trim(&1) |> String.replace(~r/\s+/u, " ")))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end
end
