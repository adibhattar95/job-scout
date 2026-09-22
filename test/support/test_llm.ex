defmodule JobScout.TestLLM do
  def extract(resume, _) do
    {:ok, profile} =
      JobScout.Profile.parse(
        %{
          "summary" => "Software developer",
          "evidence" => [%{"id" => "e1", "quote" => resume}]
        },
        resume
      )

    {:ok, profile, %{model: "fixture", input_tokens: 10, output_tokens: 5}}
  end
end
