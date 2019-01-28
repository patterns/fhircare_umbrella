defmodule Fhirshape.RootView do
  use Fhirshape, :view

  def render("index.json", %{}) do
    %{data: "For a prototype UI, see https://accidental-oil.glitch.me"}
  end

end
