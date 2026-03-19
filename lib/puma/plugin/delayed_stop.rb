# frozen_string_literal: true

# Graceful termination in Swarm/Kubernetes
#
# Puma immediately closes its incoming socket upon receipt of SIGTERM.
# When running in an orchestrator like Kubernetes or Docker Swarm, this
# can happen before the orchestrator has stopped routing requests to
# the terminated container, causing dropped requests. This plugin adds
# a configurable delay so the orchestrator has time to remove the
# terminated container before Puma exits as usual and stops serving requests.

Puma::Plugin.create do
  # Signals Puma registers handlers for. It overwrites plugin handlers for these
  # after plugins start, so using one here would silently break the delayed stop.
  # INFO (BSD/macOS) and PWR (Linux) were added in Puma 7.
  PUMA_SIGNALS = %w[TERM INT USR1 USR2 HUP INFO PWR].freeze

  # POSIX signal that triggers a delayed stop.
  # Defaults to QUIT so as not to interfere with Puma's default signal handling.
  # Accepts both "QUIT" and "SIGQUIT" forms; the SIG prefix is stripped.
  STOP_SIGNAL = ENV.fetch("PUMA_DELAYED_STOP_SIGNAL", "QUIT").sub(/\ASIG/i, "")

  # Time to wait in seconds before stopping.
  DRAIN_SECONDS = Integer(ENV.fetch("PUMA_DELAYED_STOP_DRAIN_SECONDS", "5"))

  def start(launcher)
    if PUMA_SIGNALS.include?(STOP_SIGNAL)
      raise ArgumentError,
        "[delayed_stop] PUMA_DELAYED_STOP_SIGNAL=#{STOP_SIGNAL} conflicts with " \
        "Puma's built-in SIG#{STOP_SIGNAL} handler. Use a signal Puma does not " \
        "reserve (e.g. QUIT). Puma reserves: #{PUMA_SIGNALS.map { |s| "SIG#{s}" }.join(', ')}"
    end

    # Puma 6 renamed `events` to `log_writer` for logging.
    logger = launcher.respond_to?(:log_writer) ? launcher.log_writer : launcher.events

    Signal.trap(STOP_SIGNAL) do
      Thread.new do
        logger.log("[delayed_stop] Received SIG#{STOP_SIGNAL}, sleeping #{DRAIN_SECONDS}s before stopping")
        sleep(DRAIN_SECONDS)
        launcher.stop
      end
    end
  end
end
