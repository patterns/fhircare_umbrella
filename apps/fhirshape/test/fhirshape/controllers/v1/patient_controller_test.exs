defmodule Fhirshape.V1.PatientControllerTest do
  use Fhirshape.ConnCase
  use GRPC.Integration.TestCase, async: true

  import Mox

  @ratom :patient
  @rtype "patient"
  @rname "Patient"
  #### @rpath "/api/v1/patients"
  @invalid_attrs %{name: ""}
  @base_attrs %{resourceType: @rname, name: [%{:given => ["Nikola"], :family => "Tesla"}]}

  # These tests need to go from route to controller to Healthcare module to gRPC service in order to obtain the resource record.
  # With the gRPC service being a external system. We'll need to stub this external service.
  # Taking all the stub logic from the tests in Tony's repo (github.com/tony627/grpc-elixir/tests)
  defmodule VanillaServer do
    use GRPC.Server, service: Fhirbuffer.Fhirbuffer.Service

    @base_resp %{"resourceType" => "Patient"}

    def read(req, _stream) do
      case Ecto.UUID.cast(req.id) do
        :error ->
          # At the moment, non-existent patient UUID causes database error which is how the gRPC service throws the exception.
          # In our stub service, we just abuse the fact that keys are UUIDs to simulate error conditions.
          raise GRPC.RPCError, status: :unknown, message: "This is a test (READ), please ignore"

        {:ok, _key} ->
          amber =
            @base_resp
            |> Map.put_new(:id, req.id)
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
        Map.has_key?(proposed, "name") && proposed["name"] != nil ->
          amber =
            proposed
            |> Map.put_new("id", Ecto.UUID.generate())
            |> Jason.encode!()

          Fhirbuffer.Record.new(resource: amber)

        true ->
          {:error, "Patient must specify the name field"}
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

    # Make available via ExUnit context
    {:ok, %{addr: addr, sport: sport}}
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

          amber =
            @base_attrs
            |> Map.put_new(:temporaryseqnum, "f247d8de-3acb-42e1-b665-f288b427e5a8")
            |> Jason.encode!()

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
            |> Map.put(:id, model["id"])
            |> Jason.encode!()

          # todo DEBUG  should refactor to delete_vanilla for stubbed test context
          Fhirshape.Healthcare.delete_patient(%Fhirshape.Healthcare.Patient{resource: amber})
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
    test "Responds with patient info if the patient is found", %{
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
            |> get(Routes.v1_patient_path(conn, :show, test_id))
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
    test "Responds with a message indicating patient not found", %{conn: conn, sport: sport} do
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
          conn = get(conn, Routes.v1_patient_path(conn, :show, "zzz"))

          assert text_response(conn, 404) =~ @rname <> " not found"
        end,
        sport
      )
    end
  end

  describe "update/2" do
    setup [:verify_on_exit!]

    @tag integration: true
    test "Edits, and responds with the patient if attributes are valid", %{
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
            |> patch(Routes.v1_patient_path(conn, :update, test_id), attrs)
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
    test "Returns an error and does not edit the patient if attributes are invalid", %{
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

          conn = patch(conn, Routes.v1_patient_path(conn, :update, test_id), attrs)

          assert text_response(conn, :bad_request) =~ @rname <> " name field cannot be blank"
        end,
        sport
      )
    end
  end

  describe "create/2" do
    setup [:verify_on_exit!]

    @tag integration: true
    test "Creates, and responds with a newly created patient if attributes are valid", %{
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
            |> post(Routes.v1_patient_path(conn, :create), attrs)
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
    test "Returns an error and does not create the patient if attributes are invalid", %{
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

          conn = post(conn, Routes.v1_patient_path(conn, :create), attrs)

          assert text_response(conn, 400) =~ @rname <> " name field is required"
        end,
        sport
      )
    end
  end

  describe "delete/2" do
    setup [:temp_patient, :verify_on_exit!]

    @tag integration: true
    test "Deletes, and responds with :ok if patient was deleted", %{
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
            |> delete(Routes.v1_patient_path(conn, :delete, test_id))
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

  describe "index/2" do
    setup [:verify_on_exit!]

    @tag integration: false
    test "Responds with all Patients maxed at 100", %{
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

          response =
            conn
            |> get(Routes.v1_patient_path(conn, :index))
            |> json_response(200)

          count = length(response["data"])

          assert count != 0
          assert count <= 100
        end,
        sport
      )
    end

    @tag integration: false
    test "Responds with paginated set of Patients", %{
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

          expected_seq = testdata["temporaryseqnum"]
          sort_field = "ts"
          limit = 10

          response =
            conn
            |> get(
              Routes.v1_patient_path(conn, :index,
                _end: limit,
                _order: "DESC",
                _sort: sort_field,
                _start: 0
              )
            )
            |> json_response(200)

          count = length(response["data"])

          matched =
            response["data"]
            |> Enum.find(fn row ->
              row["attributes"]["temporaryseqnum"] == expected_seq
            end)

          assert count != 0
          assert count <= limit
          assert matched != nil

          # TODO BUG the id field inside the JSON resource is not persisted
          #### assert matched["id"] == testdata["id"]
        end,
        sport
      )
    end

    @tag integration: false
    test "Responds with redirect", %{
      conn: conn
    } do
      conn = get(conn, "/patients")

      assert conn.status == 302
      assert String.contains?(conn.resp_body, "href=\"/api/v1/patients\"")
    end
  end

  defp temp_patient(%{sport: sport}) do
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
