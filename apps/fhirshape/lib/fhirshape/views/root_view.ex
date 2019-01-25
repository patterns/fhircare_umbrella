defmodule Fhirshape.RootView do
  use Fhirshape, :view

  def render("index.json", %{}) do
    %{data: "fhirshape (github.com/patterns/fhircare_umbrella)"}
  end

end
