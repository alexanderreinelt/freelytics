defmodule Freelytics.Router do
  use Plug.Router
  require Logger
  require Ecto.Query

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:match)
  plug(:dispatch)

  get "/get/:root" do
    IO.inspect(root)
    ## if root has http:// https:// it should be removed
    query =
      Ecto.Query.from(a in Freelytics.Analytics,
        where: a.root == ^root,
        select: %{times_visited: a.times_visited, url: a.url}
      )

    entries = Freelytics.Repo.all(query)

    send_resp(conn, 200, Jason.encode!(entries))
  end

  post "/save" do
    {status, body} =
      case conn.body_params do
        %{"root" => root, "url" => url} -> {200, {root, url}}
        _ -> {400, "fails"}
      end

    if status == 400 do
      send_resp(conn, 400, "Wrong arguments.")
    end

    {root, url} = body

    # here we should just update directly in the database
    # without getting the value first and then counting up by 1
    result =
      case Freelytics.Repo.get_by(Freelytics.Analytics, root: root) do
        # Post not found, we build one
        nil ->
          insert_analytics(%Freelytics.Analytics{root: root, url: url, times_visited: 1})

        analytics ->
          update_analytics(analytics)
      end

    case result do
      {:ok, struct} ->
        Logger.info("Updated #{inspect(struct)}")
        send_resp(conn, 200, "")

      {:error, changeset} ->
        Logger.info("Update failed for #{inspect(changeset)}")
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp insert_analytics(analytics) do
    Freelytics.Analytics.changeset(analytics, %{times_visited: analytics.times_visited + 1})
    |> Freelytics.Repo.insert()
  end

  defp update_analytics(analytics) do
    Freelytics.Analytics.changeset(analytics, %{times_visited: analytics.times_visited + 1})
    |> Freelytics.Repo.update()
  end
end
