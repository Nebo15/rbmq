defmodule RBMQ.ConsumerTest do
  use ExUnit.Case
  use AMQP
  doctest RBMQ.Consumer

  @queue "consumer_test_qeueue"

  defmodule ProducerTestConnection do
    use RBMQ.Connection,
      otp_app: :rbmq
  end

  defmodule TestProducer do
    use RBMQ.Producer,
      connection: ProducerTestConnection,
      queue: [
        name: "consumer_test_qeueue",
        error_name: "consumer_test_qeueue_errors",
        routing_key: "consumer_test_qeueue",
        durable: false
      ],
      exchange: [
        name: "consumer_test_qeueue_exchange",
        type: :direct,
        durable: false
      ]
  end

  defmodule TestConsumer do
    use RBMQ.Consumer,
      connection: ProducerTestConnection,
      queue: [
        name: "consumer_test_qeueue",
        error_name: "consumer_test_qeueue_errors",
        routing_key: "consumer_test_qeueue",
        durable: false
      ],
      qos: [
        prefetch_count: 10
      ]

    def consume(_payload, [tag: tag, redelivered?: _redelivered, channel: chan]) do
      ack(chan, tag)
    end
  end

  setup_all do
    ProducerTestConnection.start_link
    TestProducer.start_link
    TestConsumer.start_link
    :ok
  end

  setup do
    chan = ProducerTestConnection.get_channel(RBMQ.ConsumerTest.TestProducer.Channel)
    AMQP.Queue.purge(chan, @queue)
    [channel: chan]
  end

  test "read messages" do
    assert {:ok, %{message_count: 0, queue: @queue}} = TestProducer.status

    assert :ok == TestProducer.publish(%{example: true})
    assert :ok == TestProducer.publish(1)
    assert :ok == TestProducer.publish("string")
    assert :ok == TestProducer.publish([:list])
    assert :ok == TestProducer.publish(false)


    :timer.sleep(100)

    assert {:ok, %{message_count: 0, queue: @queue}} = TestProducer.status
  end
end
