defmodule Rbmq.SupervisorProducer do
  @moduledoc """
  Supervisor for RabbitMQ Producers.
  """
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :producer_supervisor)
  end

  def spawn_producer(name, queue, prefetch_count \\ nil, exchange \\ nil) do
    Supervisor.start_child(:producer_supervisor, [name, queue, prefetch_count, exchange])
  end

  def init(_) do
    children = [
      worker(Rbmq.Producer, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
