defmodule OpenStax.Keystone.Auth.Supervisor do
  @moduledoc """
  This module is responsible for supervising workers that are requesting
  Auth Tokens.
  """

  use Supervisor

  @doc """
  Starts the Supervisor.

  Options are just passed to `Supervisor.start_link`.
  """
  @spec start_link(Supervisor.options) :: Supervisor.on_start
  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, :ok, options)
  end

  @doc false
  def init(:ok) do
    Supervisor.init([], strategy: :one_for_one)
  end
end
