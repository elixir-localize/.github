defmodule Mix.Tasks.Blog.Build do
  @shortdoc "Build the static blog site into _site/"
  @moduledoc """
  Builds the blog's static HTML files into the output directory.

      mix blog.build [--output DIR]

  The default output directory is `_site` in the current working directory.
  The directory is deleted and recreated on every build.
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [output: :string])
    output = Keyword.get(opts, :output, "_site")

    Mix.Task.run("app.start")

    {:ok, result} = ElixirLocalize.Generator.build(output)

    Mix.shell().info([
      :green,
      "✓ Built ",
      :reset,
      "#{result.files} files (#{format_bytes(result.bytes)}) → #{result.output}"
    ])
  end

  defp format_bytes(b) when b < 1024, do: "#{b} B"
  defp format_bytes(b) when b < 1024 * 1024, do: "#{Float.round(b / 1024, 1)} KB"
  defp format_bytes(b), do: "#{Float.round(b / 1024 / 1024, 2)} MB"
end
