defmodule JobScout.ResumeReader do
  @moduledoc "Extracts plain text from uploaded PDF resumes using Poppler's pdftotext."

  @max_chars 16_000

  def extract_pdf(path) when is_binary(path) do
    with {:ok, header} <- read_header(path),
         true <- String.starts_with?(header, "%PDF-"),
         {:ok, text} <- run_pdftotext(path),
         text <- normalize(text),
         :ok <- validate(text) do
      {:ok, text}
    else
      false -> {:error, :not_a_pdf}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_header(path) do
    case File.open(path, [:read, :binary], fn file -> IO.binread(file, 5) end) do
      {:ok, header} when is_binary(header) -> {:ok, header}
      _ -> {:error, :pdf_read_failed}
    end
  end

  defp run_pdftotext(path) do
    case System.find_executable("pdftotext") do
      nil ->
        {:error, :pdf_tool_missing}

      executable ->
        case System.cmd(executable, ["-layout", "-enc", "UTF-8", path, "-"],
               stderr_to_stdout: true
             ) do
          {text, 0} -> {:ok, text}
          _ -> {:error, :pdf_read_failed}
        end
    end
  rescue
    _ -> {:error, :pdf_read_failed}
  end

  defp normalize(text) do
    text
    |> String.replace("\f", "\n")
    |> String.replace(~r/\r\n?/, "\n")
    |> String.replace(~r/[^\S\n]+/u, " ")
    |> String.trim()
  end

  defp validate(text) do
    cond do
      String.length(text) < 40 -> {:error, :pdf_no_text}
      String.length(text) > @max_chars -> {:error, :pdf_text_too_long}
      true -> :ok
    end
  end

  def error_message(:not_a_pdf), do: "That file is not a valid PDF. Please choose a PDF resume."

  def error_message(:pdf_tool_missing),
    do: "PDF extraction is unavailable. Install Poppler (pdftotext) or use the Docker image."

  def error_message(:pdf_no_text),
    do:
      "This PDF has too little selectable text. If it is scanned, use an OCR version or paste the resume text."

  def error_message(:pdf_text_too_long),
    do:
      "The extracted PDF text is over 16,000 characters. Use a shorter resume or paste an edited excerpt."

  def error_message(:pdf_read_failed),
    do: "The PDF could not be read. Try another PDF or paste the resume text."

  def error_message(_), do: "The PDF could not be processed."
end
