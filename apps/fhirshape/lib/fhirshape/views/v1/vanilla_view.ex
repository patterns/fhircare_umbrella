defmodule Fhirshape.V1.VanillaView do
  use Fhirshape, :view
  alias Fhirshape.V1.VanillaView

  def render("index.json", %{vanillas: vanillas, paginate: paginate}) do
    [head | _] = vanillas
    resource_type = head["resourceType"]
    plural = String.downcase(resource_type) <> "s"

    %{
      data: render_many(vanillas, VanillaView, "vanilla.json"),
      links:
        for(
          {key, val} <- paginate,
          into: %{},
          do:
            {key,
             "/api/v1/" <>
               plural <>
               "?page[size]=" <>
               to_string(val.size) <>
               "&page[number]=" <> to_string(val.number) <> "&sort=" <> val.sort}
        )
    }
  end

  def render("show.json", %{vanilla: vanilla}) do
    %{data: render_one(vanilla, VanillaView, "vanilla.json")}
  end

  def render("vanilla.json", %{vanilla: vanilla}) do
    # JSON:API (jaserializer or jeregrin/jsonapi can handle this?)
    # by shifting the type and id fields, and putting the rest inside the attributes section

    plural = String.downcase(vanilla["resourceType"]) <> "s"

    keep =
      Map.keys(vanilla)
      |> List.delete("id")

    %{
      type: plural,
      id: vanilla["id"],
      attributes: Map.take(vanilla, keep)
    }
  end
end
