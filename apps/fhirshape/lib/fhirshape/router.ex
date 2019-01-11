defmodule Fhirshape.Router do
  use Fhirshape, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", Fhirshape do
    pipe_through :api

    resources "/patients", PatientController, only: [:show, :update]
  end
end
