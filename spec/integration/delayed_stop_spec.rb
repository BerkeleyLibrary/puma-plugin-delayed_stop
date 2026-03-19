# frozen_string_literal: true

require "tempfile"

RSpec.describe "Delayed stop integration", :integration do
  RACKUP = File.expand_path("../fixtures/config.ru", __dir__)

  def find_open_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end

  def wait_for_server(port, timeout: 10)
    deadline = Time.now + timeout
    loop do
      TCPSocket.new("127.0.0.1", port).close
      return true
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      raise "Server did not start within #{timeout}s" if Time.now > deadline
      sleep 0.1
    end
  end

  def wait_for_server_down(port, timeout: 15)
    deadline = Time.now + timeout
    loop do
      TCPSocket.new("127.0.0.1", port).close
      raise "Server did not stop within #{timeout}s" if Time.now > deadline
      sleep 0.1
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      return true
    end
  end

  # Generate a Puma config file that loads the plugin via the DSL,
  # which works in both Puma 5 and 6.
  def write_puma_config(port:)
    file = Tempfile.new(["puma", ".rb"])
    file.write(<<~RUBY)
      app_dir = "#{File.expand_path('..', __dir__)}"
      rackup "\#{app_dir}/fixtures/config.ru"
      bind "tcp://127.0.0.1:#{port}"
      workers 0
      threads 1, 1
      plugin :delayed_stop
    RUBY
    file.close
    file
  end

  def spawn_puma(port:, env_overrides: {})
    env = ENV.to_h.merge(env_overrides)
    config_file = write_puma_config(port: port)
    @tempfiles << config_file

    cmd = ["bundle", "exec", "puma", "-C", config_file.path]

    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe
    pid = Process.spawn(env, *cmd, out: stdout_w, err: stderr_w)
    stdout_w.close
    stderr_w.close

    wait_for_server(port)
    { pid: pid, stdout: stdout_r, stderr: stderr_r }
  end

  def spawn_puma_capture(port:, env_overrides: {})
    env = ENV.to_h.merge(env_overrides)
    config_file = write_puma_config(port: port)
    @tempfiles << config_file

    cmd = ["bundle", "exec", "puma", "-C", config_file.path]
    Open3.capture3(env, *cmd)
  end

  def cleanup(handle)
    return unless handle

    pid = handle[:pid]
    if pid
      begin
        Process.kill("KILL", pid)
        Process.waitpid(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        # already gone
      end
    end
    [handle[:stdout], handle[:stderr]].each { |io| io&.close unless io&.closed? }
  end

  def read_output(handle)
    handle[:stdout].read + handle[:stderr].read
  end

  def wait_for_exit(handle)
    _pid, _status = Process.waitpid2(handle[:pid], Process::WNOHANG) || Process.waitpid2(handle[:pid])
    handle[:pid] = nil
  end

  before { @tempfiles = [] }

  after do
    cleanup(@handle)
    @tempfiles.each(&:unlink)
  end

  context "when SIGQUIT is received" do
    it "keeps the server running during the drain period, then shuts down" do
      port = find_open_port
      drain_seconds = 2

      @handle = spawn_puma(
        port: port,
        env_overrides: {
          "PUMA_DELAYED_STOP_SIGNAL" => "QUIT",
          "PUMA_DELAYED_STOP_DRAIN_SECONDS" => drain_seconds.to_s
        }
      )

      # Confirm the server responds before signal.
      response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
      expect(response.code).to eq("200")

      signal_sent_at = Time.now
      Process.kill("QUIT", @handle[:pid])

      # Server should still be up at the midpoint of the drain period.
      sleep(drain_seconds * 0.5)
      begin
        mid_response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
        expect(mid_response.code).to eq("200")
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        raise "Server stopped too early (during drain period)"
      end

      # Wait for the server to shut down.
      wait_for_server_down(port)
      elapsed = Time.now - signal_sent_at

      expect(elapsed).to be >= drain_seconds

      wait_for_exit(@handle)

      output = read_output(@handle)
      expect(output).to match(/delayed_stop/)
      expect(output).to match(/SIGQUIT/)
      expect(output).to match(/sleeping #{drain_seconds}s/)
    end
  end

  context "with a custom drain period" do
    it "respects the configured PUMA_DELAYED_STOP_DRAIN_SECONDS" do
      port = find_open_port
      drain_seconds = 1

      @handle = spawn_puma(
        port: port,
        env_overrides: {
          "PUMA_DELAYED_STOP_SIGNAL" => "QUIT",
          "PUMA_DELAYED_STOP_DRAIN_SECONDS" => drain_seconds.to_s
        }
      )

      signal_sent_at = Time.now
      Process.kill("QUIT", @handle[:pid])

      wait_for_server_down(port)
      elapsed = Time.now - signal_sent_at

      expect(elapsed).to be >= drain_seconds
      expect(elapsed).to be < (drain_seconds + 3)

      wait_for_exit(@handle)

      output = read_output(@handle)
      expect(output).to match(/sleeping 1s/)
    end
  end

  context "when configured with a Puma-reserved signal" do
    %w[TERM SIGTERM].each do |signal_value|
      it "exits with an error when PUMA_DELAYED_STOP_SIGNAL=#{signal_value}" do
        port = find_open_port

        stdout, stderr, status = spawn_puma_capture(
          port: port,
          env_overrides: {
            "PUMA_DELAYED_STOP_SIGNAL" => signal_value,
            "PUMA_DELAYED_STOP_DRAIN_SECONDS" => "1"
          }
        )
        output = stdout + stderr

        expect(status.success?).to be false
        expect(output).to match(/conflicts with Puma/)
        expect(output).to match(/SIGTERM/)
      end
    end
  end

  context "when SIGTERM is received" do
    it "shuts down immediately without the plugin delay" do
      port = find_open_port

      @handle = spawn_puma(
        port: port,
        env_overrides: {
          "PUMA_DELAYED_STOP_SIGNAL" => "QUIT",
          "PUMA_DELAYED_STOP_DRAIN_SECONDS" => "30"
        }
      )

      signal_sent_at = Time.now
      Process.kill("TERM", @handle[:pid])

      wait_for_server_down(port, timeout: 10)
      elapsed = Time.now - signal_sent_at

      # SIGTERM should cause a fast shutdown, well under the 30s drain.
      expect(elapsed).to be < 5

      wait_for_exit(@handle)
    end
  end
end
