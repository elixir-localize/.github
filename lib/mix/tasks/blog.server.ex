defmodule Mix.Tasks.Blog.Server do
  @shortdoc "Run the blog preview and Micropub editing servers"
  @moduledoc """
  Starts two Bandit servers from a single supervisor:

  * **Preview server** on port 4000 — serves the built `_site/` directory
    for local browser preview. Replaces `mix blog.serve` in most workflows.
  * **API server** on port 4010 — Micropub + XML-RPC endpoint for MarsEdit.

      mix blog.server [--api-port 4010] [--preview-port 4000]

  Before running, set a bearer token in the environment:

      export LOCALIZE_BLOG_TOKEN=some-long-random-string

  MarsEdit configuration:

  * System → Micropub
  * Endpoint: `http://localhost:4010/micropub`
  * Token: whatever you set `LOCALIZE_BLOG_TOKEN` to

  The preview is at `http://localhost:4000/`.

  Every successful create / update / delete rebuilds `_site/` automatically
  from the current contents of `priv/posts/`. Publishing to Cloudflare R2
  remains an explicit step via `mix blog.publish`.

  Press `Ctrl+C` twice to stop.
  """
  use Mix.Task

  alias ElixirLocalize.Web.Server

  @impl Mix.Task
  def run(argv) do
    {options, _, _} =
      OptionParser.parse(argv, switches: [api_port: :integer, preview_port: :integer])

    api_port = Keyword.get(options, :api_port, 4010)
    preview_port = Keyword.get(options, :preview_port, 4000)

    unless System.get_env("LOCALIZE_BLOG_TOKEN") do
      Mix.raise("""
      LOCALIZE_BLOG_TOKEN is not set.

      Generate a long random string and export it before running the server:

          export LOCALIZE_BLOG_TOKEN=$(openssl rand -hex 32)
          mix blog.server
      """)
    end

    Mix.Task.run("app.start")
    Application.ensure_all_started(:bandit)

    # Override the micropub URL so the built _site/ advertises this local
    # endpoint via <link rel="micropub">, which is what MarsEdit (and any
    # other Micropub client) reads during autodetection. A later
    # `mix blog.publish` run from a fresh shell will not see this override
    # and will rebuild with the production URL.
    micropub_url = "http://localhost:#{api_port}/micropub"
    Application.put_env(:elixir_localize, :micropub_url, micropub_url)

    Mix.shell().info([:cyan, "→ Rebuilding _site/ with local micropub URL…"])
    {:ok, _} = ElixirLocalize.Generator.build("_site", ElixirLocalize.RuntimePosts.all())

    children = Server.child_specs(api_port, preview_port)

    {:ok, _pid} =
      Supervisor.start_link(children, strategy: :one_for_one)

    Mix.shell().info([
      :green,
      "✓ Preview   ",
      :reset,
      "http://localhost:#{preview_port}/"
    ])

    Mix.shell().info([
      :green,
      "✓ Micropub  ",
      :reset,
      micropub_url
    ])

    Mix.shell().info("Press Ctrl+C twice to stop.")
    Process.sleep(:infinity)
  end
end
