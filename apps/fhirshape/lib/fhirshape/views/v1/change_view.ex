defmodule Fhirshape.V1.ChangeView do
  use Fhirshape, :view
  alias Fhirshape.V1.ChangeView

  def render("index.json", %{changes: changes, paginate: paginate}) do
    %{
      data: render_many(changes, ChangeView, "change.json"),
      links:
        for(
          {key, val} <- paginate,
          into: %{},
          do:
            {key,
             "/api/v1/changes?page[size]=" <>
               to_string(val.size) <>
               "&page[number]=" <> to_string(val.number) <> "&sort=" <> val.sort}
        )
    }
  end

  def render("show.json", %{change: change}) do
    %{data: render_one(change, ChangeView, "change.json")}
  end

  def render("change.json", %{change: change}) do
    # JSON:API (jaserializer or jeregrin/jsonapi can handle this?)
    # by shifting the type and id fields, and putting the rest inside the attributes section

    keep =
      Map.keys(change)
      |> List.delete("id")

    %{
      type: "changes",
      id: change["id"],
      attributes: Map.take(change, keep)
    }
  end
end
