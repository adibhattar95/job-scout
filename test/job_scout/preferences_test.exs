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

  test "requires explicit countries and target roles" do
    assert {:error, _} = JobScout.Preferences.from_form(%{"countries" => "", "roles" => ""})
  end
end
