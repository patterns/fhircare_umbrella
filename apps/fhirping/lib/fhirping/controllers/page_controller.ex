defmodule Fhirping.PageController do
  use Fhirping, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
