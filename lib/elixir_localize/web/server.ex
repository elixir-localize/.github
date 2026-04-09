defmodule ElixirLocalize.Web.Server do
  @moduledoc """
  Starts Bandit serving the `ElixirLocalize.Web.Router` on the configured
  port for the Micropub editing workflow.

  The server is not started automatically with the application — it is only
  brought up by `mix blog.server`. That keeps the library usable as a
  build-only tool when the server is not wanted.
  """

  @doc """
  Build a child spec for the Bandit server on the given port.

  ### Arguments

  * `port` is the TCP port to listen on. Defaults to `4010` to avoid
    colliding with `mix blog.serve`, which uses `4000`.

  ### Returns

  * A supervisor child spec.

  """
  @spec child_spec(non_neg_integer()) :: Supervisor.child_spec()
  def child_spec(port \\ 4010) do
    {Bandit, plug: ElixirLocalize.Web.Router, port: port, scheme: :http}
  end
end
