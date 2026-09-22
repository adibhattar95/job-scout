defmodule JobScout.OllamaTest do
  use ExUnit.Case, async: true
  alias JobScout.LLM.Ollama

  test "uses local schema output and returns validated facts and usage" do
    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      request = Jason.decode!(body)
      assert request["stream"] == false
      assert request["format"]["type"] == "object"
      assert length(request["messages"]) == 2

      Req.Test.json(conn, %{
        message: %{
          content:
            Jason.encode!(%{
              summary: "Developer",
              skills: ["Elixir"],
              evidence: [%{id: "e1", quote: "Built APIs in Elixir."}]
            })
        },
        prompt_eval_count: 100,
        eval_count: 40
      })
    end)

    assert {:ok, profile, %{input_tokens: 100}} =
             Ollama.extract("Built APIs in Elixir.",
               request_options: [plug: {Req.Test, __MODULE__}]
             )

    assert profile.skills == ["Elixir"]
  end

  test "rejects fabricated evidence without retrying" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        message: %{
          content:
            Jason.encode!(%{
              summary: "Developer",
              evidence: [%{id: "e1", quote: "Led a 50-person team"}]
            })
        }
      })
    end)

    assert {:error, :invalid_model_output} =
             Ollama.extract("Built APIs in Elixir.",
               request_options: [plug: {Req.Test, __MODULE__}]
             )
  end

  test "reports missing models" do
    Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 404, "missing") end)

    assert {:error, :model_not_found} =
             Ollama.extract("resume", request_options: [plug: {Req.Test, __MODULE__}])
  end
end
