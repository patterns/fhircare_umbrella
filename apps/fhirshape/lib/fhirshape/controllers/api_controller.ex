defmodule Fhirshape.ApiController do
  use Fhirshape, :controller

  action_fallback(Fhirshape.FallbackController)

  def index(conn, _params) do
    redirect(conn, to: "/api/v1#{conn.request_path}")
  end

  def create(conn, _params) do
    redirect(conn, to: "/api/v1#{conn.request_path}")
  end

  def show(conn, _id) do
    redirect(conn, to: "/api/v1#{conn.request_path}")
  end

  def update(conn, _params) do
    redirect(conn, to: "/api/v1#{conn.request_path}")
  end

  def delete(conn, _id) do
    redirect(conn, to: "/api/v1#{conn.request_path}")
  end
end
