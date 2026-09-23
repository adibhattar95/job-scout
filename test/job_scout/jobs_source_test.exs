defmodule JobScout.JobsSourceTest do
  use ExUnit.Case, async: true
  alias JobScout.Jobs.{JSearch, Remotive}
  alias JobScout.Store

  setup do
    path = Path.join(System.tmp_dir!(), "jobs-source-#{System.unique_integer([:positive])}")
    store = start_supervised!({Store, name: nil, path: path})
    on_exit(fn -> File.rm_rf!(path) end)
    %{store: store}
  end

  test "Remotive fetches once and credits the source link", %{store: store} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(__MODULE__, fn conn ->
      Agent.update(counter, &(&1 + 1))

      Req.Test.json(conn, %{
        jobs: [
          %{
            id: 42,
            title: "Data Scientist",
            company_name: "Example Co",
            candidate_required_location: "Worldwide",
            url: "https://remotive.com/remote-jobs/data-scientist-42",
            description: "<p>Build models with Python &amp; SQL.</p>"
          }
        ]
      })
    end)

    opts = [
      store: store,
      now: ~U[2026-09-23 10:00:00Z],
      request_options: [plug: {Req.Test, __MODULE__}]
    ]

    assert {:ok, [job], :live} = Remotive.fetch(opts)
    assert job.source == "Remotive"
    assert job.url == "https://remotive.com/remote-jobs/data-scientist-42"
    assert job.description =~ "Build models"
    assert {:ok, [_], :cached} = Remotive.fetch(opts)
    assert Agent.get(counter, & &1) == 1
  end

  test "JSearch uses one request for a city query and caches the result", %{store: store} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(__MODULE__, fn conn ->
      Agent.update(counter, &(&1 + 1))
      params = URI.decode_query(conn.query_string)
      assert params["query"] == "Data Scientist jobs in London, GB"
      assert params["country"] == "gb"
      assert params["work_from_home"] == "true"
      assert Plug.Conn.get_req_header(conn, "x-api-key") == ["test-key"]

      Req.Test.json(conn, %{
        data: %{
          jobs: [
            %{
              job_id: "job-1",
              job_title: "Data Scientist",
              employer_name: "Example Co",
              job_location: "London, GB",
              job_apply_link: "https://example.com/jobs/1",
              job_description: "Python and SQL modelling",
              job_is_remote: true
            }
          ]
        }
      })
    end)

    opts = [
      store: store,
      now: ~U[2026-09-23 10:00:00Z],
      key: "test-key",
      request_options: [plug: {Req.Test, __MODULE__}]
    ]

    assert {:ok, [job], :live} = JSearch.search("Data Scientist", "London, GB", "remote", opts)
    assert job.company == "Example Co"
    assert {:ok, [_], :cached} = JSearch.search("Data Scientist", "London, GB", "remote", opts)
    assert Agent.get(counter, & &1) == 1
    assert {:ok, 1} = Store.jsearch_usage(store, ~D[2026-09-23])
  end

  test "JSearch without a key makes no request or quota reservation", %{store: store} do
    assert {:error, :not_configured} =
             JSearch.search("Engineer", "Amsterdam, NL", "any",
               store: store,
               key: nil,
               now: ~U[2026-09-23 10:00:00Z]
             )

    assert {:ok, 0} = Store.jsearch_usage(store, ~D[2026-09-23])
  end
end
