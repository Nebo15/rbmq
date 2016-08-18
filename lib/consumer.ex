defmodule MQ.Consumer do
  use GenServer
  use AMQP

  # Server
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__, func: "func")
  end

  def get(server) do
#    GenServer.call(server, {:get})
  end

  @exchange    "os_decision_engine_exchange"
  @queue       "os_decision_queue"
  @queue_error "#{@queue}_error"

  def init(_opts) do
    rabbitmq_connect
  end

  defp rabbitmq_connect do
    case Connection.open(Rbmq.get_amqp_params) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        # Everything else remains the same
        {:ok, chan} = Channel.open(conn)
        Basic.qos(chan, prefetch_count: 10)
        Queue.declare(chan, @queue_error, durable: true)
        Queue.declare(chan, "os_decision_engine_ex", durable: true)
        Queue.declare(chan, @queue, durable: true,
                                    arguments: [{"x-dead-letter-exchange", :longstr, ""},
                                                {"x-dead-letter-routing-key", :longstr, @queue_error}])

        Exchange.direct(chan, @exchange, durable: true)
        Queue.bind(chan, @queue, @exchange)

        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        {:ok, chan}
      {:error, _} ->
        # Reconnection loop
        :timer.sleep(10000)
        rabbitmq_connect
    end
  end

  def handle_call({:get}, _from, chan) do
    {:reply, Basic.get(chan, @queue), chan}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
    {:ok, chan} = rabbitmq_connect
    {:noreply, chan}
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

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    spawn fn -> consume(chan, tag, redelivered, payload) end
    {:noreply, chan}
  end

  defp consume(chan, tag, redelivered, payload) do
    try do
#      IO.inspect chan
#      IO.inspect tag
#      IO.inspect redelivered
#      IO.inspect payload

      number = String.to_integer(payload)
      if number <= 10 do
        Basic.ack chan, tag
        IO.puts "Consumed a #{number}."
      else
        Basic.reject chan, tag, requeue: false
        IO.puts "#{number} is too big and was rejected."
      end
    rescue
      _ ->
        # Requeue unless it's a redelivered message.
        # This means we will retry consuming a message once in case of exception
        # before we give up and have it moved to the error queue
        Basic.reject chan, tag, requeue: not redelivered
        IO.puts "Error converting #{payload} to integer"
    end
  end
end
