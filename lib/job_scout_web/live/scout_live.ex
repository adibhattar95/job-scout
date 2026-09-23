defmodule JobScoutWeb.ScoutLive do
  use JobScoutWeb, :live_view
  alias JobScout.{Preferences, Profile, ResumeReader, Runner}

  @example """
  Alex Morgan
  Software Engineer
  Built REST APIs in Elixir and Phoenix for an internal scheduling application.
  Worked with PostgreSQL, ExUnit, Git and Docker.
  Collaborated with designers to improve accessibility in customer-facing forms.
  Education: Bachelor of Computer Science.
  """

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:resume_pdf, accept: ~w(.pdf), max_entries: 1, max_file_size: 10_000_000)
     |> assign(
       resume: "",
       resume_form: to_form(%{"resume" => ""}),
       busy: false,
       profile: nil,
       run: nil,
       saved_id: nil,
       model: JobScout.LLM.Ollama.model(),
       profile_form: to_form(%{}, as: :candidate),
       error: nil,
       uploaded_filename: nil
     )}
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :resume_pdf, ref)}
  end

  def handle_event("parse_pdf", _params, socket) do
    case consume_uploaded_entries(socket, :resume_pdf, fn %{path: path}, entry ->
           {:ok, {entry.client_name, ResumeReader.extract_pdf(path)}}
         end) do
      [{filename, {:ok, text}}] ->
        {:noreply,
         assign(socket,
           resume: text,
           resume_form: to_form(%{"resume" => text}),
           uploaded_filename: filename,
           profile: nil,
           error: nil
         )}

      [{_filename, {:error, reason}}] ->
        {:noreply, assign(socket, error: ResumeReader.error_message(reason))}

      _ ->
        {:noreply, assign(socket, error: "Choose a PDF resume to upload first.")}
    end
  end

  def handle_event("example", _, socket),
    do:
      {:noreply,
       assign(socket,
         resume: @example,
         resume_form: to_form(%{"resume" => @example}),
         uploaded_filename: nil,
         error: nil
       )}

  def handle_event("extract", %{"resume" => resume}, socket) do
    if socket.assigns.busy do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(
         resume_form: to_form(%{"resume" => resume}),
         resume: resume,
         busy: true,
         error: nil,
         profile: nil,
         saved_id: nil,
         run: nil
       )
       |> start_async(:extract, fn -> Runner.extract(resume) end)}
    end
  end

  def handle_event("cancel", _, socket) do
    {:noreply,
     socket |> cancel_async(:extract) |> assign(busy: false, error: "Extraction cancelled.")}
  end

  def handle_event("save", %{"candidate" => attrs}, socket) do
    profile_attrs =
      Map.take(attrs, ["name", "summary", "seniority"])
      |> Map.put("skills", split(attrs["skills"]))

    with %Profile{} = original <- socket.assigns.profile,
         {:ok, profile} <-
           Profile.changeset(original, profile_attrs) |> Ecto.Changeset.apply_action(:update),
         {:ok, preferences} <-
           Preferences.from_form(
             Map.take(attrs, ["countries", "roles", "work_mode", "sponsorship"])
           ),
         {:ok, id} <- Runner.save_candidate(profile, preferences) do
      {:noreply,
       assign(socket,
         profile: profile,
         saved_id: id,
         error: nil,
         profile_form: to_form(attrs, as: :candidate)
       )}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        message =
          changeset.errors
          |> Enum.map_join(" · ", fn {key, {message, _}} -> "#{key}: #{message}" end)

        {:noreply, assign(socket, error: message, profile_form: to_form(attrs, as: :candidate))}

      _ ->
        {:noreply,
         assign(socket, error: "Could not save the candidate. Check the local data directory.")}
    end
  end

  def handle_async(:extract, {:ok, {:ok, profile, run}}, socket) do
    form = %{
      "name" => profile.name || "",
      "summary" => profile.summary,
      "seniority" => profile.seniority || "",
      "skills" => Enum.join(profile.skills, ", "),
      "roles" => "",
      "countries" => "",
      "work_mode" => "any",
      "sponsorship" => "unknown"
    }

    {:noreply,
     assign(socket,
       busy: false,
       profile: profile,
       run: run,
       profile_form: to_form(form, as: :candidate)
     )}
  end

  def handle_async(:extract, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, busy: false, error: Runner.error_message(reason))}
  end

  def handle_async(:extract, {:exit, _}, socket) do
    {:noreply,
     assign(socket,
       busy: false,
       error: socket.assigns.error || "Extraction stopped. You can try again."
     )}
  end

  defp upload_error_message(:too_large), do: "The PDF exceeds the 10 MB upload limit."
  defp upload_error_message(:too_many_files), do: "Upload one PDF at a time."
  defp upload_error_message(:not_accepted), do: "Only PDF files are accepted."
  defp upload_error_message(_), do: "The upload could not be completed."

  defp split(value),
    do:
      (value || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="scout-shell">
        <header class="scout-header">
          <a href="/" class="scout-brand"><span class="scout-mark"><.icon
            name="hero-arrow-up-right"
            class="size-6"
          /></span>
          Job Scout</a>
          <span class="local-badge"><span></span> Local workspace</span>
        </header>
        <main>
          <section class="scout-hero">
            <p class="eyebrow">YOUR NEXT CHAPTER</p>
            <h1>A better search starts<br />with your story.</h1>
            <p class="hero-copy">
              Build a profile from your experience. Set your own direction.<br />Keep the facts that make you, you.
            </p>
          </section>
          <nav class="step-bar" aria-label="Progress">
            <span class="active"><b>01</b> Your profile</span>
            <span><b>02</b> Discover jobs <small>Coming next</small></span>
            <span><b>03</b> Tailor & apply <small>Planned</small></span>
          </nav>
          <div :if={@error} role="alert" class="scout-alert">{@error}</div>
          <div class="scout-grid">
            <section class="scout-card">
              <div class="card-heading">
                <h2>Your experience, in your words</h2><span class="subtle">01 / INPUT</span>
              </div>
              <p class="muted">
                Upload a text-based PDF or paste your resume. Review the extracted text before building your profile.
              </p>
              <.form
                for={to_form(%{})}
                phx-change="validate_upload"
                phx-submit="parse_pdf"
                id="pdf-upload-form"
              >
                <label for={@uploads.resume_pdf.ref}>PDF resume · up to 10 MB</label>
                <.live_file_input upload={@uploads.resume_pdf} class="resume-file-input" />
                <div :for={entry <- @uploads.resume_pdf.entries} class="upload-entry">
                  <span>{entry.client_name} · {trunc(entry.progress)}%</span>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    class="text-button"
                  >Remove</button>
                </div>
                <p :for={error <- upload_errors(@uploads.resume_pdf)} role="alert" class="scout-alert">
                  {upload_error_message(error)}
                </p>
                <button
                  type="submit"
                  class="secondary-button"
                  disabled={@busy || @uploads.resume_pdf.entries == []}
                >Extract text from PDF</button>
                <p :if={@uploaded_filename} role="status" class="saved-message">
                  Text extracted from {@uploaded_filename}. Check it below before continuing.
                </p>
              </.form>
              <div class="upload-divider"><span>or paste text</span></div>
              <.form for={@resume_form} phx-submit="extract" id="resume-form">
                <.input
                  field={@resume_form[:resume]}
                  id="resume"
                  type="textarea"
                  label="Resume text"
                  minlength="40"
                  maxlength="16000"
                  required
                  rows="12"
                  placeholder="Name, experience, projects, skills, education…"
                  disabled={@busy}
                />
                <div class="form-footer">
                  <button type="button" phx-click="example" disabled={@busy} class="text-button">Try a sample resume</button><span class="subtle">Up to 16,000 characters</span>
                </div>
                <button type="submit" disabled={@busy} class="primary-button">{if @busy,
                  do: "Reading your resume…",
                  else: "Build my profile →"}</button>
                <button :if={@busy} type="button" phx-click="cancel" class="text-button cancel-button">Cancel</button>
                <p :if={@busy} role="status" class="muted">
                  Your local model is working. The first run may take a few minutes.
                </p>
              </.form>
            </section>
            <aside class="scout-card side-card">
              <span class="eyebrow">BUILT AROUND YOU</span>
              <h2>Your search.<br />Your boundaries.</h2>
              <ul class="principles">
                <li>
                  <span><.icon name="hero-computer-desktop" class="size-4" /></span><div>
                    <strong>Local intelligence</strong><p>
                      Resume extraction runs on your computer with Ollama.
                    </p>
                  </div>
                </li>
                <li>
                  <span><.icon name="hero-check" class="size-4" /></span><div>
                    <strong>Evidence you can inspect</strong><p>
                      Source quotes are checked against your resume. Review the extracted facts before saving.
                    </p>
                  </div>
                </li>
                <li>
                  <span><.icon name="hero-arrow-up-right" class="size-4" /></span><div>
                    <strong>You choose the destination</strong><p>
                      Set target roles, countries and work preferences after extraction.
                    </p>
                  </div>
                </li>
              </ul>
              <div class="model-box">
                <span class="subtle">LOCAL MODEL</span><code>{@model}</code>
              </div>
              <p class="muted small">No job-source requests are made in this milestone.</p>
            </aside>
          </div>
          <section :if={@profile} class="scout-card review-card" id="profile-review">
            <div class="card-heading">
              <h2>Review your profile & choose your direction</h2><span class="subtle">02 / REVIEW</span>
            </div>
            <p class="muted">
              Correct any extraction mistakes. Only add facts you can support. Countries are your choice, not inferred from the resume.
            </p>
            <.form for={@profile_form} id="profile-form" phx-submit="save">
              <div class="field-grid">
                <.input field={@profile_form[:name]} label="Name" />
                <.input field={@profile_form[:seniority]} label="Seniority" />
              </div>
              <.input field={@profile_form[:summary]} type="textarea" label="Profile summary" />
              <.input field={@profile_form[:skills]} label="Skills (comma separated)" />
              <div class="field-grid">
                <.input field={@profile_form[:roles]} label="Target roles (comma separated)" required />
                <.input
                  field={@profile_form[:countries]}
                  label="Country codes, e.g. IN, GB, DE"
                  required
                />
                <.input
                  field={@profile_form[:work_mode]}
                  type="select"
                  label="Work preference"
                  options={[
                    {"Any", "any"},
                    {"Remote", "remote"},
                    {"Hybrid", "hybrid"},
                    {"On-site", "onsite"}
                  ]}
                />
                <.input
                  field={@profile_form[:sponsorship]}
                  type="select"
                  label="Sponsorship"
                  options={[
                    {"Not specified", "unknown"},
                    {"Required", "required"},
                    {"Not required", "not_required"}
                  ]}
                />
              </div>
              <details>
                <summary>View source evidence ({length(@profile.evidence)})</summary><blockquote :for={
                  e <- @profile.evidence
                }>
                  {e["quote"]}
                </blockquote>
              </details>
              <button class="primary-button" type="submit">Save reviewed profile</button>
            </.form>
            <p :if={@saved_id} role="status" class="saved-message">
              Profile saved locally. Job discovery is the next milestone.
            </p>
            <div :if={@run} class="run-footer">
              Run {@run.id} · {Float.round(@run.duration_ms / 1000, 1)}s · Local inference · {@run.prompt_version}
            </div>
          </section>
        </main>
        <footer class="scout-footer">
          Made for thoughtful applications. You stay in control.<span>Phase 1 · Foundation</span>
        </footer>
      </div>
    </Layouts.app>
    """
  end
end
