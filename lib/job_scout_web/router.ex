defmodule JobScoutWeb.Router do
  use JobScoutWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JobScoutWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JobScoutWeb do
    pipe_through :browser

    live "/", ScoutLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", JobScoutWeb do
  #   pipe_through :api
  # end
end
