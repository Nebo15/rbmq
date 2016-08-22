defmodule RBMQ.SupervisorProducer do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :producer_supervisor)
  end

  def start_producer(name, queue) do
    Supervisor.start_child(:producer_supervisor, [name, queue])
  end

  def init(_) do
    children = [
      worker(MQ.Producer, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end