defmodule JobScoutWeb.ScoutLiveTest do
  use JobScoutWeb.ConnCase
  import Phoenix.LiveViewTest

  test "serves local onboarding and populates a sample without external calls", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#resume-form")
    assert has_element?(view, ".side-card")
    view |> element("button", "Try a sample resume") |> render_click()
    assert has_element?(view, "#resume", "Alex Morgan")
    refute has_element?(view, "#profile-form")
  end

  test "PDF upload fills the editable resume without calling the model", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    upload =
      file_input(view, "#pdf-upload-form", :resume_pdf, [
        %{
          name: "resume.pdf",
          content: File.read!("test/fixtures/resume.pdf"),
          type: "application/pdf"
        }
      ])

    assert render_upload(upload, "resume.pdf") =~ "100%"
    view |> form("#pdf-upload-form") |> render_submit()

    assert has_element?(view, "#resume", "Alex Morgan")
    assert has_element?(view, "[role=status]", "Text extracted")
    refute has_element?(view, "#profile-form")
  end

  test "invalid PDF is rejected with a clear message", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    upload =
      file_input(view, "#pdf-upload-form", :resume_pdf, [
        %{name: "invalid.pdf", content: "This is not a PDF", type: "application/pdf"}
      ])

    render_upload(upload, "invalid.pdf")
    view |> form("#pdf-upload-form") |> render_submit()
    assert has_element?(view, "[role=alert]", "not a valid PDF")
  end

  test "rejects invalid resume input with a useful message", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    view |> form("#resume-form", resume: "tiny") |> render_submit()
    render_async(view)
    assert has_element?(view, "[role=alert]", "Paste or upload at least 40 characters")
  end
end
