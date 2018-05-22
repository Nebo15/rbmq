defmodule RBMQ.Connection.Channel do
  @moduledoc """
  AMQP channel server.

  Whenever connection gets rest channel reinitializes itself.
  """

  use GenServer
  require Logger
  alias RBMQ.Connection.Helper

  def start_link(opts, name) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  def init(opts) do
    chan_opts =
      opts
      |> Keyword.delete(:channel)
      |> Keyword.delete(:connection)
      |> Keyword.get(:config, [])

    case Helper.open_channel(opts[:connection]) do
      {:error, :conn_dead} ->
        Logger.warn(
          "Connection #{inspect(opts[:connection].pid)} is dead, waiting for supervisor actions.."
        )

        {:ok, [channel: nil, config: chan_opts, connection: nil]}

      {:ok, chan} ->
        configure(chan, chan_opts)

        # Monitor channel state
        # Process.flag(:trap_exit, true) # uncomment me?
        Process.monitor(chan.pid)

        {:ok, [channel: chan, config: chan_opts, connection: opts[:connection]]}
    end
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
    Helper.set_channel_qos(chan, qos_opts)
    chan
  end

  defp configure_queue(chan, nil) do
    chan
  end

  defp configure_queue(chan, queue_opts) do
    Helper.declare_queue(chan, queue_opts[:name], queue_opts[:error_name], queue_opts)
    chan
  end

  defp configure_exchange(chan, queue_opts, exchange_opts)
       when is_nil(queue_opts) or is_nil(exchange_opts) do
    chan
  end

  defp configure_exchange(chan, queue_opts, exchange_opts) do
    Helper.declare_exchange(chan, exchange_opts[:name], exchange_opts[:type], exchange_opts)

    Helper.bind_queue(
      chan,
      queue_opts[:name],
      exchange_opts[:name],
      routing_key: queue_opts[:routing_key]
    )

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
    Logger.warn("Channel received connection change event: #{inspect(conn)}")
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
    Logger.warn("AMQP channel #{inspect(pid)} went down with reason #{inspect(reason)}.")
    Process.demonitor(monitor_ref, [:flush])
    GenServer.cast(self(), {:restart, reason})
    {:noreply, state}
  end

  @doc false
  def handle_cast({:restart, _reason}, state) do
    # case reason do
    #   :normal ->
    #     Logger.error "AMQP channel won't be restarted."
    #     {:stop, :normal, state}
    #   _ ->
    {:ok, state} =
      state
      |> Keyword.delete(:channel)
      |> init

    {:noreply, state}
    # end
  end

  @doc false
  def handle_cast(:close, state) do
    Helper.close_channel(state[:channel])
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
  def handle_call({:reconnect, conn}, _from, state) do
    {:ok, state} =
      init(
        connection: conn,
        config: state[:config]
      )

    {:reply, :ok, state}
  end

  @doc false
  def handle_call({:apply_config, config}, _from, state) do
    chan =
      state[:channel]
      |> configure(config)

    {:reply, :ok,
     [
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
