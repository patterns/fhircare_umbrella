defmodule Fhirshape.V1.PatientView do
  use Fhirshape, :view
  alias Fhirshape.V1.PatientView

  ##  def render("index.json", %{patients: patients}) do
  ##    %{data: render_many(patients, PatientView, "patient.json")}
  ##  end

  def render("index.json", %{patients: patients, paginate: paginate}) do
    %{
      data: render_many(patients, PatientView, "patient.json"),
      links:
        for(
          {key, val} <- paginate,
          into: %{},
          do:
            {key,
             "/api/v1/patients?page[size]=" <>
               to_string(val.size) <>
               "&page[number]=" <> to_string(val.number) <> "&sort=" <> val.sort}
        )
    }
  end

  def render("show.json", %{patient: patient}) do
    %{data: render_one(patient, PatientView, "patient.json")}
  end

  def render("patient.json", %{patient: patient}) do
    # JSON:API (jaserializer or jeregrin/jsonapi can handle this?)
    # by shifting the type and id fields, and putting the rest inside the attributes section

    keep =
      Map.keys(patient)
      |> List.delete("id")

    %{
      type: "patients",
      id: patient["id"],
      attributes: Map.take(patient, keep)
    }
  end
end
