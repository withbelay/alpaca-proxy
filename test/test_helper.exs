ExUnit.start()

# If you use credo, dialyxir or excoveralls manually in your console
# you may be interested in calling test with ci_checks environment
# to avoid extra compilation time
#
# MIX_ENV=ci_checks mix test
# mix credo
# mix dialyxir
# mix excoveralls

# ci_checks configuration is supposed to import test configuration
# so if you do not use those tools manually in your console
# you are safe to call it in standard test environment
#
# mix test
