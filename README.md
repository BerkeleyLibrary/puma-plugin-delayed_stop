# puma-plugin-delayed_stop

A [Puma](https://puma.io) plugin that delays shutdown after receiving a signal, giving container orchestrators (Kubernetes, Docker Swarm, ECS, etc.) time to remove the instance from load balancing before connections are closed.

## The problem

When Puma receives `SIGTERM`, it begins shutting down immediately. In orchestrated environments, the termination signal often arrives *before* the orchestrator has finished removing the container from its service mesh or load balancer. Requests routed to the container during this window are dropped.

## The solution

This plugin intercepts a configurable signal (default: `SIGQUIT`) and waits a configurable number of seconds before telling Puma to stop. This gives the orchestrator time to update its routing tables.

A typical Kubernetes setup would configure the pod's `preStop` hook or `terminationGracePeriodSeconds` to send `SIGQUIT`, then later `SIGTERM`:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["kill", "-QUIT", "1"]
```

## Installation

Add to your Gemfile:

```ruby
gem "puma-plugin-delayed_stop"
```

Then in your `config/puma.rb`:

```ruby
plugin :delayed_stop
```

## Configuration

Configuration is via environment variables:

| Variable | Default | Description |
|---|---|---|
| `PUMA_DELAYED_STOP_SIGNAL` | `QUIT` | Signal name (without `SIG` prefix) that triggers the delayed stop |
| `PUMA_DELAYED_STOP_DRAIN_SECONDS` | `5` | Seconds to wait before telling Puma to stop |

**Warning:** Do not set `PUMA_DELAYED_STOP_SIGNAL` to a signal that Puma already handles (`TERM`, `INT`, `HUP`, `USR1`, `USR2`). Puma registers its own handlers for these signals *after* plugins start, so the plugin's handler will be silently overwritten. The default (`QUIT`) is safe because Puma does not trap it. See [Puma's signal handling documentation](https://github.com/puma/puma/blob/master/docs/signals.md) for the full list of reserved signals.

## How it works

1. On startup, the plugin registers a signal handler for the configured signal.
2. When the signal is received, the handler sleeps for the configured drain period.
3. After sleeping, it calls `launcher.stop`, which initiates Puma's normal graceful shutdown.

## Development

```bash
bundle install
bundle exec rspec
```

## License

[MIT](LICENSE)
