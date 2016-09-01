defmodule RBMQ.ProducerTest do
  use ExUnit.Case, async: true
  import RBMQ.Connection
  use AMQP
  doctest RBMQ.GenericProducer

  defmodule TestConnection do
    use RBMQ.Connection,
      otp_app: :rbmq
  end

  defmodule TestProducer do
    use RBMQ.GenericProducer,
      connection: TestConnection,
      queue: [
        name: "decision_queue",
        error_name: "decision_queue_errors",
        routing_key: "decision_queue",
        durable: true
      ],
      exchange: [
        name: "queue_exchange",
        type: :direct,
        durable: true
      ],
      qos: [
        prefetch_count: 100
      ]
  end

  setup_all do
    TestConnection.start_link
    :ok
  end

  # test "starts producer" do
  #   TestProducer.start_link
  # end

  test "publish message" do
    TestProducer.start_link
    TestProducer.publish(%{example: true})
  end
end
