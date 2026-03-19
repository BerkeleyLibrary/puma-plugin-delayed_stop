# frozen_string_literal: true

# This file exists so that `require "puma-plugin-delayed_stop"` works, but
# Puma discovers plugins via lib/puma/plugin/<name>.rb automatically.
require_relative "puma/plugin/delayed_stop"
