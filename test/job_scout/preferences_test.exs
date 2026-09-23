defmodule JobScout.PreferencesTest do
  use ExUnit.Case, async: true

  test "normalizes user supplied countries and roles" do
    assert {:ok, p} =
             JobScout.Preferences.from_form(%{
               "countries" => "in, gb, IN",
               "roles" => "Engineer, Designer",
               "work_mode" => "remote"
             })

    assert p.countries == ["IN", "GB"]
    assert p.roles == ["Engineer", "Designer"]
  end

  test "accepts city targets without broad country targets" do
    assert {:ok, preferences} =
             JobScout.Preferences.from_form(%{
               "countries" => "",
               "cities" => "London, GB\nAmsterdam, NL",
               "roles" => "Data Scientist"
             })

    assert preferences.countries == []
    assert preferences.cities == ["London, GB", "Amsterdam, NL"]
  end

  test "requires a target role and at least one country or city" do
    assert {:error, _} = JobScout.Preferences.from_form(%{"countries" => "", "roles" => ""})

    assert {:error, changeset} =
             JobScout.Preferences.from_form(%{
               "countries" => "",
               "cities" => "",
               "roles" => "Engineer"
             })

    assert Keyword.has_key?(changeset.errors, :cities)
  end
end
