defmodule RBMQ.Connection.Channel do
  @moduledoc """
  AQMP channel server.

  Whenever connection gets rest channel reinitializes itself.
  """

  use GenServer
  require Logger
  alias RBMQ.Connector

  def init(opts) do
    chan_opts = Keyword.get(opts, :config, [])

    chan = opts[:connection]
    |> Connector.open_channel
    |> init_qos(chan_opts[:qos])
    |> init_queue(chan_opts[:queue])
    |> init_exchange(chan_opts[:queue], chan_opts[:exchange])

    chan
  end

  def init_qos({:ok, _} = res, nil) do
    res
  end

  def init_qos({:ok, chan} = res, qos_opts) do
    Connector.set_channel_qos(chan, qos_opts)

    res
  end

  def init_queue({:ok, _} = res, nil) do
    res
  end

  def init_queue({:ok, chan} = res, queue_opts) do
    Connector.declare_queue(chan, queue_opts[:name], queue_opts[:error_name], queue_opts)

    res
  end

  def init_exchange({:ok, _} = res, queue_opts, exchange_opts) when is_nil(queue_opts) or is_nil(exchange_opts) do
    res
  end

  def init_exchange({:ok, chan} = res, queue_opts, exchange_opts) do
    Connector.declare_exchange(chan, exchange_opts[:name], exchange_opts[:type], exchange_opts)
    Connector.bind_queue(chan, queue_opts[:name], exchange_opts[:name], routing_key: queue_opts[:routing_key])

    res
  end

  def start_link(opts, name \\ []) do
    GenServer.start_link(__MODULE__, opts, name: name)
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

  def run(pid, callback) do
    GenServer.call(pid, {:run, callback})
  end

  def handle_call(:get, _from, chan) do
    {:reply, chan, chan}
  end

  def handle_call({:reconnect, conn}, _from, _) do
    chan = init(conn)

    {:reply, chan, chan}
  end

  def handle_call({:run, callback}, _from, chan) when is_function(callback) do
    {:reply, callback.(chan), chan}
  end

  def handle_cast(:close, chan) do
    Connector.close_channel(chan)
    {:stop, :normal, :ok}
  end
end
