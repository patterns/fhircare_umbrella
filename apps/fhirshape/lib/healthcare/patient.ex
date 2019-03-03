defmodule Fhirshape.Healthcare.Patient do
  use Ecto.Schema
  import Ecto.Changeset

  schema "patient" do
    # The resource is the raw JSON unaltered.
    # We postpone any conversions until it is necessary.
    field(:resource, :string)
  end

  def create_changeset(attrs) do
    # For create, the name is a mandatory field
    # and must be supplied by the input/request.

    data = %{}
    types = %{tree: :map}
    proposed = %{tree: Jason.decode!(attrs)}

    {data, types}
    |> cast(proposed, [:tree])
    |> validate_change(:tree, fn :tree, tree ->
      case Map.has_key?(tree, "name") && is_nil(tree["name"]) == false && tree["name"] != "" do
        false -> [resource: " name field is required"]
        true -> []
      end
    end)
    |> apply_action(:insert)
  end

  def update_changeset(patient, attrs) do
    data = %{tree: Jason.decode!(patient.resource)}
    types = %{tree: :map}
    proposed = %{tree: Jason.decode!(attrs)}

    {data, types}
    |> cast(proposed, [:tree])
    |> validate_change(:tree, fn :tree, tree ->
      case Map.has_key?(tree, "name") && is_nil(tree["name"]) == false && tree["name"] != "" do
        false -> [resource: " name field cannot be blank"]
        true -> []
      end
    end)
    |> apply_action(:update)
  end

  def delete_changeset(patient) do
    data = %{}
    types = %{tree: :map}
    proposed = %{tree: Jason.decode!(patient.resource)}

    {data, types}
    |> cast(proposed, [:tree])
    |> validate_change(:tree, fn :tree, tree ->
      case Map.has_key?(tree, "resourceType") && tree["resourceType"] == "Patient" do
        false -> [resource: " resourceType must be Patient"]
        true -> []
      end
    end)
    |> apply_action(:delete)
  end
end
