defmodule OpenStax.Keystone.Mixfile do
  use Mix.Project

  def project do
    [
      app: :openstax_keystone,
      version: "1.0.0",
      elixir: "~> 1.6",
      description: "OpenStack Keystone client",
      maintainers: ["Marcin Lewandowski"],
      licenses: ["MIT"],
      name: "OpenStax.Keystone",
      source_url: "https://github.com/mspanc/openstax_keystone",
      package: package(),
      deps: deps(),
    ]
  end

  def application do
    [
      mod: {OpenStax.Keystone, []},
      extra_applications: [:logger],
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.4"},
      {:jason, "~> 1.1"},
      {:connection, "~> 1.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
    ]
  end


  defp package do
    [description: "OpenStack Keystone client",
     files: ["lib",  "mix.exs", "README*", "LICENSE"],
     maintainers: ["Marcin Lewandowski"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/mspanc/openstax_keystone"}]
  end
end
