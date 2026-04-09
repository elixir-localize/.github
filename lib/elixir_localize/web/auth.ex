defmodule ElixirLocalize.Web.Auth do
  @moduledoc """
  Plug that enforces bearer-token authentication on Micropub requests.

  The expected token is read from the `LOCALIZE_BLOG_TOKEN` environment
  variable. Requests with a missing or wrong `Authorization: Bearer <token>`
  header (or `access_token` form parameter, per the Micropub spec) receive a
  401 response.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(options), do: options

  @impl true
  def call(conn, _options) do
    case expected_token() do
      {:ok, expected} ->
        case extract_token(conn) do
          ^expected -> conn
          _ -> deny(conn, "invalid_token")
        end

      :error ->
        deny(conn, "server_misconfigured")
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        token

      ["bearer " <> token] ->
        token

      _ ->
        case conn.params do
          %{"access_token" => token} when is_binary(token) -> token
          _ -> nil
        end
    end
  end

  defp expected_token do
    case System.get_env("LOCALIZE_BLOG_TOKEN") do
      nil -> :error
      "" -> :error
      token -> {:ok, token}
    end
  end

  defp deny(conn, error) do
    body = ~s({"error":"#{error}"})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
    |> halt()
  end
end
