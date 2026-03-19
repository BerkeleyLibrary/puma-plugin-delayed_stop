# frozen_string_literal: true

RSpec.describe "Puma::Plugin::DelayedStop" do
  plugin_source = File.expand_path("../../../lib/puma/plugin/delayed_stop.rb", __dir__)
  plugin_lines = File.readlines(plugin_source)

  # Extract the right-hand side expression from a constant assignment line.
  def self.rhs_for(name, lines)
    line = lines.find { |l| l.strip.start_with?("#{name} =") }
    raise "Constant #{name} not found" unless line
    line.strip.sub(/\A#{name}\s*=\s*/, "")
  end

  stop_signal_expr = rhs_for("STOP_SIGNAL", plugin_lines)
  drain_seconds_expr = rhs_for("DRAIN_SECONDS", plugin_lines)

  around do |example|
    saved = {
      "PUMA_DELAYED_STOP_SIGNAL" => ENV["PUMA_DELAYED_STOP_SIGNAL"],
      "PUMA_DELAYED_STOP_DRAIN_SECONDS" => ENV["PUMA_DELAYED_STOP_DRAIN_SECONDS"]
    }
    example.run
  ensure
    saved.each { |k, v| ENV[k] = v }
  end

  describe "STOP_SIGNAL" do
    it "defaults to QUIT" do
      ENV.delete("PUMA_DELAYED_STOP_SIGNAL")
      expect(eval(stop_signal_expr)).to eq("QUIT") # rubocop:disable Security/Eval
    end

    it "reads from PUMA_DELAYED_STOP_SIGNAL env var" do
      ENV["PUMA_DELAYED_STOP_SIGNAL"] = "USR1"
      expect(eval(stop_signal_expr)).to eq("USR1") # rubocop:disable Security/Eval
    end

    it "strips the SIG prefix" do
      ENV["PUMA_DELAYED_STOP_SIGNAL"] = "SIGQUIT"
      expect(eval(stop_signal_expr)).to eq("QUIT") # rubocop:disable Security/Eval
    end

    it "strips a lowercase SIG prefix" do
      ENV["PUMA_DELAYED_STOP_SIGNAL"] = "sigQUIT"
      expect(eval(stop_signal_expr)).to eq("QUIT") # rubocop:disable Security/Eval
    end
  end

  describe "DRAIN_SECONDS" do
    it "defaults to 5" do
      ENV.delete("PUMA_DELAYED_STOP_DRAIN_SECONDS")
      expect(eval(drain_seconds_expr)).to eq(5) # rubocop:disable Security/Eval
    end

    it "reads from PUMA_DELAYED_STOP_DRAIN_SECONDS env var" do
      ENV["PUMA_DELAYED_STOP_DRAIN_SECONDS"] = "10"
      expect(eval(drain_seconds_expr)).to eq(10) # rubocop:disable Security/Eval
    end

    it "raises ArgumentError for non-integer values" do
      ENV["PUMA_DELAYED_STOP_DRAIN_SECONDS"] = "abc"
      expect { eval(drain_seconds_expr) }.to raise_error(ArgumentError) # rubocop:disable Security/Eval
    end
  end
end
