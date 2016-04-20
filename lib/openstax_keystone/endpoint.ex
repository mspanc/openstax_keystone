defmodule OpenStax.Keystone.Endpoint do
  @moduledoc """
  This module is responsible for storing configuration of Keystone backends.
  """

  @doc """
  Starts a new agent for storing configuration.
  """
  def start_link(opts \\ []) do
    Agent.start_link(fn -> %{} end, opts)
  end


  @doc """
  Registers new backend that uses username/password for authentication.

  Endpoint URL is a URL to the authentication service, along with /v2.0
  suffix.

  Version has to be :"2.0" at the moment as this is the only supported
  version by this library.

  According to the specification Tenant's ID and Name are mutually exclusive
  so you have to specify only one of them (put nil as second one).
  """
  def register_password(backend_id, version = :"2.0", endpoint_url, tenant_id, tenant_name, username, password) do
    result = Agent.update(OpenStax.Keystone.Endpoint, fn(state) ->
      Map.put(state, backend_id, %{
        endpoint_url: endpoint_url,
        version: version,
        tenant_id: tenant_id,
        tenant_name: tenant_name,
        username: username,
        password: password
      })
    end)

    OpenStax.Keystone.AuthSupervisor.start_worker(backend_id)

    result
  end


  @doc """
  Registers new backend that uses token for authentication.

  Endpoint URL is a URL to the authentication service, along with /v2.0
  suffix.

  Version has to be :"2.0" at the moment as this is the only supported
  version by this library.

  According to the specification Tenant's ID and Name are mutually exclusive
  so you have to specify only one of them (put nil as second one).
  """
  def register_token(backend_id, version = :"2.0", endpoint_url, tenant_id, tenant_name, token) do
    Agent.update(OpenStax.Keystone.Endpoint, fn(state) ->
      Map.put(state, backend_id, %{
        endpoint_url: endpoint_url,
        version: version,
        tenant_id: tenant_id,
        tenant_name: tenant_name,
        token: token
      })
    end)
  end


  @doc """
  Returns current access token for a backend.
  """
  def get_config(backend_id) do
    Agent.get(OpenStax.Keystone.Endpoint, fn(state) ->
      Map.get(state, backend_id)
    end)
  end
end
