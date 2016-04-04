defmodule EctoLdap.Mixfile do
  use Mix.Project
  @description """
    An Ecto adapter for LDAP
  """

  def project do
    [app: :ecto_ldap,
     version: "0.2.6",
     elixir: "~> 1.2",
     name: "ecto_ldap",
     description: @description,
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.html": :test, "coveralls.post": :test],
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ecto, :timex_ecto]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ecto, "~> 1.1"},
      {:timex, github: "bitwalker/timex", override: true},
      {:timex_ecto, "~> 1.0"},
      {:excoveralls, "~> 0.5", only: :test},
    ]
  end

  defp package do
    [ maintainers: ["Jeff Weiss", "Manny Batule"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/jeffweiss/ecto_ldap"} ]
  end
end
