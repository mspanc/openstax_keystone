defmodule OpenStax.Keystone.Endpoint.Registry do
  @moduledoc """
  This module is responsible for storing registry of Keystone endpoints.
  """

  alias OpenStax.Keystone.Endpoint.Config
  require Logger

  @logger_tag "OpenStax.Keystone.Endpoint.Registry"

  @typedoc "Endpoint identifier"
  @type endpoint_id_t :: Map.key()

  @typedoc "Options passed while starting registry"
  @type options_t :: GenServer.options

  @typedoc "Return value of starting registry"
  @type on_start_t :: Agent.on_start

  @doc """
  Starts a new registry for storing configuration and links it to the
  calling process.
  """
  @spec start_link(options_t) :: on_start_t
  def start_link(opts \\ []) do
    Agent.start_link(fn -> %Config{} end, opts)
  end

  @doc """
  Registers new endpoint that uses username/password for authentication.

  Endpoint URL is a URL to the authentication service, along with /v2.0
  suffix.
  
  According to the specification Tenant's ID and Name are mutually exclusive
  so you have to specify only one of them (put nil as second one).

  It returns `:ok` on success, `{:error, reason}` otherwise.

  FIXME: currently in case of trying to register the two endpoints with the same
  ID the configuration of the existing endpoint will be overridden despite
  returning the error.
  """
  @spec register_password(endpoint_id_t, Config.endpoint_url_t, Config.tenant_id_t, Config.tenant_name_t, Config.username_t, Config.password_t) ::
    :ok |
    {:error, any}
  def register_password(endpoint_id, endpoint_url, tenant_id, tenant_name, username, password) do
    with \
      :ok <- 
        Agent.update(OpenStax.Keystone.Endpoint.Registry, fn(state) ->
          Map.put(state, endpoint_id, %Config{
            endpoint_url: endpoint_url,
            tenant_id: tenant_id,
            tenant_name: tenant_name,
            username: username,
            password: password,
            auth_token: nil
          })
        end),
      {:ok, _child} <- 
        Supervisor.start_child(OpenStax.Keystone.Auth.Supervisor, Supervisor.Spec.worker(OpenStax.Keystone.Auth.Worker, [endpoint_id], [id: worker_id(endpoint_id)]))
    do
      Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Registered endpoint for #{endpoint_url} with password authentication"
      :ok
    else
      {:error, {:already_started, _pid}} ->
        {:error, :already_registered}
      {:error, :already_present} ->
        {:error, :already_registered}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Registers new endpoint that uses token for authentication.

  Endpoint URL is a URL to the authentication service, along with /v2.0
  suffix.
  
  According to the specification Tenant's ID and Name are mutually exclusive
  so you have to specify only one of them (put nil as second one).

  It returns `:ok` on success, `{:error, reason}` otherwise.

  Possible error reasons are:

  * `:already_registered` - endpoint with given ID is already registered

  FIXME: currently in case of trying to register the two endpoints with the same
  ID the configuration of the existing endpoint will be overridden despite
  returning the error.
  """
  @spec register_token(endpoint_id_t, Config.endpoint_url_t, Config.tenant_id_t, Config.tenant_name_t, Config.token_t) ::
    :ok |
    {:error, any}
  def register_token(endpoint_id, endpoint_url, tenant_id, tenant_name, token) do
    with \
      :ok <- 
        Agent.update(OpenStax.Keystone.Endpoint.Registry, fn(state) ->
          Map.put(state, endpoint_id, %Config{
            endpoint_url: endpoint_url,
            tenant_id: tenant_id,
            tenant_name: tenant_name,
            token: token,
            auth_token: nil
          })
        end),
      {:ok, _child} <-
        Supervisor.start_child(OpenStax.Keystone.Auth.Supervisor, Supervisor.Spec.worker(OpenStax.Keystone.Auth.Worker, [endpoint_id], [id: worker_id(endpoint_id)]))
    do
      Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Registered endpoint for #{endpoint_url} with token authentication"
      :ok
    else
      {:error, {:already_started, _pid}} ->
        {:error, :already_registered}
      {:error, :already_present} ->
        {:error, :already_registered}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns current configuration for the given endpoint.

  It returns `{:ok, config}` on success, `{:error, reason}` otherwise.

  Possible error reasons are:

  * `:invalid_endpoint_id` - endpoint with given ID is not registered
  """
  @spec get_config(endpoint_id_t, timeout) ::
    {:ok, Config.t} |
    {:error, any}
  def get_config(endpoint_id, timeout \\ 5000) do
    Agent.get(OpenStax.Keystone.Endpoint.Registry, fn(state) ->
      case Map.get(state, endpoint_id) do
        nil ->
          {:error, :invalid_endpoint_id}
        config ->
          {:ok, config}
      end
    end, timeout)
  end

  @doc """
  Returns current auth token for the given endpoint.

  It returns `{:ok, {auth_token, expires}}` on success, `{:error, reason}` 
  otherwise.

  It is up to the application to check if auth token has not expired
  before usage.

  Possible error reasons are:

  * `:invalid_endpoint_id` - endpoint with given ID is not registered
  """
  @spec get_auth_token(endpoint_id_t, timeout) ::
    {:ok, {Config.auth_token_t, Config.expires_t}} |
    {:error, any}
  def get_auth_token(endpoint_id, timeout \\ 5000) do
    Agent.get(OpenStax.Keystone.Endpoint.Registry, fn(state) ->
      case Map.get(state, endpoint_id) do
        nil ->
          {:error, :invalid_endpoint_id}
        config ->
          {:ok, {config.auth_token, config.expires}}
      end
    end, timeout)
  end

  @doc """
  Sets the auth token for the given endpoint.
  """
  @spec set_auth_token(endpoint_id_t, Config.auth_token_t, DateTime.t | nil) ::
    :ok |
    {:error, any}
  def set_auth_token(endpoint_id, auth_token, expires) when is_binary(auth_token) do
    Agent.update(OpenStax.Keystone.Endpoint.Registry, fn(state) ->
      case Map.get(state, endpoint_id) do
        nil ->
          {:error, :invalid_endpoint_id}
        config ->
          Map.put(state, endpoint_id, %{config | auth_token: auth_token, expires: expires})
      end
    end)
  end

  defp worker_id(endpoint_id), do: "OpenStax.KeyStone.Auth.Worker##{endpoint_id}"
end
