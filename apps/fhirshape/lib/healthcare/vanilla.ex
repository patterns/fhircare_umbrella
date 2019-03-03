defmodule Fhirshape.Healthcare.Vanilla do
  use Ecto.Schema
  import Ecto.Changeset

  schema "vanilla" do
    field(:resource, :string)
  end

  @doc false
  def create_changeset(vanilla, attrs) do
    data = %{tree: Jason.decode!(vanilla.resource)}
    types = %{tree: :map}
    proposed = %{tree: Jason.decode!(attrs)}

    {data, types}
    |> cast(proposed, [:tree])
    |> validate_resource_type(data.tree["resourceType"])
    |> apply_action(:insert)
  end

  def update_changeset(vanilla, attrs) do
    # todo use is_* functions to build the list of types (to map id, resourceType keys)
    # then we could use validate_exclude for the id, resourceType fields
    # DEBUG DEBUG
    IO.inspect(attrs, label: "upd-chgs")

    data = %{tree: Jason.decode!(vanilla.resource)}
    types = %{tree: :map}
    proposed = %{tree: Jason.decode!(attrs)}

    {data, types}
    |> cast(proposed, [:tree])
    |> validate_resource_id(data.tree["id"])
    |> validate_resource_type(data.tree["resourceType"])
    |> apply_action(:update)
  end

  def delete_changeset(vanilla) do
    data = %{}
    types = %{tree: :map}
    proposed = %{tree: Jason.decode!(vanilla.resource)}

    {data, types}
    |> cast(proposed, [:tree])
    |> validate_change(:tree, fn :tree, tree ->
      case Map.has_key?(tree, "resourceType") && is_nil(tree["resourceType"]) == false &&
             tree["resourceType"] != "" do
        false -> [resource: " resourceType field is required"]
        true -> []
      end
    end)
    |> apply_action(:delete)
  end

  defp validate_resource_id(changeset, source) do
    validate_change(changeset, :tree, fn _, tree ->
      if Map.has_key?(tree, "id") and String.equivalent?(tree["id"], source) == false do
        [resource: " ID field is read only"]
      else
        []
      end
    end)
  end

  defp validate_resource_type(changeset, source) do
    validate_change(changeset, :tree, fn _, tree ->
      if Map.has_key?(tree, "resourceType") and
           String.equivalent?(tree["resourceType"], source) == false do
        [resource: " resourceType field is read only"]
      else
        []
      end
    end)
  end
end
