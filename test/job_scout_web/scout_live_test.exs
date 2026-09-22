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

  test "rejects invalid resume input with a useful message", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    view |> form("#resume-form", resume: "tiny") |> render_submit()
    render_async(view)
    assert has_element?(view, "[role=alert]", "Paste at least 40 characters")
  end
end
