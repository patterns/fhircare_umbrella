defmodule Fhirshape.Healthcare.Dialer do
  # The dialer behaviour requires the implementation of the dial function
  # that will establish the connection to the gRPC service, fhirbuffer

  @callback dial() :: {:ok, GRPC.Channel.t()} | {:error, any}

  @callback hangup(GRPC.Channel.t()) :: {:ok, GRPC.Channel.t()} | {:error, any}
end
