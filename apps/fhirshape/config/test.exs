# Since configuration is shared in umbrella projects, this file
# should only configure the :fhirshape application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fhirshape, Fhirshape.Endpoint,
  http: [port: 4002],
  server: false

# TLS cert files to connect to fhirbuffer gRPC service
config :fhirshape, Fhirshape.Healthcare,
  ca_cert_path: "priv/cert/certauthdev.crt",
  cert_path: "priv/cert/fhirshape.crt",
  key_path: "priv/cert/fhirshape.key",
  fhirbuffer_addr: "localhost:50051",
  fhirbuffer_indication: "NONE",
  fhirbuffer_dialer: DialerMock,
  stub_port: 50051

#  fhirbuffer_addr: "localhost:10000",
#  fhirbuffer_indication: "fhirbuffer",
#  fhirbuffer_dialer: Fhirshape.Healthcare.FhirbufferDialer,
#  stub_port: 50051

##  fhirbuffer_addr: "localhost:50051",
##  fhirbuffer_indication: "NONE",
##  fhirbuffer_dialer: DialerMock,
##  stub_port: 50051
