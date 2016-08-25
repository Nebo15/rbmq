defmodule Rbmq.SupervisorProducer do
  @moduledoc """
  Supervisor for RabbitMQ Producers.
  """
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :producer_supervisor)
  end

  def spawn_producer(name, queue, exchange \\ nil, prefetch_count \\ nil) do
    Supervisor.start_child(:producer_supervisor, [name, queue, exchange, prefetch_count])
  end

  def init(_) do
    children = [
      worker(Rbmq.Producer, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
