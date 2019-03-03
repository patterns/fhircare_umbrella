defmodule Fhirshape.Router do
  use Fhirshape, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", Fhirshape do
    pipe_through(:api)
    get("/", RootController, :index)
    resources("/patients", ApiController, except: [:index])
    resources("/observations", ApiController, except: [:index])
    resources("/encounters", ApiController, except: [:index])
  end

  scope "/api/v1", Fhirshape.V1, as: :v1 do
    pipe_through(:api)
    resources("/patients", PatientController, except: [:index])
  end

  scope "/api/v1", Fhirshape.V1, as: :v1, assigns: %{resource_type: "Observation"} do
    pipe_through(:api)
    resources("/observations", VanillaController, except: [:index])
  end

  scope "/api/v1", Fhirshape.V1, as: :v1, assigns: %{resource_type: "Encounter"} do
    pipe_through(:api)
    resources("/encounters", VanillaController, except: [:index])
  end
end
