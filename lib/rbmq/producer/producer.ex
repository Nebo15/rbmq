defmodule RBMQ.GenericProducer do
  @moduledoc """
  AQMP channel producer.

  You must configure connection (queue and exchange) before calling `publish/1` function.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer

      @connection Keyword.get(opts, :connection)
      @channel_name String.to_atom("#{__MODULE__}.Channel")
      @channel_conf Keyword.delete(opts, :connection)

      unless @connection do
        raise "You need to implement connection module and pass it in :connection option."
      end

      def start_link do
        GenServer.start_link(__MODULE__, @channel_conf, name: __MODULE__)
      end

      def init(opts) do
        unless Process.whereis(@connection) do
          raise "Connection #{__MODULE__} is undefined or down."
        end

        @connection.spawn_channel(@channel_name)
        @connection.configure_channel(@channel_name, opts)
        chan = @connection.get_channel(@channel_name)

        # TODO: reconfigure when channel is restarted
        # Store config inside channel
        # Process.monitor(chan.pid)

        {:ok, chan}
      end

      @doc """
      Publish new message to a linked channel.
      """
      def publish(data) do
        GenServer.call(__MODULE__, {:publish, data})
      end

      @doc false
      def handle_call({:publish, data}, _from, chan) do
        case Poison.encode(data) do
          {:ok, encoded_data} ->
            _publish(chan, encoded_data)
          {:error, _} = err ->
            {:reply, err, chan}
        end
      end

      defp _publish(chan, data) do
        config = RBMQ.Connection.Channel.get_config(@channel_name)
        is_persistent = Keyword.get(config[:queue], :durable, false)

        case AMQP.Basic.publish(chan, config[:exchange][:name], config[:queue][:routing_key], data, [mandatory: true, persistent: is_persistent]) do
          :ok ->
            {:reply, :ok, chan}
          _ ->
            {:reply, :error, chan}
        end
      end
    end
  end
end

defmodule Rbmq.Producer do
  @moduledoc """
  RabbitMQ Producer
  """
  import Rbmq.Genserver.Interface
  use GenServer
  use AMQP
  require Logger

  # Client
  def publish(name, queue, data) do
    name
    |> get_server
    |> server_call({:publish, queue, data})
  end

  # Server

  def start_link(name, queue, prefetch_count \\ nil, exchange \\ nil) do
    GenServer.start_link(
      __MODULE__,
      {queue, get_exchange(exchange), get_prefetch_count(prefetch_count)},
      name: via_tuple(name)
    )
  end

  def init({queue, exchange, prefetch_count}) do
    queue_err =  "#{queue}_error"

    {:ok, conn} = Connection.open(get_amqp_params)
    {:ok, chan} = Channel.open(conn)
    Basic.qos(chan, prefetch_count: prefetch_count)
    Queue.declare(chan, queue_err, durable: true)
    Queue.declare(chan, queue, durable: true, arguments: [
      {"x-dead-letter-exchange", :longstr, ""},
      {"x-dead-letter-routing-key", :longstr, queue_err}
    ])
    Exchange.direct(chan, exchange, durable: true)
    Queue.bind(chan, queue, exchange, [routing_key: queue])
    AMQP.Confirm.select(chan)

    {:ok, {chan, [exchange: exchange]}}
  end

  def handle_call({:publish, routing_key, data}, _from, state = {chan, [exchange: exchange]}) do
    case Basic.publish(chan, exchange, routing_key, Poison.encode!(data), [mandatory: true, persistent: true]) do
      :ok ->
        {:reply, :ok, state}
      _ ->
        {:reply, :error, state}
    end
  end
end
