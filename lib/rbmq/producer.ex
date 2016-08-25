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
