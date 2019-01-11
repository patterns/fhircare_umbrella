defmodule Fhirshape.Healthcare do
  @moduledoc """
  The Healthcare context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Fhirshape.Healthcare.Patient


  @doc """
  Gets a single patient.

  Raises `Ecto.NoResultsError` if the Patient does not exist.

  ## Examples

      iex> get_patient!(123)
      %Patient{}

      iex> get_patient!(456)
      ** (Ecto.NoResultsError)

  """
  def get_patient!(id) do
    {:ok, json} = read_resource(id, "Patient")
    %Patient{resource: json}
  end


  @doc """
  Updates a patient.

  ## Examples

      iex> update_patient(patient, %{field: new_value})
      {:ok, %Patient{}}

      iex> update_patient(patient, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_patient(%Patient{} = patient, attrs) do
    proposed = Poison.decode!(attrs)
    source = Poison.decode!(patient.resource)

    cond do
      Map.has_key?(source, "id") && source["id"] == proposed["id"] ->
        {:ok, savjson} =
          source
          |> Map.merge(proposed)
          |> Poison.encode!()
          |> update_resource()

        {:ok, %Patient{resource: savjson}}

      true ->
        Logger.debug("Patient ID is ambiguous #{inspect(attrs)}")
        {:error, %Ecto.Changeset{}}
    end
  end



  #
  # May need to break into separate module for gRPC specific logic
  #
  @ca_cert_path Application.get_env(:fhir_shape, :ca_cert_path)
  @cert_path Application.get_env(:fhir_shape, :cert_path)
  @key_path Application.get_env(:fhir_shape, :key_path)
  @fhirbuffer_addr Application.get_env(:fhir_shape, :fhirbuffer_addr)

  defp read_resource(id, type) do
    # We close the connection after the read (and incur the cost to re-connect per request) to avoid holding on to mem/net resources.
    cred =
      GRPC.Credential.new(
        ssl: [
          cacertfile: @ca_cert_path,
          certfile: @cert_path,
          keyfile: @key_path,
          verify: :verify_peer,
          server_name_indication: 'FhirBuffer'
        ]
      )

    opts = [cred: cred]
    request = Fhirbuffer.Search.new(id: id, type: type)

    case GRPC.Stub.connect(@fhirbuffer_addr, opts) do
      {:ok, channel} ->
        try do
          {:ok, reply} = Fhirbuffer.Fhirbuffer.Stub.read(channel, request)
          {:ok, reply.resource}
        after
          GRPC.Stub.disconnect(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials)"}
    end
  end

  defp update_resource(json) do
    # We close the connection after the update (and incur the cost to re-connect per request) to avoid holding on to mem/net resources.
    cred =
      GRPC.Credential.new(
        ssl: [
          cacertfile: @ca_cert_path,
          certfile: @cert_path,
          keyfile: @key_path,
          verify: :verify_peer,
          server_name_indication: 'FhirBuffer'
        ]
      )

    opts = [cred: cred]
    request = Fhirbuffer.Change.new(resource: json)

    case GRPC.Stub.connect(@fhirbuffer_addr, opts) do
      {:ok, channel} ->
        try do
          {:ok, reply} = Fhirbuffer.Fhirbuffer.Stub.update(channel, request)
          {:ok, reply.resource}
        after
          GRPC.Stub.disconnect(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials)"}
    end
  end
 
  
end
