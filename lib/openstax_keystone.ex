defmodule OpenStax.Keystone do
  use Application


  def version do
    "0.1.0"
  end


  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(OpenStax.Keystone.AuthAgent, [[name: OpenStax.Keystone.AuthAgent]]),
      supervisor(OpenStax.Keystone.AuthSupervisor, [[name: OpenStax.Keystone.AuthSupervisor]])
    ]

    opts = [strategy: :one_for_one, name: OpenStax.Keystone]
    Supervisor.start_link(children, opts)
  end
end
