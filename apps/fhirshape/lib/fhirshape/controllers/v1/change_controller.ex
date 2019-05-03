defmodule Fhirshape.V1.ChangeController do
  use Fhirshape, :controller

  alias Fhirshape.Healthcare
  action_fallback(Fhirshape.FallbackController)

  def index(conn, params) do
    pgpairs = params["page"]

    limit =
      if pgpairs != nil and pgpairs["size"] != nil,
        do:
          (case Integer.parse(pgpairs["size"]) do
             :error -> 25
             # negatives are nonsense, should error?
             {num, _} when num < 1 -> 25
             # greater than zeros are fine
             {num, _} when num > 0 -> num
           end),
        else: 25

    offset =
      if pgpairs != nil and pgpairs["number"] != nil,
        do:
          (case Integer.parse(pgpairs["number"]) do
             :error -> 1
             # negatives are nonsense, should error?
             {num, _} when num < 1 -> 1
             # greater than zeros are fine
             {num, _} when num > 0 -> num
           end),
        else: 1

    [sort_field, order] =
      if params["sort"] == nil,
        do: ["id", :ASC],
        else:
          (case String.downcase(params["sort"]) do
             "count" -> ["count", :ASC]
             "-count" -> ["count", :DESC]
             "-id" -> ["id", :DESC]
             _ -> ["id", :ASC]
           end)

    page =
      if limit == 0,
        do: nil,
        else: %{limit: limit, offset: offset, order: order, sort_field: sort_field}

    {changes, paginate} = Healthcare.list_changes(page)
    count = to_string(length(changes))

    conn
    |> put_resp_header("x-total-count", count)
    |> render("index.json", %{changes: changes, paginate: paginate})
  end
end
