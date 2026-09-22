defmodule JobScoutWeb.PageController do
  use JobScoutWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
