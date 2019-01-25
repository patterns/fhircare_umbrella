defmodule Fhirshape.RootController do
  use Fhirshape, :controller

  action_fallback Fhirshape.FallbackController

  def index(conn, _params) do
    render conn, "index.json"
  end

end
