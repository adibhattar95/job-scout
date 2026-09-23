defmodule JobScout.ResumeReaderTest do
  use ExUnit.Case, async: true
  alias JobScout.ResumeReader

  test "extracts selectable text from a real PDF fixture" do
    assert {:ok, text} = ResumeReader.extract_pdf("test/fixtures/resume.pdf")
    assert text =~ "Alex Morgan"
    assert text =~ "Elixir and Phoenix"
  end

  test "rejects a file with a PDF extension but invalid content" do
    path = Path.join(System.tmp_dir!(), "fake-#{System.unique_integer([:positive])}.pdf")
    File.write!(path, "This is not a PDF")
    on_exit(fn -> File.rm(path) end)
    assert {:error, :not_a_pdf} = ResumeReader.extract_pdf(path)
  end

  test "explains scanned or otherwise empty PDFs" do
    assert {:error, :pdf_no_text} = ResumeReader.extract_pdf("test/fixtures/blank.pdf")
  end
end
