defmodule MQ.Producer do
  use GenServer
  use AMQP

  # Client
  def publish(server, queue, data) do
    GenServer.call(server, {:publish, queue, data})
  end

  # Server
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
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

        {:ok, chan} = Channel.open(conn)
        Basic.qos(chan, prefetch_count: 10)
        Queue.declare(chan, @queue_error, durable: true)
        Queue.declare(chan, @queue, durable: true,
                                    arguments: [{"x-dead-letter-exchange", :longstr, ""},
                                                {"x-dead-letter-routing-key", :longstr, @queue_error}])
        Exchange.direct(chan, @exchange, durable: true)
        Queue.bind(chan, @queue, @exchange)
        AMQP.Confirm.select(chan)

        {:ok, chan}
      {:error, _} ->
        # Reconnection loop
        :timer.sleep(10000)
        rabbitmq_connect
    end
  end

  def handle_call({:publish, queue, data}, _from, chan) do
    case Basic.publish(chan, queue, "", Poison.encode!(data), [mandatory: true, persistent: true]) do
      :ok ->
        {:reply, :ok, chan}
      _ ->
        {:reply, :error, chan}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
    {:ok, chan} = rabbitmq_connect
    {:noreply, chan}
  end
end
