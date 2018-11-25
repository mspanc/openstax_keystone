defmodule OpenStax.Keystone.Mixfile do
  use Mix.Project

  def project do
    [app: :openstax_keystone,
     version: "0.1.8",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     description: "OpenStack Keystone client",
     maintainers: ["Marcin Lewandowski"],
     licenses: ["MIT"],
     name: "OpenStax.Keystone",
     source_url: "https://github.com/mspanc/openstax_keystone",
     package: package,
     preferred_cli_env: [espec: :test],
     deps: deps]
  end


  def application do
    [applications: [:crypto, :httpoison, :timex],
     mod: {OpenStax.Keystone, []}]
  end


  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib",]


  defp deps do
    deps(:test_dev)
  end


  defp deps(:test_dev) do
    [
      {:httpoison, "~> 0.10"},
      {:poison, "~> 2.0" },
      {:connection, "~> 1.0"},
      {:timex, "~> 3.1"},
      {:espec, "~> 0.8.17", only: :test},
      {:ex_doc, "~> 0.11.4", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev}
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
