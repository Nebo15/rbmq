defmodule RBMQ.SupervisorConsumer do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :consumer_supervisor)
  end

  def start_consumer(name, queue) do
    Supervisor.start_child(:consumer_supervisor, [name, queue])
  end

  def init(_) do
    children = [
      worker(MQ.Consumer, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end