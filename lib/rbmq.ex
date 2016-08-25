defmodule Rbmq do
  @moduledoc """
  Module for simple usage of the Rbmq library
  """

  @doc """
    Start Supervisor for Consumers
  """
  defdelegate start_consumer_supervisor, to:  Rbmq.SupervisorConsumer, as: :start_link

  @doc """
    Start Supervisor for Producers
  """
  defdelegate start_producer_supervisor, to:  Rbmq.SupervisorProducer, as: :start_link

  @doc """
    Spawn new process with Consumer
  """
  defdelegate spawn_consumer(name, queue, exchange \\ nil), to:  Rbmq.SupervisorConsumer

  @doc """
    Spawn new process with Producer
  """
  defdelegate spawn_producer(name, queue, exchange \\ nil, prefetch_count \\ nil), to:  Rbmq.SupervisorProducer

  @doc """
    Publish message into queue.
    Producer with specified queue must already be started
  """
  defdelegate publish(name, queue, data), to:  Rbmq.Producer

  @doc """
    Get queue status.
    Consumer with specified queue must already be started
  """
  defdelegate status(name, queue), to:  Rbmq.Consumer

  @doc """
    Get message from queue.
    Consumer with specified queue must already be started
  """
  defdelegate get(name, queue), to:  Rbmq.Consumer
end
