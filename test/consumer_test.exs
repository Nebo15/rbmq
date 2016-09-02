defmodule RBMQ.ConsumerTest do
  use ExUnit.Case
  use AMQP
  doctest RBMQ.GenericConsumer

  @queue "consumer_test_qeueue"

  defmodule ProducerTestConnection do
    use RBMQ.Connection,
      otp_app: :rbmq
  end

  defmodule TestProducer do
    use RBMQ.GenericProducer,
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
    use RBMQ.GenericConsumer,
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

    def consume(payload, tag, _redelivered) do
      IO.inspect payload
      IO.inspect tag
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

  test "read message" do
    assert :ok == TestProducer.publish(%{example: true})
    assert :ok == TestProducer.publish(1)
    assert :ok == TestProducer.publish("string")
    assert :ok == TestProducer.publish([:list])
    assert :ok == TestProducer.publish(false)
  end

  # test "rapidly publish messages" do
  #   TestProducer.publish(%{example: true})

  #   for n <- 1..1000 do
  #     assert :ok == TestProducer.publish(n)
  #   end

  #   # Doesn't spawn additional connections
  #   assert Supervisor.count_children(ProducerTestConnection).active == 1
  #   assert Supervisor.count_children(ProducerTestConnection).workers == 1

  #   :timer.sleep(500)

  #   assert {:ok, %{message_count: 1001, queue: @queue}} = TestProducer.status
  # end
end
