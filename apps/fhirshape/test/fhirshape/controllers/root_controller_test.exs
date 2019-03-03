defmodule Fhirshape.RootControllerTest do
  use Fhirshape.ConnCase

  test "index/2 responds with Glitch URL", %{conn: conn} do
    response =
      conn
      |> get(Routes.root_path(conn, :index))
      |> json_response(200)

    expected = %{
      "data" => "For a prototype UI, see https://accidental-oil.glitch.me"
    }

    assert response == expected
  end
end
