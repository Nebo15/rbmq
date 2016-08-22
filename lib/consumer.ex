defmodule MQ.Consumer do
  import RBMQ.Genserver.Interface
  use GenServer
  use AMQP

  @exchange "os_decision_engine_exchange"

  def get(name, queue) do
    name
    |> get_server
    |> server_call({:get, queue})
  end

  def status(name, queue) do
    name
    |> get_server
    |> server_call({:status, queue})
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

    {:ok, _consumer_tag} = Basic.consume(chan, queue)
    {:ok, chan}
  end

  def handle_call({:status, queue}, _from, chan) do
    {:reply, Queue.status(chan, queue), chan}
  end

  def handle_call({:get, queue}, _from, chan) do
    {:reply, Basic.get(chan, queue), chan}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered, routing_key: routing_key}}, chan) do
    spawn fn -> consume(chan, tag, redelivered, payload, routing_key) end
    {:noreply, chan}
  end

  defp consume(chan, tag, _redelivered, payload, "os_decision_queue") do
    case MQ.Producer.publish("p1", "os_decision_next", payload) do
      :ok -> Basic.ack chan, tag
      _   -> Basic.reject chan, tag, requeue: false
    end
  end

  defp consume(chan, tag, redelivered, payload, "os_decision_next") do
    try do

      {:ok, payload} = Poison.decode(payload)

      {:ok, conn} = Postgrex.start_link(hostname: "localhost", username: "postgres", password: "postgres", database: "rbmq")
      res = Postgrex.query(conn, "INSERT INTO sample (val) VALUES (#{payload})", [])
      GenServer.stop(conn)

      case res do
        {:ok, _}         -> Basic.ack chan, tag
        {:error, reason} -> Basic.reject chan, tag, requeue: not redelivered
      end


    rescue
      _ ->
        # Requeue unless it's a redelivered message.
        # This means we will retry consuming a message once in case of exception
        # before we give up and have it moved to the error queue
        Basic.reject chan, tag, requeue: not redelivered
    end
  end

  defp consume(chan, tag, _redelivered, _payload, _routing_key) do
    Basic.reject chan, tag, requeue: false
  end
end
