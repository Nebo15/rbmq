defmodule Rbmq.SupervisorConsumer do
  @moduledoc """
  Supervisor for RabbitMQ Consumers.
  """
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :consumer_supervisor)
  end

  def spawn_consumer(name, queue, exchange \\ nil) do
    Supervisor.start_child(:producer_supervisor, [name, queue, exchange])
  end

  def init(_) do
    children = [
      worker(Rbmq.Consumer, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
