defmodule Fhirshape.V1.VanillaView do
  use Fhirshape, :view
  alias Fhirshape.V1.VanillaView

  def render("index.json", %{vanillas: vanillas}) do
    %{data: render_many(vanillas, VanillaView, "vanilla.json")}
  end

  def render("show.json", %{vanilla: vanilla}) do
    %{data: render_one(vanilla, VanillaView, "vanilla.json")}
  end

  def render("vanilla.json", %{vanilla: vanilla}) do
    %{id: vanilla.id, resource: vanilla.resource}
  end
end
