defmodule OpenStax.Keystone.Endpoint.Config do
  @moduledoc """
  This module is responsible for storing configuration of a single
  Keystone endpoint.
  """

  @type endpoint_url_t :: String.t
  @type tenant_id_t :: String.t
  @type tenant_name_t :: String.t
  @type username_t :: String.t
  @type password_t :: String.t
  @type token_t :: String.t
  @type auth_token_t :: String.t
  @type expires_t :: DateTime.t | nil

  @type t :: %__MODULE__{
    endpoint_url: endpoint_url_t,
    tenant_id: tenant_id_t | nil,
    tenant_name: tenant_name_t | nil,
    username: username_t | nil,
    password: password_t | nil,
    token: token_t | nil,
    auth_token: auth_token_t | nil,
    expires: expires_t
  }

  defstruct \
    endpoint_url: nil,
    tenant_id: nil,
    tenant_name: nil,
    username: nil,
    password: nil,
    token: nil,
    auth_token: nil,
    expires: nil
end