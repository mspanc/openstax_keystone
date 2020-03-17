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
      {:ok, nil} ->
        {:ok, s, :hibernate}

      {:ok, timeout} ->
        {:backoff, timeout, s}

      {:error, _reason} ->
        {:backoff, @retry_timeout, s}
    end
  end

  defp request_payload(%{version: :"2.0"} = config) do
    case config do
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
  end

  defp request_payload(%{version: :"3.0"} = config) do
    case config do
      %{project_id: project_id, project_name: project_name, username: username, password: password, domain: domain} ->
        cond do
          !is_nil(project_id) and !is_nil(project_name) ->
            %{auth: %{identity: %{methods: ["password"], password: %{user: %{domain: %{id: domain}, name: username, password: password}}}, scope: %{project: %{domain: %{id: domain}, id: project_id}}}}

          !is_nil(project_id) ->
            %{auth: %{identity: %{methods: ["password"], password: %{user: %{domain: %{id: domain}, name: username, password: password}}}, scope: %{project: %{domain: %{id: domain}, id: project_id}}}}

          !is_nil(project_name) ->
            %{auth: %{identity: %{methods: ["password"], password: %{user: %{domain: %{id: domain}, name: username, password: password}}}, scope: %{project: %{domain: %{id: domain}, name: project_name}}}}
        end

      %{project_id: project_id, project_name: project_name, token: token, domain: domain} ->
        cond do
          !is_nil(project_id) and !is_nil(project_name) ->
            %{auth: %{identity: %{methods: ["token"], token: %{id: token}}, scope: %{project: %{domain: %{id: domain}, id: project_id}}}}

          !is_nil(project_id) ->
            %{auth: %{identity: %{methods: ["token"], token: %{id: token}}, scope: %{project: %{domain: %{id: domain}, id: project_id}}}}

          !is_nil(project_name) ->
            %{auth: %{identity: %{methods: ["token"], token: %{id: token}}, scope: %{project: %{domain: %{id: domain}, name: project_name}}}}
        end
    end
  end

  defp request_url(%{version: :"2.0", endpoint_url: endpoint_url}) do
    "#{endpoint_url}/tokens"
  end

  defp request_url(%{version: :"3.0", endpoint_url: endpoint_url}) do
    "#{endpoint_url}/auth/tokens"
  end

  defp request_token(endpoint_id) do
    config = OpenStax.Keystone.Endpoint.get_config(endpoint_id)

    payload = request_payload(config)
    url = request_url(config)

    Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retreiving auth token..."

    case config[:version] do
      :"2.0" ->
        case HTTPoison.request(:post, url, Poison.encode!(payload), @request_headers, @request_options) do
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            case status_code do
              200 ->
                %{"access" => %{"token" => %{"id" => auth_token, "expires" => expires}}} = Poison.decode!(body)

                Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Successfully retreived auth token"
                OpenStax.Keystone.Endpoint.set_auth_token(endpoint_id, auth_token)

                if !is_nil(expires) do
                  {:ok, expires_parsed} = Timex.parse(expires, "{ISO:Extended}")
                  timeout = Timex.to_unix(expires_parsed) - Timex.to_unix(Timex.now())

                  Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retreived auth token expires in #{timeout} seconds"
                  {:ok, timeout * 950}

                else
                  Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retrieved auth token is valid indefinitely"
                  {:ok, nil}
                end

              _ ->
                Logger.warn "[#{@logger_tag} #{inspect(endpoint_id)}] Failed to retrieve auth token: got unexpected status code of #{status_code}"
                {:error, {:httpcode, status_code}}
            end

          {:error, reason} ->
            Logger.warn "[#{@logger_tag} #{inspect(endpoint_id)}] Failed to retrieve auth token: got HTTP error #{inspect(reason)}"
            {:error, {:httperror, reason}}
        end

      :"3.0" ->
        case HTTPoison.request(:post, url, Poison.encode!(payload), @request_headers, @request_options) do
          {:ok, %HTTPoison.Response{status_code: status_code, headers: headers, body: body}} ->
            case status_code do
              201 ->
                %{"token" => %{"expires_at" => expires}} = Poison.decode!(body)
                case List.keyfind(headers, "X-Subject-Token", 0) do
                  {"X-Subject-Token", auth_token} ->
                    Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Successfully retreived auth token"
                    OpenStax.Keystone.Endpoint.set_auth_token(endpoint_id, auth_token)
    
                    if !is_nil(expires) do
                      {:ok, expires_parsed} = Timex.parse(expires, "{ISO:Extended}")
                      timeout = Timex.to_unix(expires_parsed) - Timex.to_unix(Timex.now())
    
                      Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retreived auth token expires in #{timeout} seconds"
                      {:ok, timeout * 950}
    
                    else
                      Logger.info "[#{@logger_tag} #{inspect(endpoint_id)}] Retrieved auth token is valid indefinitely"
                      {:ok, nil}
                    end

                  _ ->
                    Logger.warn "[#{@logger_tag} #{inspect(endpoint_id)}] Failed to retrieve auth token: no X-Subject-Token header was present"
                    {:error, {:header, headers}}
                end

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
end
