defmodule RBMQ.GenericConsumer do
  @moduledoc """
  AQMP channel producer.

  You must configure connection (queue and exchange) before calling `publish/1` function.

  TODO: take look at genevent and defimpl Stream (use as Stream) for consumers.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use RBMQ.Worker, opts

      {:ok, pid} = Task.Supervisor.start_link()
      @task_supervisor pid

      def init_worker(chan, opts) do
        {:ok, _consumer_tag} = AMQP.Basic.consume(chan, opts[:queue][:name])
        chan
      end

      # Confirmation sent by the broker after registering this process as a consumer
      def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:noreply, state}
      end

      # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
      def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
        {:stop, :shutdown, state}
      end

      # Confirmation sent by the broker to the consumer process after a Basic.cancel
      def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:stop, :normal, state}
      end

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, state) do
        consume(payload, tag, redelivered)
        {:noreply, state}
      end

      def ack(tag) do

      end

      def consume(_payload, _tag, _redelivered) do
        raise "#{__MODULE__}.consume/3 is not implemented"
      end

      defoverridable [consume: 3]
    end
  end

  @doc """
  Receiver of messages.

  If channel is down it will keep trying to send message with 3 second timeout.
  """
  @callback consume :: :ok | :error
end

defmodule RBMQ.Consumer.Task do

end

defmodule Rbmq.Consumer do
  @moduledoc """
  RabbitMQ Consumer.
  """
  import Rbmq.Genserver.Interface
  require Logger
  use GenServer
  use AMQP

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

  def start_link(name, queue, callback, exchange \\ nil) do
    GenServer.start_link(__MODULE__, {queue, callback, get_exchange(exchange)}, name: via_tuple(name))
  end

  def init({queue, callback, exchange}) do
    queue_err =  "#{queue}_error"

    {:ok, conn} = Connection.open(get_amqp_params)
    {:ok, chan} = Channel.open(conn)
    Basic.qos(chan, prefetch_count: 100)

    Queue.declare(chan, queue_err, durable: true)
    Queue.declare(chan, queue, durable: true, arguments: [
      {"x-dead-letter-exchange", :longstr, ""},
      {"x-dead-letter-routing-key", :longstr, queue_err}
    ])

    Exchange.direct(chan, exchange, durable: true)
    Queue.bind(chan, queue, exchange, [routing_key: queue])

    {:ok, _consumer_tag} = Basic.consume(chan, queue)
    {:ok, {chan, [callback: callback]}}
  end

  def handle_call({:status, queue}, _from, {chan, _opts} = state) do
    {:reply, Queue.status(chan, queue), state}
  end

  def handle_call({:get, queue}, _from, {chan, _opts} = state) do
    {:reply, Basic.get(chan, queue), state}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  def handle_info(
    {:basic_deliver,
    payload,
    %{delivery_tag: tag, redelivered: redelivered, routing_key: key}},
    {chan, [callback: callback]} = state) do

    callback.(chan, tag, redelivered, payload, key)
    {:noreply, state}
  end
end
