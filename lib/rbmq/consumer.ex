defmodule Rbmq.Consumer do
  @moduledoc """
  RabbitMQ Consumer.
  """
  import Rbmq.Genserver.Interface
  require Logger
  use GenServer
  use AMQP

  @exchange "os_exchange_decision_engine"

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

  def start_link(name, queue, exchange \\ nil) do
    GenServer.start_link(__MODULE__, [queue: queue, exchange: get_exchange(exchange)], name: via_tuple(name))
  end

  def init(opts) do
    exchange = opts[:exchange]
    queue = opts[:queue]
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
    {:ok, {chan, [exchange: exchange]}}
  end

  def handle_call({:status, queue}, _from, {chan, _opts}) do
    {:reply, Queue.status(chan, queue), chan}
  end

  def handle_call({:get, queue}, _from, {chan, _opts}) do
    {:reply, Basic.get(chan, queue), chan}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, {chan, _opts}) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, {chan, _opts}) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, {chan, _opts}) do
    {:noreply, chan}
  end

  def handle_info(
    {:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered, routing_key: key}},
    {chan, [exchange: exchange]}) do
    spawn fn -> consume(chan, tag, redelivered, payload, key) end
    {:noreply, chan}
  end

  defp consume(chan, tag, redelivered, _data, "os_decision_queue") do
    try do
      Logger.debug "consume"

      # it's enough'
      Basic.ack chan, tag

    rescue
      err ->
        Logger.error "consumer 'os_decision_queue' error #{inspect err}"
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
