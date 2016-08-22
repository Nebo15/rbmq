defmodule MQ.Producer do
  import RBMQ.Genserver.Interface
  use GenServer
  use AMQP

  @exchange "os_decision_engine_exchange"

  # Client
  def publish(name, queue, data) do
    name
    |> get_server
    |> server_call({:publish, queue, data})
  end

  # Server
  def start_link(name, queue) do
    GenServer.start_link(__MODULE__, [queue: queue], name: via_tuple(name))
  end

  def init(opts) do
    queue = opts[:queue]
    queue_err =  "#{queue}_error"

    {:ok, conn} = Connection.open(get_amqp_params)
    {:ok, chan} = Channel.open(conn)
    Basic.qos(chan, prefetch_count: 10)
    Queue.declare(chan, queue_err, durable: true)
    Queue.declare(chan, queue, durable: true, arguments: [
      {"x-dead-letter-exchange", :longstr, ""},
      {"x-dead-letter-routing-key", :longstr, queue_err}
    ])
    Exchange.direct(chan, @exchange, durable: true)
    Queue.bind(chan, queue, @exchange, [routing_key: queue])
    AMQP.Confirm.select(chan)

    {:ok, chan}
  end

  def handle_call({:publish, routing_key, data}, _from, chan) do
    case Basic.publish(chan, @exchange, routing_key, Poison.encode!(data), [mandatory: true, persistent: true]) do
      :ok ->
        {:reply, :ok, chan}
      _ ->
        {:reply, :error, chan}
    end
  end
end
