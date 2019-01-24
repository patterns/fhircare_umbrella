use Mix.Config

##config :logger,
##  level: :debug,
##  truncate: 4096

fsport = String.to_integer(System.get_env("PORT"))
config :fhirshape, Fhirshape.Endpoint,
  http: [port: fsport],
  url: [host: System.get_env("HOSTNAME"), port: fsport],
  root: ".",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# TLS cert files to connect to fhirbuffer gRPC service
config :fhirshape, Fhirshape.Healthcare,
  ca_cert_path: System.get_env("CA_CERT"),
  cert_path: System.get_env("FHIRSHAPE_CERT"),
  key_path: System.get_env("FHIRSHAPE_KEY"),
  fhirbuffer_addr: System.get_env("FHIRBUFFER_ADDR"),
  fhirbuffer_indication: System.get_env("FHIRBUFFER_INDICATION")

