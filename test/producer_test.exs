defmodule RBMQ.ProducerTest do
  use ExUnit.Case
  import RBMQ.Connection
  use AMQP
  doctest RBMQ.GenericProducer

  defmodule ProducerTestConnection do
    use RBMQ.Connection,
      otp_app: :rbmq
  end

  @queue "producer_test_qeueue"

  defmodule TestProducer do
    use RBMQ.GenericProducer,
      connection: ProducerTestConnection,
      queue: [
        name: "producer_test_qeueue",
        error_name: "producer_test_qeueue_errors",
        routing_key: "producer_test_qeueue",
        durable: false
      ],
      exchange: [
        name: "producer_test_qeueue_exchange",
        type: :direct,
        durable: false
      ]
  end

  setup_all do
    ProducerTestConnection.start_link
    TestProducer.start_link
    :ok
  end

  setup do
    chan = ProducerTestConnection.get_channel(RBMQ.ProducerTest.TestProducer.Channel)
    AMQP.Queue.purge(chan, @queue)
    [channel: chan]
  end

  test "publish message" do
    assert :ok == TestProducer.publish(%{example: true})
    assert :ok == TestProducer.publish(1)
    assert :ok == TestProducer.publish("string")
    assert :ok == TestProducer.publish([:list])
    assert :ok == TestProducer.publish(false)
  end

  test "rapidly publish messages" do
    TestProducer.publish(%{example: true})

    for n <- 1..1000 do
      assert :ok == TestProducer.publish(n)
    end

    # Doesn't spawn additional connections
    assert Supervisor.count_children(ProducerTestConnection).active == 1
    assert Supervisor.count_children(ProducerTestConnection).workers == 1

    :timer.sleep(500)

    assert {:ok, %{message_count: 1001, queue: @queue}} = TestProducer.status
  end

  # test "messages delivered when channel dies", context do
  #   # Kill connection, it dies with channels
  #   # Process.exit(context[:channel].pid, :kill)

  #   # Kill channel
  #   Process.exit(context[:channel].pid, :shutdown)

  #   # ref = Process.monitor(context[:channel].pid)
  #   # assert_receive {:DOWN, ^ref, _, _, _}

  #   for n <- 1..100 do
  #     assert :ok == TestProducer.publish(n)
  #   end

  #   # Wait till it respawns
  #   :timer.sleep(100)

  #   # Doesn't spawn additional connections
  #   assert Supervisor.count_children(ProducerTestConnection).active == 1
  #   assert Supervisor.count_children(ProducerTestConnection).workers == 1

  #   :timer.sleep(500)

  #   assert {:ok, %{message_count: 100, queue: @queue}} = TestProducer.status
  # end
end
