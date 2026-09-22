defmodule JobScout.Runner do
  @moduledoc "Shared extraction entry point for the UI and command-line runs."
  alias JobScout.{LLM.Ollama, Profile, Store}
  @prompt_version "extract-profile-v2"

  def extract(resume, opts \\ []) do
    resume = String.trim(resume)
    adapter = Keyword.get(opts, :adapter, Ollama)
    store = Keyword.get(opts, :store, Store)
    run_id = Ecto.UUID.generate()
    started_at = DateTime.utc_now() |> DateTime.to_iso8601()
    start = System.monotonic_time(:millisecond)

    result =
      cond do
        String.length(resume) < 40 -> {:error, :resume_too_short}
        String.length(resume) > 16_000 -> {:error, :resume_too_long}
        true -> adapter.extract(resume, Keyword.get(opts, :llm_options, []))
      end

    record = %{
      id: run_id,
      started_at: started_at,
      duration_ms: System.monotonic_time(:millisecond) - start,
      prompt_version: @prompt_version,
      status: if(match?({:ok, _, _}, result), do: "completed", else: "failed"),
      # No resume or model prompt is written to trace records.
      resume_sha256: :crypto.hash(:sha256, resume) |> Base.encode16(case: :lower)
    }

    case result do
      {:ok, profile, usage} ->
        record = Map.put(record, :usage, usage)

        with :ok <- Store.put("run", run_id, record, store) do
          {:ok, profile, record}
        else
          _ -> {:error, :storage_unavailable}
        end

      {:error, reason} ->
        Store.put("run", run_id, Map.put(record, :error, inspect(reason)), store)
        {:error, reason}
    end
  end

  def save_candidate(profile, preferences) do
    id = Ecto.UUID.generate()

    data = %{
      profile: Profile.to_map(profile),
      preferences: Map.from_struct(preferences),
      saved_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    with :ok <- Store.put("candidate", id, data), do: {:ok, id}
  end

  def error_message(:resume_too_short), do: "Paste at least 40 characters of resume text."

  def error_message(:resume_too_long),
    do: "This first version supports up to 16,000 characters. Shorten the input and try again."

  def error_message(:model_not_found),
    do: "The configured model is not installed in Ollama. Check OLLAMA_MODEL."

  def error_message(:ollama_unavailable),
    do: "Could not reach Ollama, or generation timed out. Check that Ollama is running."

  def error_message(:invalid_model_output),
    do:
      "The model returned an invalid profile or unsupported evidence. No profile was accepted. Try again or choose another model."

  def error_message(:storage_unavailable),
    do: "The local data directory could not be written. Check its permissions."

  def error_message(_), do: "The operation failed. Check your local configuration and try again."
end
