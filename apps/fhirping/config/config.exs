# Since configuration is shared in umbrella projects, this file
# should only configure the :fhirping application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

# General application configuration
config :fhirping,
  ecto_repos: [Fhirping.Repo],
  generators: [context_app: false]

# Configures the endpoint
config :fhirping, Fhirping.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "JY7DfwsK6oxje5L8xliwXbGPg3P96+x2jLGl1Ol3Lp72O6NR0JoJ8bzv5kV9gbVZ",
  render_errors: [view: Fhirping.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Fhirping.PubSub, adapter: Phoenix.PubSub.PG2]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
