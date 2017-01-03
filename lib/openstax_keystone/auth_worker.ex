defmodule OpenStax.Keystone.AuthWorker do
  @moduledoc """
  This module is responsible for periodically requesting Auth Token based on
  passed credentials.
  """

  use Connection

  require Logger

  @request_headers [
    {"Connection",    "Close"},
    {"Cache-Control", "no-cache, must-revalidate"},
    {"Content-Type",  "application/json"},
    {"User-Agent",    "OpenStax.Keystone/#{OpenStax.Keystone.version}"}
  ]
  @request_timeout 30000
  @request_options [timeout: @request_timeout, recv_timeout: @request_timeout, follow_redirect: false]
  @retry_timeout   10000
  @logger_tag      "OpenStax.Keystone.AuthWorker"


  def start_link(endpoint_id) do
    Connection.start_link(__MODULE__, endpoint_id, [])
  end


  @doc false
  def init(endpoint_id) do
    s = %{endpoint_id: endpoint_id}
    {:connect, :init, s}
  end


  def connect(_, %{endpoint_id: endpoint_id} = s) do
    case request_token(endpoint_id) do
      :ok ->
        {:ok, s}

      {:error, reason} ->
        {:backoff, reason, @retry_timeout}
    end
  end


  def disconect(:refresh, s) do
    {:connect, :refresh, s}
  end


  def handle_info(:refresh, s) do
    {:disconnect, :refresh, s}
  end


  defp request_token(endpoint_id) do
    config = OpenStax.Keystone.Endpoint.get_config(endpoint_id)

    payload = case config do
      %{tenant_id: tenant_id, tenant_name: tenant_name, username: username, password: password} ->
        cond do
          !is_nil(tenant_id) and !is_nil(tenant_name) ->
            %{auth: %{tenantId: tenant_id, passwordCredentials: %{username: username, password: password}}}

          !is_nil(tenant_id) ->
            %{auth: %{tenantId: tenant_id, passwordCredentials: %{username: username, password: password}}}

          !is_nil(tenant_name) ->
            %{auth: %{tenantName: tenant_name, passwordCredentials: %{username: username, password: password}}}
        end

      %{tenant_id: tenant_id, tenant_name: tenant_name, token: token} ->
        cond do
          !is_nil(tenant_id) and !is_nil(tenant_name) ->
            %{auth: %{tenantId: tenant_id, token: %{id: token}}}

          !is_nil(tenant_id) ->
            %{auth: %{tenantId: tenant_id, token: %{id: token}}}

          !is_nil(tenant_name) ->
            %{auth: %{tenantName: tenant_name, token: %{id: token}}}
        end
    end


    Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retreiving auth token..."
    case HTTPoison.request(:post, config[:endpoint_url] <> "/tokens", Poison.encode!(payload), @request_headers, @request_options) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        case status_code do
          200 ->
            %{"access" => %{"token" => %{"id" => auth_token, "expires" => expires}}} = Poison.decode!(body)

            Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Successfully retreived auth token"
            OpenStax.Keystone.Endpoint.set_auth_token(endpoint_id, auth_token)

            if !is_nil(expires) do
              {:ok, expires_parsed} = Timex.Duration.parse(expires)
              timeout = Timex.to_unix(expires_parsed) - Timex.to_unix(Timex.now())

              Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retreived auth token expires in #{timeout} seconds"

              Process.send_after(self(), :refresh, timeout * 950) # Wait for 95% of expiry time

            else
              Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retrieved auth token is valid indefinitely"
            end

            :ok

          _ ->
            Logger.warn "[#{@logger_tag} #{inspect(endpoint_id)}] Failed to retrieve auth token: got unexpected status code of #{status_code}"
            {:error, {:httpcode, status_code}}
        end

      {:error, reason} ->
        Logger.warn "[#{@logger_tag} #{inspect(endpoint_id)}] Failed to retrieve auth token: got HTTP error #{inspect(reason)}"
        {:error, {:httperror, reason}}
    end
  end
end
