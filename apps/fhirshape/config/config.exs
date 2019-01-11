# Since configuration is shared in umbrella projects, this file
# should only configure the :fhirshape application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

# General application configuration
config :fhirshape,
  generators: [context_app: false, binary_id: true]

# Configures the endpoint
config :fhirshape, Fhirshape.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "hdTTrUHoanwK3qQSx6O/3wBr1R9mFhWOzqSdag6RAyLK63UJMDK/eQr8omaxQEk0",
  render_errors: [view: Fhirshape.ErrorView, accepts: ~w(json)],
  pubsub: [name: Fhirshape.PubSub, adapter: Phoenix.PubSub.PG2]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
