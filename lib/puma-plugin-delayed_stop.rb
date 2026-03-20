# frozen_string_literal: true

# This file exists so Bundler's auto-require doesn't raise a LoadError.
# The actual plugin is loaded by Puma when it encounters `plugin :delayed_stop`
# in the Puma config. It lives at lib/puma/plugin/delayed_stop.rb and is
# discovered by convention — no explicit require is needed.
