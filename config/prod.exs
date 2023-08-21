import Config

config :logger, level: :info

config :sentry,
  dsn: "https://4a5e6b9536ca513d32081eed5e65b3c8@o1157219.ingest.sentry.io/4505743551758336",
  environment_name: System.get_env("DEPLOY_TARGET", "staging"),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  included_environments: ~w(staging sandbox)
