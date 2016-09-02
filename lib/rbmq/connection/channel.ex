defmodule RBMQ.Connection.Channel do
  @moduledoc """
  AMQP channel server.

  Whenever connection gets rest channel reinitializes itself.
  """

  use GenServer
  require Logger
  alias RBMQ.Connector

  def start_link(opts, name \\ []) do
    # IO.inspect "Linking !"
    # IO.inspect opts
    # IO.inspect name
    # IO.inspect "========"
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  def init(opts) do
    {:ok, _init(opts)}
  end

  defp _init(opts) do
    chan_opts = opts
    |> Keyword.delete(:channel)
    |> Keyword.get(:config, [])

    # IO.inspect "Open channel #{inspect chan_opts}:"

    # :timer.sleep(100)
    # IO.inspect Connector.open_channel(opts[:connection])

    {:ok, chan} = Connector.open_channel(opts[:connection])

    configure(chan, chan_opts)

    # Monitor channel state
    # IO.inspect "Start monitor"
    Process.monitor(chan.pid)

    [channel: chan, config: chan_opts, connection: opts[:connection]]
  end

  defp configure(chan, chan_opts) do
    chan
    |> configure_qos(chan_opts[:qos])
    |> configure_queue(chan_opts[:queue])
    |> configure_exchange(chan_opts[:queue], chan_opts[:exchange])
  end

  defp configure_qos(chan, nil) do
    chan
  end

  defp configure_qos(chan, qos_opts) do
    Connector.set_channel_qos(chan, qos_opts)
    chan
  end

  defp configure_queue(chan, nil) do
    chan
  end

  defp configure_queue(chan, queue_opts) do
    Connector.declare_queue(chan, queue_opts[:name], queue_opts[:error_name], queue_opts)
    chan
  end

  defp configure_exchange(chan, queue_opts, exchange_opts) when is_nil(queue_opts) or is_nil(exchange_opts) do
    chan
  end

  defp configure_exchange(chan, queue_opts, exchange_opts) do
    Connector.declare_exchange(chan, exchange_opts[:name], exchange_opts[:type], exchange_opts)
    Connector.bind_queue(chan, queue_opts[:name], exchange_opts[:name], routing_key: queue_opts[:routing_key])
    chan
  end

  @doc false
  def get(pid) do
    GenServer.call(pid, :get)
  end

  @doc false
  def close(pid) do
    GenServer.cast(pid, :close)
  end

  @doc false
  def reconnect(pid, conn) do
    Logger.warn "Channel received connection change event: #{inspect conn}"
    GenServer.call(pid, {:reconnect, conn})
  end

  @doc false
  def set_config(pid, config) do
    GenServer.call(pid, {:apply_config, config})
  end

  @doc """
  Returns current configuration of a channel.
  """
  def get_config(pid) do
    GenServer.call(pid, :get_config)
  end

  @doc """
  Run callback inside Channel GenServer and return result.
  Callback function should accept connection as first argument.
  """
  def run(pid, callback) do
    GenServer.call(pid, {:run, callback})
  end

  @doc false
  def handle_info({:DOWN, monitor_ref, :process, pid, reason}, state) do
    Logger.error "AMQP channel went down: #{inspect pid}"
    # AMQP.Channel.close(%AMQP.Channel{pid: pid, conn: state[:connection]})
    Process.demonitor(monitor_ref)
    :timer.sleep(100)

    case reason do
      :normal ->
        {:stop, :normal, :ok}
      _ ->
        {:stop, :channel_down, state}
        # IO.inspect reason
        # # IO.inspect state

        # # :timer.sleep(1_000)

        # state = state
        # |> Keyword.delete(:channel)
        # |> _init

        # IO.inspect "Got new state"
        # # IO.inspect state

        # {:noreply, state}
        # # {:stop, :child_dead, state}
    end
  end

  @doc false
  def handle_cast(:close, state) do
    Connector.close_channel(state[:channel])
    {:stop, :normal, :ok}
  end

  @doc false
  def handle_call(:get, _from, state) do
    {:reply, state[:channel], state}
  end

  @doc false
  def handle_call(:get_config, _from, state) do
    {:reply, state[:config], state}
  end

  @doc false
  def handle_call({:reconnect, conn}, _from, [config: chan_opts]) do
    state = _init([
      connection: conn,
      config: chan_opts
    ])

    {:reply, :ok, state}
  end

  @doc false
  def handle_call({:apply_config, config}, _from, state) do
    chan = state[:channel]
    |> configure(config)

    {:reply, :ok, [
      channel: chan,
      config: Keyword.merge(state[:config], config),
      connection: state[:connection]
    ]}
  end

  @doc false
  def handle_call({:run, callback}, _from, state) when is_function(callback) do
    {:reply, callback.(state[:channel]), state}
  end
end
