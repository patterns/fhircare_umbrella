defmodule Fhirshape.Router do
  use Fhirshape, :router

  pipeline :api do
    plug(:accepts, ["json-api"])
  end

  scope "/", Fhirshape do
    pipe_through(:api)
    get("/", RootController, :index)
    resources("/patients", ApiController, except: [:delete])
    resources("/observations", ApiController, except: [:delete])
    resources("/encounters", ApiController, except: [:delete])
    resources("/changes", ApiController, only: [:index])
  end

  scope "/api/v1", Fhirshape.V1, as: :v1 do
    pipe_through(:api)
    resources("/patients", PatientController, except: [:delete])
  end

  scope "/api/v1", Fhirshape.V1, as: :v1, assigns: %{resource_type: "Observation"} do
    pipe_through(:api)
    resources("/observations", VanillaController, except: [:delete])
  end

  scope "/api/v1", Fhirshape.V1, as: :v1, assigns: %{resource_type: "Encounter"} do
    pipe_through(:api)
    resources("/encounters", VanillaController, except: [:delete])
  end

  scope "/api/v1", Fhirshape.V1, as: :v1 do
    pipe_through(:api)
    resources("/changes", ChangeController, only: [:index])
  end
end
