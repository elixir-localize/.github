defmodule ElixirLocalize.Web.PreviewRouter do
  @moduledoc """
  A minimal Plug router that serves the built `_site/` directory as a
  static-file preview. Handles trailing-slash → `index.html` rewriting
  so clean URLs (`/posts/hello-localize/`) work the same as they will on
  Cloudflare R2.

  Started alongside the Micropub API server by `mix blog.server`.
  """

  use Plug.Router

  @site_root Path.expand("_site")

  plug(:rewrite_index)
  plug(Plug.Static, at: "/", from: @site_root, gzip: false)
  plug(:match)
  plug(:dispatch)

  match _ do
    four_oh_four = Path.join(@site_root, "404.html")

    if File.regular?(four_oh_four) do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(404, four_oh_four)
    else
      send_resp(conn, 404, "Not found")
    end
  end

  # Plug.Static won't serve directory index files automatically.
  # If the requested path resolves to a directory in _site/ that
  # contains an index.html, rewrite path_info so Plug.Static finds it.
  defp rewrite_index(conn, _options) do
    joined = Path.join([@site_root | conn.path_info])

    cond do
      File.regular?(joined) ->
        conn

      File.regular?(Path.join(joined, "index.html")) ->
        %{conn | path_info: conn.path_info ++ ["index.html"]}

      true ->
        conn
    end
  end
end
