defmodule Mix.Tasks.Blog.Publish do
  @shortdoc "Build and publish the blog to Cloudflare R2"
  @moduledoc """
  Builds the blog and syncs the output directory to the configured R2 bucket.

      mix blog.publish [--output DIR] [--skip-build]

  R2 credentials are read from environment variables:

  * `R2_ACCOUNT_ID`
  * `R2_ACCESS_KEY_ID`
  * `R2_SECRET_ACCESS_KEY`
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        switches: [output: :string, skip_build: :boolean]
      )

    output = Keyword.get(opts, :output, "_site")
    Mix.Task.run("app.start")

    unless Keyword.get(opts, :skip_build, false) do
      Mix.Task.run("blog.build", ["--output", output])
    end

    case ElixirLocalize.Publisher.sync(output) do
      {:ok, stats} ->
        Mix.shell().info([
          :green,
          "✓ Published ",
          :reset,
          "uploaded: #{stats.uploaded}, skipped: #{stats.skipped}, deleted: #{stats.deleted}"
        ])

      {:error, reason} ->
        Mix.raise("Publish failed: #{inspect(reason)}")
    end
  end
end
