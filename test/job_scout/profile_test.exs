defmodule JobScout.ProfileTest do
  use ExUnit.Case, async: true
  alias JobScout.Profile

  test "rejects evidence that does not appear in the resume" do
    attrs = %{
      "summary" => "Developer",
      "evidence" => [%{"id" => "e1", "quote" => "Managed 40 people"}]
    }

    assert {:error, :unsupported_evidence} = Profile.parse(attrs, "Developed billing software.")
  end

  test "accepts verbatim evidence" do
    attrs = %{
      "summary" => "Developer",
      "skills" => ["Elixir"],
      "evidence" => [%{"id" => "e1", "quote" => "Built APIs in Elixir."}]
    }

    assert {:ok, %{skills: ["Elixir"]}} =
             Profile.parse(attrs, "Experience: Built APIs in Elixir.")
  end

  test "rejects invalid structured fields" do
    assert {:error, :invalid_profile} =
             Profile.parse(%{"summary" => "Developer", "skills" => 3}, "resume")
  end
end
