defmodule OpenStax.Keystone.AuthSupervisor do
  @moduledoc """
  This module is responsible for supervising workers that are requesting
  Auth Tokens.
  """

  use Supervisor


  @doc """
  Starts the Supervisor.

  Options are just passed to `Supervisor.start_link`.
  """
  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, :ok, options)
  end


  @doc false
  def init(:ok) do
    supervise([], strategy: :one_for_one)
  end


  @doc """
  Starts worker for specified backend.

  Backend has to be added first to the AuthAgent.
  """
  def start_worker(backend_id) when is_atom(backend_id) do
    case Supervisor.start_child(OpenStax.Keystone.AuthSupervisor, Supervisor.Spec.worker(OpenStax.Keystone.AuthWorker, [backend_id], [id: "OpenStax.KeyStone.AuthWorker##{backend_id}"])) do
      {:ok, _child} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
