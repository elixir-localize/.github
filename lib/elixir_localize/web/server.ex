defmodule ElixirLocalize.Web.Server do
  @moduledoc """
  Builds supervisor child specs for the two Bandit servers that
  `mix blog.server` starts:

  * **API server** (`ElixirLocalize.Web.Router`) on port 4010 — Micropub +
    XML-RPC endpoints for MarsEdit.
  * **Preview server** (`ElixirLocalize.Web.PreviewRouter`) on port 4000 —
    static file serving of `_site/` for local browser preview.

  Neither server is started automatically with the application — they are
  only brought up by `mix blog.server`.
  """

  @doc """
  Return a list of child specs for both the API and preview servers.

  ### Arguments

  * `api_port` is the TCP port for the Micropub/XML-RPC server.
    Defaults to `4010`.

  * `preview_port` is the TCP port for the static preview server.
    Defaults to `4000`.

  ### Returns

  * A list of two supervisor child specs.

  """
  @spec child_specs(non_neg_integer(), non_neg_integer()) :: [Supervisor.child_spec()]
  def child_specs(api_port \\ 4010, preview_port \\ 4000) do
    [
      Supervisor.child_spec(
        {Bandit, plug: ElixirLocalize.Web.Router, port: api_port, scheme: :http},
        id: :api_server
      ),
      Supervisor.child_spec(
        {Bandit, plug: ElixirLocalize.Web.PreviewRouter, port: preview_port, scheme: :http},
        id: :preview_server
      )
    ]
  end
end
