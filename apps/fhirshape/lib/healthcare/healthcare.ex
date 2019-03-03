defmodule Fhirshape.Healthcare do
  @moduledoc """
  The Healthcare context.
  Takes controller calls and passes along to the fhirbuffer service.
  """

  alias Fhirshape.Healthcare.Vanilla
  alias Fhirshape.Healthcare.Patient
  alias Fhirshape.Healthcare.FhirbufferDialer

  # Injection to enable stubbing in tests.
  @fhirbuffer_dialer Application.get_env(:fhirshape, Fhirshape.Healthcare)[:fhirbuffer_dialer] ||
                       FhirbufferDialer

  @doc """
  Gets a single resource.

  Returns nil if the Resource does not exist.

  ## Examples

      iex> get_vanilla(123, "Patient")
      %Vanilla{}

      iex> get_vanilla(456, "Patient")
      nil

  """
  def get_vanilla(id, resource_type) do
    case read_resource(id, resource_type) do
      {:error, _error} -> nil
      {:ok, reply} -> %Vanilla{resource: reply.resource}
    end
  end

  @doc """
  Updates a resource.

  ## Examples

      iex> update_vanilla(vanilla, %{field: new_value})
      {:ok, %Vanilla{}}

      iex> update_vanilla(vanilla, %{field: bad_value})
      {:error, "Resource ID must match record key"}

  """
  def update_vanilla(%Vanilla{} = vanilla, attrs) do
    case Vanilla.update_changeset(vanilla, attrs) do
      {:ok, data} ->
        {:ok, reply} = update_resource(data)
        {:ok, %Vanilla{resource: reply.resource}}

      {:error, %Ecto.Changeset{} = changeset} ->
        source = Jason.decode!(vanilla.resource)
        format_changeset_errors(changeset, source["resourceType"])
    end
  end

  def create_vanilla(attrs) do
    rtype = String.downcase(attrs.resource_type)
    van = empty_resource(attrs.resource_type)

    case Vanilla.create_changeset(van, attrs[rtype]) do
      {:ok, data} ->
        {:ok, reply} = create_resource(data)
        {:ok, %Vanilla{resource: reply.resource}}

      {:error, %Ecto.Changeset{} = changeset} ->
        format_changeset_errors(changeset, attrs.resource_type)
    end
  end

  def delete_vanilla(%Vanilla{} = vanilla) do
    case Vanilla.delete_changeset(vanilla) do
      {:ok, data} ->
        {:ok, reply} = delete_resource(data)
        {:ok, %Vanilla{resource: reply.resource}}

      {:error, %Ecto.Changeset{} = changeset} ->
        format_changeset_errors(changeset, "Patient")
    end
  end

  def create_patient(attrs) do
    case Patient.create_changeset(attrs) do
      {:ok, data} ->
        {:ok, reply} = create_resource(data)
        {:ok, %Patient{resource: reply.resource}}

      {:error, %Ecto.Changeset{} = changeset} ->
        format_changeset_errors(changeset, "Patient")
    end
  end

  def get_patient(id) do
    case read_resource(id, "Patient") do
      {:error, _error} -> nil
      {:ok, reply} -> %Patient{resource: reply.resource}
    end
  end

  def update_patient(%Patient{} = patient, attrs) do
    case Patient.update_changeset(patient, attrs) do
      {:ok, data} ->
        {:ok, reply} = update_resource(data)
        {:ok, %Patient{resource: reply.resource}}

      {:error, %Ecto.Changeset{} = changeset} ->
        format_changeset_errors(changeset, "Patient")
    end
  end

  def delete_patient(%Patient{} = patient) do
    case Patient.delete_changeset(patient) do
      {:ok, data} ->
        {:ok, reply} = delete_resource(data)
        {:ok, %Patient{resource: reply.resource}}

      {:error, %Ecto.Changeset{} = changeset} ->
        format_changeset_errors(changeset, "Patient")
    end
  end

  #
  # 
  #

  # We close the connection after the read (and incur the cost to re-connect per request) to avoid holding on to mem/net resources.
  defp read_resource(id, type) do
    case @fhirbuffer_dialer.dial() do
      {:ok, channel} ->
        try do
          request = Fhirbuffer.Search.new(id: id, type: type)
          Fhirbuffer.Fhirbuffer.Stub.read(channel, request)
        after
          @fhirbuffer_dialer.hangup(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials and common name/indication)"}
    end
  end

  defp update_resource(%{tree: tree}) do
    case @fhirbuffer_dialer.dial() do
      {:ok, channel} ->
        try do
          request = Fhirbuffer.Change.new(resource: Jason.encode!(tree))
          Fhirbuffer.Fhirbuffer.Stub.update(channel, request)
        after
          @fhirbuffer_dialer.hangup(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials)"}
    end
  end

  defp create_resource(%{tree: tree}) do
    case @fhirbuffer_dialer.dial() do
      {:ok, channel} ->
        try do
          request = Fhirbuffer.Change.new(resource: Jason.encode!(tree))
          Fhirbuffer.Fhirbuffer.Stub.create(channel, request)
        after
          @fhirbuffer_dialer.hangup(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials)"}
    end
  end

  defp delete_resource(%{tree: tree}) do
    case @fhirbuffer_dialer.dial() do
      {:ok, channel} ->
        try do
          request = Fhirbuffer.Search.new(id: tree["id"], type: tree["resourceType"])
          Fhirbuffer.Fhirbuffer.Stub.delete(channel, request)
        after
          @fhirbuffer_dialer.hangup(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials and common name/indication)"}
    end
  end

  defp empty_resource(type) do
    amber = Jason.encode!(%{resourceType: type})
    %Vanilla{resource: amber}
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset, type) do
    pairs =
      Ecto.Changeset.traverse_errors(changeset, fn
        {msg, _opts} -> type <> msg
        msg -> type <> msg
      end)

    {:error, pairs.resource}
  end
end
