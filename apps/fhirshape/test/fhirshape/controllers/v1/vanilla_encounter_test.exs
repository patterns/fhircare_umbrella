defmodule Fhirshape.V1.VanillaEncounterTest do
  use Fhirshape.ConnCase
  use GRPC.Integration.TestCase, async: true

  import Mox

  @ratom :encounter
  @rtype "encounter"
  @rname "Encounter"
  @rpath "/api/v1/encounters"
  @invalid_attrs %{resourceType: "INVALID-TYPE"}
  @base_attrs %{
    resourceType: @rname,
    subject: %{:id => "cd78b515-5a32-4db0-81c6-3ce87904497f", :type => "TEST"}
  }

  # These tests need to go from route to controller to Healthcare module to gRPC service in order to obtain the resource record.
  # With the gRPC service being a external system. We'll need to stub this external service.
  # Taking all the stub logic from the tests in Tony's repo (github.com/tony627/grpc-elixir/tests)
  defmodule VanillaServer do
    use GRPC.Server, service: Fhirbuffer.Fhirbuffer.Service

    @base_resp %{"resourceType" => "Encounter"}

    def read(req, _stream) do
      case Ecto.UUID.cast(req.id) do
        :error ->
          # At the moment, non-existent encounter UUID causes database error which is how the gRPC service throws the exception.
          # In our stub service, we just abuse the fact that keys are UUIDs to simulate error conditions.
          raise GRPC.RPCError, status: :unknown, message: "This is a test (READ), please ignore"

        {:ok, _key} ->
          amber =
            @base_resp
            |> Map.put_new("id", req.id)
            |> Jason.encode!()

          Fhirbuffer.Record.new(resource: amber)
      end
    end

    def update(req, _stream) do
      proposed = Jason.decode!(req.resource)
      rid = proposed["id"]

      case Ecto.UUID.cast(rid) do
        :error ->
          raise GRPC.RPCError, status: :unknown, message: "This is a test (UPDATE), please ignore"

        {:ok, _key} ->
          # Simulate the update by merging proposed changes
          combo =
            @base_resp
            |> Map.merge(proposed)
            |> Jason.encode!()

          Fhirbuffer.Record.new(resource: combo)
      end
    end

    def create(req, _stream) do
      proposed = Jason.decode!(req.resource)

      cond do
        Map.has_key?(proposed, "resourceType") && is_nil(proposed["resourceType"]) == false &&
            proposed["resourceType"] != "" ->
          amber =
            proposed
            |> Map.put_new("id", Ecto.UUID.generate())
            |> Jason.encode!()

          Fhirbuffer.Record.new(resource: amber)

        true ->
          {:error, "Encounter resourceType field is required"}
      end
    end

    def delete(req, _stream) do
      amber =
        @base_resp
        |> Map.put_new("id", req.id)
        |> Jason.encode!()

      Fhirbuffer.Record.new(resource: amber)
    end
  end

  setup_all do
    # Get fhirbuffer svc address (from config/test.exs)
    addr = Application.get_env(:fhirshape, Fhirshape.Healthcare)[:fhirbuffer_addr]
    sport = Application.get_env(:fhirshape, Fhirshape.Healthcare)[:stub_port]

    # Returns extra metadata to be merged into context
    {:ok, [addr: addr, sport: sport]}
  end

  setup context do
    # Before each test.
    {:ok, reply} =
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          amber = Jason.encode!(@base_attrs)
          attrs = %{@rtype => amber, :resource_type => @rname}

          Fhirshape.Healthcare.create_vanilla(attrs)
        end,
        context.sport
      )

    model = Jason.decode!(reply.resource)

    # After test is done.
    on_exit(fn ->
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          amber =
            @base_attrs
            |> Map.put("id", model["id"])
            |> Jason.encode!()

          Fhirshape.Healthcare.delete_vanilla(%Fhirshape.Healthcare.Vanilla{resource: amber})
        end,
        context.sport
      )
    end)

    # Returns extra metadata to be merged into context
    {:ok, [testdata: model]}
  end

  describe "show/2" do
    setup [:verify_on_exit!]

    @tag integration: true
    test "Responds with encounter info if the encounter is found", %{
      conn: conn,
      sport: sport,
      testdata: testdata
    } do
      run_server(
        VanillaServer,
        fn port ->
          # Make client connection to VanillaServer
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          # Inject client connection into Healthcare module; must be paired with fhirbuffer_dialer in config/test.exs
          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          test_id = testdata["id"]

          # Trigger the controller with request
          response =
            conn
            |> get(@rpath <> "/" <> test_id)
            |> json_response(200)

          expected = %{
            "id" => test_id,
            "resourceType" => @rname
          }

          assert response["id"] == expected["id"]
          assert response["resourceType"] == expected["resourceType"]
        end,
        sport
      )
    end

    @tag integration: true
    test "Responds with a message indicating encounter not found", %{conn: conn, sport: sport} do
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          # For clarification, we purposely violate the UUID format here to force a error.
          # We don't actually care about fetching the record from the db. We use the fact
          # that 'zzz' can never be a record key.
          conn = get(conn, @rpath <> "/zzz")

          assert text_response(conn, 404) =~ @rname <> " not found"
        end,
        sport
      )
    end
  end

  describe "update/2" do
    setup [:verify_on_exit!]

    @tag integration: true
    test "Edits, and responds with the encounter if attributes are valid", %{
      conn: conn,
      sport: sport,
      testdata: testdata
    } do
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          test_id = testdata["id"]

          amber =
            @base_attrs
            |> Map.put(:gender, "updatevaluetest")
            |> Map.put(:id, test_id)
            |> Jason.encode!()

          attrs =
            %{}
            |> Map.put(:id, test_id)
            |> Map.put(@ratom, amber)

          response =
            conn
            |> patch(@rpath <> "/" <> test_id, attrs)
            |> json_response(200)

          expected = %{
            "id" => test_id,
            "resourceType" => @rname,
            "gender" => "updatevaluetest"
          }

          assert response["id"] == expected["id"]
          assert response["resourceType"] == expected["resourceType"]
          assert response["gender"] == expected["gender"]
        end,
        sport
      )
    end

    @tag integration: true
    test "Returns an error and does not edit the encounter if attributes are invalid", %{
      conn: conn,
      sport: sport,
      testdata: testdata
    } do
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          test_id = testdata["id"]

          amber =
            @invalid_attrs
            |> Map.put(:gender, "updateerrortest")
            |> Map.put(:id, test_id)
            |> Jason.encode!()

          attrs =
            %{}
            |> Map.put(:id, test_id)
            |> Map.put(@ratom, amber)

          conn = patch(conn, @rpath <> "/" <> test_id, attrs)

          assert text_response(conn, :bad_request) =~ @rname <> " resourceType field is read only"
        end,
        sport
      )
    end
  end

  describe "create/2" do
    setup [:verify_on_exit!]

    @tag integration: true
    test "Creates, and responds with a newly created encounter if attributes are valid", %{
      conn: conn,
      sport: sport
    } do
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          amber =
            @base_attrs
            |> Map.put(:gender, "createvaluetest")
            |> Jason.encode!()

          attrs = %{@ratom => amber}

          response =
            conn
            |> post(@rpath, attrs)
            |> json_response(:created)

          expected = %{
            "resourceType" => @rname,
            "gender" => "createvaluetest"
          }

          assert Map.has_key?(response, "id")
          assert {:ok, key} = Ecto.UUID.cast(response["id"])

          assert response["resourceType"] == expected["resourceType"]
          assert response["gender"] == expected["gender"]
        end,
        sport
      )

      # todo Clean-up after making a new record.
    end

    @tag integration: true
    test "Returns an error and does not create the encounter if attributes are invalid", %{
      conn: conn,
      sport: sport
    } do
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          amber = Jason.encode!(@invalid_attrs)
          attrs = %{@ratom => amber}

          conn = post(conn, @rpath, attrs)

          assert text_response(conn, :bad_request) =~ @rname <> " resourceType field is read only"
        end,
        sport
      )
    end
  end

  describe "delete/2" do
    setup [:temp_encounter, :verify_on_exit!]

    @tag integration: true
    test "Deletes, and responds with :ok if encounter was deleted", %{
      conn: conn,
      sport: sport,
      temp_data: testdata
    } do
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          test_id = testdata["id"]

          response =
            conn
            |> delete(@rpath <> "/" <> test_id)
            |> json_response(200)

          expected = %{
            "id" => test_id,
            "resourceType" => @rname
          }

          assert response["id"] == expected["id"]
          assert response["resourceType"] == expected["resourceType"]
        end,
        sport
      )
    end
  end

  defp temp_encounter(%{sport: sport}) do
    {:ok, reply} =
      run_server(
        VanillaServer,
        fn port ->
          {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

          DialerMock
          |> stub(:dial, fn -> {:ok, channel} end)
          |> stub(:hangup, fn _ -> {:ok, channel} end)

          amber = Jason.encode!(@base_attrs)
          attrs = %{@rtype => amber, :resource_type => @rname}

          Fhirshape.Healthcare.create_vanilla(attrs)
        end,
        sport
      )

    model = Jason.decode!(reply.resource)
    {:ok, [temp_data: model]}
  end
end
