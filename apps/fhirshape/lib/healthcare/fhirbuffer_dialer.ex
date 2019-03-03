# FhirbufferDialer will be our default dialer in production environments.
defmodule Fhirshape.Healthcare.FhirbufferDialer do
  @behaviour Fhirshape.Healthcare.Dialer

  @spec dial() :: {:ok, GRPC.Channel.t()} | {:error, any}
  def dial() do
    GRPC.Stub.connect(conf!(:fhirbuffer_addr), dialoption())
  end

  @spec hangup(GRPC.Channel.t()) :: {:ok, GRPC.Channel.t()} | {:error, any}
  def hangup(channel) do
    GRPC.Stub.disconnect(channel)
  end

  # For production environments, we want TLS enabled as a security measure.
  def dialoption() do
    common_name = conf!(:fhirbuffer_indication)

    cr =
      GRPC.Credential.new(
        ssl: [
          cacertfile: conf!(:ca_cert_path),
          certfile: conf!(:cert_path),
          keyfile: conf!(:key_path),
          verify: :verify_peer,
          server_name_indication: common_name
        ]
      )

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
