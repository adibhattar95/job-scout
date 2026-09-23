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

    assert has_element?(
             view,
             "#resume-form [role=alert]",
             "Paste or upload at least 40 characters"
           )
  end

  test "restores the saved profile on a fresh visit", %{conn: conn} do
    path = Path.join(System.tmp_dir!(), "scout-live-#{System.unique_integer([:positive])}")
    store = start_supervised!({JobScout.Store, name: nil, path: path})
    previous_store = Application.get_env(:job_scout, :candidate_store)
    Application.put_env(:job_scout, :candidate_store, store)

    on_exit(fn ->
      if previous_store,
        do: Application.put_env(:job_scout, :candidate_store, previous_store),
        else: Application.delete_env(:job_scout, :candidate_store)

      File.rm_rf!(path)
    end)

    assert :ok =
             JobScout.Store.put(
               "candidate",
               "saved",
               %{
                 profile: %{
                   name: "Alex Morgan",
                   summary: "Built internal APIs in Elixir.",
                   skills: ["Elixir"],
                   roles: ["Software Engineer"],
                   evidence: [%{"id" => "e1", "quote" => "Built internal APIs in Elixir."}]
                 },
                 preferences: %{
                   roles: ["Backend Engineer"],
                   countries: ["IN"],
                   work_mode: "remote",
                   sponsorship: "unknown"
                 },
                 saved_at: "2026-09-22T10:00:00Z"
               },
               store
             )

    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, ".saved-panel", "Your profile is saved locally")
    assert has_element?(view, "#candidate_name[value='Alex Morgan']")
    assert has_element?(view, "#candidate_roles[value='Backend Engineer']")
    assert has_element?(view, "#candidate_countries[value='IN']")
    refute has_element?(view, "#resume-form")

    view |> element("button", "Use a different resume") |> render_click()
    assert has_element?(view, "#resume-form")
  end
end
