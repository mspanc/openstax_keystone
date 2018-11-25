defmodule OpenStax.Keystone.Auth.Worker do
  @moduledoc """
  This module is responsible for periodically requesting Auth Token based on
  passed credentials.
  """

  use Connection
  require Logger
  alias OpenStax.Keystone.Endpoint.Config
  alias OpenStax.Keystone.Endpoint.Registry

  @type options_t :: GenServer.options
  @type on_start_t :: GenServer.on_start

  @request_headers [
    {"Connection",    "Close"},
    {"Cache-Control", "no-cache, must-revalidate"},
    {"Content-Type",  "application/json"},
    {"User-Agent",    "OpenStax.Keystone/#{OpenStax.Keystone.version}"}
  ]
  @request_timeout 30000
  @request_options [timeout: @request_timeout, recv_timeout: @request_timeout, follow_redirect: false]
  @retry_timeout   10000
  @logger_tag      "OpenStax.Keystone.Auth.Worker"

  @doc """
  Starts the process and links it to calling process in the supervision tree.

  Expects endpoint ID as an argument.

  Options and return value are identical to one being used in `GenServer.start_link/3`.
  """
  @spec start_link(Registry.endpoint_id_t, options_t) ::
    on_start_t
  def start_link(endpoint_id, options \\ []) do
    Connection.start_link(__MODULE__, endpoint_id, options)
  end

  @doc false
  def init(endpoint_id) do
    {:connect, :init, %{endpoint_id: endpoint_id}}
  end

  @doc false
  def connect(_, %{endpoint_id: endpoint_id} = state) do
    with \
      {:ok, config} <- 
        OpenStax.Keystone.Endpoint.Registry.get_config(endpoint_id),
      payload <- 
        config_to_payload(config),
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
        HTTPoison.request(:post, "#{config.endpoint_url}/tokens", Jason.encode!(payload), @request_headers, @request_options),
      {:ok, %{"access" => %{"token" => %{"id" => auth_token, "expires" => expires}}}} <-
        Jason.decode(body),
      {:ok, expires} <-
        parse_expires(expires),
      :ok <-
        OpenStax.Keystone.Endpoint.Registry.set_auth_token(endpoint_id, auth_token, expires)
    do
      if not is_nil(expires) do        
        timeout = DateTime.diff(expires, DateTime.utc_now(), :second)

        Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retreived auth token, expires in #{timeout} seconds"
        {:backoff, timeout * 950, state} # Wait for 95% of expiry time
      else
        Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retrieved auth token, valid indefinitely"
        {:ok, state, :hibernate}
      end

    else
      {:error, reason} ->
        Logger.warn "[#{@logger_tag} #{inspect(endpoint_id)}] Failed to retrieve auth token: #{inspect(reason)}"
        {:backoff, @retry_timeout, state}

      {:ok, %HTTPoison.Response{} = response} ->
        Logger.warn "[#{@logger_tag} #{inspect(endpoint_id)}] Failed to retrieve auth token due to unexpected response: #{inspect(response)}"
        {:backoff, @retry_timeout, state}
    end
  end

  defp config_to_payload(%Config{tenant_id: tenant_id, tenant_name: tenant_name, username: username, password: password})
  when is_binary(username) and is_binary(password) and is_binary(tenant_id) and is_nil(tenant_name) do
    %{auth: %{tenantId: tenant_id, passwordCredentials: %{username: username, password: password}}}
  end

  defp config_to_payload(%Config{tenant_id: tenant_id, tenant_name: tenant_name, username: username, password: password})
  when is_binary(username) and is_binary(password) and is_nil(tenant_id) and is_binary(tenant_name) do
    %{auth: %{tenantName: tenant_name, passwordCredentials: %{username: username, password: password}}}
  end

  defp config_to_payload(%Config{tenant_id: tenant_id, tenant_name: tenant_name, token: token})
  when is_binary(token) and is_binary(tenant_id) and is_nil(tenant_name) do
    %{auth: %{tenantId: tenant_id, token: %{id: token}}}
  end

  defp config_to_payload(%Config{tenant_id: tenant_id, tenant_name: tenant_name, token: token})
  when is_binary(token) and is_nil(tenant_id) and is_binary(tenant_name) do
    %{auth: %{tenantName: tenant_name, token: %{id: token}}}
  end

  defp parse_expires(nil), do: nil
  
  defp parse_expires(expires) when is_binary(expires) do
    case DateTime.from_iso8601(expires) do
      {:ok, expires_parsed, _utc_offset} ->
        {:ok, expires_parsed}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
