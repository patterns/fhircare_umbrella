defmodule Fhirbuffer.Search do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t()
        }
  defstruct [:id, :type]

  field(:id, 1, type: :string)
  field(:type, 2, type: :string)
end

defmodule Fhirbuffer.Change do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          resource: String.t()
        }
  defstruct [:resource]

  field(:resource, 1, type: :bytes)
end

defmodule Fhirbuffer.Record do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          resource: String.t()
        }
  defstruct [:resource]

  field(:resource, 1, type: :bytes)
end

defmodule Fhirbuffer.Fhirbuffer.Service do
  @moduledoc false
  use GRPC.Service, name: "fhirbuffer.Fhirbuffer"

  rpc(:Read, Fhirbuffer.Search, Fhirbuffer.Record)
  rpc(:Update, Fhirbuffer.Change, Fhirbuffer.Record)
  rpc(:Create, Fhirbuffer.Change, Fhirbuffer.Record)
  rpc(:Delete, Fhirbuffer.Search, Fhirbuffer.Record)
end

defmodule Fhirbuffer.Fhirbuffer.Stub do
  @moduledoc false
  use GRPC.Stub, service: Fhirbuffer.Fhirbuffer.Service
end
