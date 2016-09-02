defmodule RBMQ.Connection.Guard do
  @moduledoc """
  Supervisor for RabbitMQ Consumers.
  """
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :consumer_supervisor)
  end

  def spawn_consumer(name, queue, callback, exchange \\ nil) do
    Supervisor.start_child(:consumer_supervisor, [name, queue, callback, exchange])
  end

  def init(_) do
    children = [
      worker(Rbmq.Consumer, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
