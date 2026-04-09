defmodule Mix.Tasks.Blog.Serve do
  @shortdoc "Serve the built _site/ directory for local preview"
  @moduledoc """
  Starts a tiny local HTTP server on the built blog directory for previewing
  before publishing. Uses Erlang's built-in `:inets` httpd — no extra deps.

      mix blog.serve [--port 4000] [--dir _site]

  Press `Ctrl+C` twice to stop.
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv, switches: [port: :integer, dir: :string])

    port = Keyword.get(opts, :port, 4000)
    dir = opts |> Keyword.get(:dir, "_site") |> Path.expand()

    unless File.dir?(dir), do: Mix.raise("#{dir} does not exist — run `mix blog.build` first")

    Application.ensure_all_started(:inets)

    {:ok, _pid} =
      :inets.start(:httpd,
        port: port,
        server_name: ~c"localize_blog",
        server_root: String.to_charlist(dir),
        document_root: String.to_charlist(dir),
        directory_index: [~c"index.html"],
        mime_types: [
          {~c"html", ~c"text/html"},
          {~c"css", ~c"text/css"},
          {~c"svg", ~c"image/svg+xml"},
          {~c"xml", ~c"application/rss+xml"},
          {~c"txt", ~c"text/plain"},
          {~c"js", ~c"application/javascript"},
          {~c"ico", ~c"image/x-icon"},
          {~c"png", ~c"image/png"}
        ]
      )

    Mix.shell().info([:green, "Serving ", :reset, "#{dir} at http://localhost:#{port}/"])
    Mix.shell().info("Press Ctrl+C twice to stop.")
    Process.sleep(:infinity)
  end
end
