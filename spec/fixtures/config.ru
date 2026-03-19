# frozen_string_literal: true

# Minimal Rack app used by integration tests.
app = lambda do |_env|
  [200, { "content-type" => "text/plain" }, ["OK"]]
end

run app
