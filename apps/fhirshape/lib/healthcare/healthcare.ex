defmodule Fhirshape.Healthcare do
  @moduledoc """
  The Healthcare context.
  """

  import Ecto.Query, warn: false

  ####require Logger

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
        ####Logger.debug("Patient ID is ambiguous #{inspect(attrs)}")
        {:error, %Ecto.Changeset{}}
    end
  end



  #
  # May need to break into separate module for gRPC specific logic
  #

  defp read_resource(id, type) do
    # We close the connection after the read (and incur the cost to re-connect per request) to avoid holding on to mem/net resources.
    case GRPC.Stub.connect(conf!(:fhirbuffer_addr), tlscred()) do
      {:ok, channel} ->
        try do
          request = Fhirbuffer.Search.new(id: id, type: type)
          {:ok, reply} = Fhirbuffer.Fhirbuffer.Stub.read(channel, request)
          {:ok, reply.resource}
        after
          GRPC.Stub.disconnect(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials and common name/indication)"}
    end
  end

  defp update_resource(json) do
    # We close the connection after the update (and incur the cost to re-connect per request) to avoid holding on to mem/net resources.
    case GRPC.Stub.connect(conf!(:fhirbuffer_addr), tlscred()) do
      {:ok, channel} ->
        try do
          request = Fhirbuffer.Change.new(resource: json)
          {:ok, reply} = Fhirbuffer.Fhirbuffer.Stub.update(channel, request)
          {:ok, reply.resource}
        after
          GRPC.Stub.disconnect(channel)
        end

      _ ->
        {:error, "gRPC connect failed (check TLS credentials)"}
    end
  end

  defp tlscred() do
    cr =
      GRPC.Credential.new(
        ssl: [
          cacertfile: conf!(:ca_cert_path),
          certfile: conf!(:cert_path),
          keyfile: conf!(:key_path),
          verify: :verify_peer,
          server_name_indication: conf!(:fhirbuffer_indication)
        ]
      )

    ####Logger.debug("cred settings #{inspect(cr)}")

    [cred: cr]
  end

  # TLS Configuration settings that are required to connect to the gRPC svc.
  # For example, the cert/key files are a mounted volume of the container.
  defp conf!(key) do
    kls = Application.get_env(:fhirshape, Fhirshape.Healthcare)
    case key do

      :fhirbuffer_addr ->
        Keyword.get(kls, :fhirbuffer_addr)

      :fhirbuffer_indication ->
        to_charlist(Keyword.get(kls, :fhirbuffer_indication))

      k when k in [:ca_cert_path, :cert_path, :key_path] ->
        # With crt/key environment vars look for empty values
        case path = Keyword.get(kls, k) do
          v when v in ["", nil] -> defaultconf(k)
          _ -> path
        end

      _ ->
        raise "Key argument must be one of (:ca_cert_path,:cert_path,:key_path,:fhirbuffer_addr,:fhirbuffer_indication)"
    end
  end

  # In the absence of configured values, fallback to cert/key files in the release.
  defp defaultconf(key) do
    cert_dir = Application.app_dir(:fhirshape, "priv/cert")
    case key do
      :ca_cert_path -> Path.join(cert_dir, "certauthdev.crt")
      :cert_path -> Path.join(cert_dir, "fhirshape.crt")
      :key_path -> Path.join(cert_dir, "fhirshape.key")
    end
  end
end
