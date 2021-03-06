defmodule OpenStax.Keystone do
  @moduledoc ~S"""
  OpenStax Keystone provides bindings for OpenStack Identity v2.0 API for the
  Elixir programming language.

  It is currently capable of periodically retreiving token from the endpoint.

  It supports adding multiple endpoints in the runtime, but if you want you may
  add only one during startup.

  ## Installation

  Add the following tuple to `deps` in your `mix.exs`:

      {:openstax_keystone, "~> 1.0"}

  ## Examples

  If you use username/password authentication, and Tenant ID as your identifier,
  use the following code in order to add the new keystone endpoint:

      OpenStax.Keystone.Endpoint.Registry.register_password(:myendpoint, "https://auth.example.com/v2.0", "my_tenant_id", nil, "john", "secret")

  If you use username/password authentication, and Tenant Name as your identifier,
  use the following code in order to add the new keystone endpoint:

      OpenStax.Keystone.Endpoint.Registry.register_password(:myendpoint, "https://auth.example.com/v2.0", nil, "my_tenant_name", "john", "secret")

  If you use token authentication, and Tenant ID as your identifier,
  use the following code in order to add the new keystone endpoint:

      OpenStax.Keystone.Endpoint.Registry.register_token(:myendpoint, "https://auth.example.com/v2.0", "my_tenant_id", nil, "secrettoken")

  If you use token authentication, and Tenant Name as your identifier,
  use the following code in order to add the new keystone endpoint:

      OpenStax.Keystone.Endpoint.Registry.register_token(:myendpoint, "https://auth.example.com/v2.0", nil, "my_tenant_name", "secrettoken")

  After the endpoint is registered you can get its current auth token by
  calling:

      {:ok, {auth_token, expires}} = OpenStax.Keystone.Endpoint.Registry.get_auth_token(:myendpoint)
  """

  use Application

  def version do
    "1.0.0"
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(OpenStax.Keystone.Endpoint.Registry, [
        [name: OpenStax.Keystone.Endpoint.Registry]]),
      supervisor(OpenStax.Keystone.Auth.Supervisor, [
        [name: OpenStax.Keystone.Auth.Supervisor]])
    ]

    opts = [strategy: :one_for_one, name: OpenStax.Keystone]
    Supervisor.start_link(children, opts)
  end
end
