defmodule RbmqTest do
  use ExUnit.Case
  doctest Rbmq

  @p1 "p1"
  @c1 "c1"
  @exchange "test_exchange"
  @queue "os_decision_queue"

  test "the truth" do
#    c2 = "c2"
#    c3 = "c3"
#    c4 = "c4"
#    c5 = "c5"

    assert {:ok, _pid} = Rbmq.start_consumer_supervisor
    assert {:ok, _pid} = Rbmq.start_producer_supervisor
    assert {:ok, _pid} = Rbmq.spawn_producer(@p1, @queue, @exchange)
    assert {:ok, _pid} = Rbmq.spawn_consumer(@c1, @queue, @exchange)

    assert :ok == Rbmq.publish(@p1, @queue, 1)
    assert :ok == Rbmq.publish(@p1, @queue, %{map: "really"})

    :timer.sleep 100
#    IO.inspect Rbmq.status(@c1, @queue)



#    Rbmq.start_producer_supervisor
#    Rbmq.SupervisorConsumer.start_consumer(c1, queue1)
#    Rbmq.SupervisorConsumer.start_consumer(c2, queue1)
#    Rbmq.SupervisorConsumer.start_consumer(c3, queue1)
#    Rbmq.SupervisorConsumer.start_consumer(c4, queue1)
#    Rbmq.SupervisorConsumer.start_consumer(c5, queue1)
#    Rbmq.SupervisorConsumer.start_consumer("c6", queue2)
#    Rbmq.SupervisorConsumer.start_consumer("c7", queue2)
#    Rbmq.SupervisorConsumer.start_consumer("c8", queue2)
#    Rbmq.SupervisorConsumer.start_consumer("c9", queue2)
#    Rbmq.SupervisorConsumer.start_consumer("c10", queue2)
#    Rbmq.SupervisorConsumer.start_consumer("c11", "os_decision_next")

#    for n <- 1..10000, do: MQ.Producer.publish(p1, queue1, n)

#    :timer.sleep(15000)

#    IO.inspect MQ.Consumer.status(c1, queue1)
#    IO.inspect MQ.Consumer.status(c1, queue2)
#    IO.inspect MQ.Consumer.status(c1, "#{queue1}_error")
#    IO.inspect MQ.Consumer.status(c1, "#{queue2}_error")



#    MQ.Consumer.get(c4, "#{queue2}_error")
#    MQ.Consumer.get(c5, "#{queue2}_error")

  end

  test "exchange must be a list" do
    Rbmq.start_consumer_supervisor
    Rbmq.start_producer_supervisor

    {:error, {:EXIT, {%RuntimeError{message: err_msg}, _}}} = Rbmq.spawn_consumer(@p1, @queue, :exchange)
    assert "exchange name must be a string" == err_msg

    {:error, {:EXIT, {%RuntimeError{message: err_msg}, _}}} = Rbmq.spawn_producer(@p1, @queue, :exchange)
     assert "exchange name must be a string" == err_msg
  end

  test "supervisor restart consumer and producer processes" do
    p1 = "p100"
    c1 = "c100"
    queue = "os_decision_queue"

    Rbmq.SupervisorProducer.start_link
    Rbmq.SupervisorProducer.start_producer(p1, queue)

    Rbmq.SupervisorConsumer.start_link
    Rbmq.SupervisorConsumer.start_consumer(c1, queue)

    assert :gproc.where({:n, :l, {:queue, "consumer_#{c1}"}}) |> Process.exit(:kill)
    assert :gproc.where({:n, :l, {:queue, "producer_#{p1}"}}) |> Process.exit(:kill)

    :timer.sleep(150)

    assert :undefined != :gproc.where({:n, :l, {:queue, "consumer_#{c1}"}})
    assert :undefined != :gproc.where({:n, :l, {:queue, "producer_#{p1}"}})
  end
end
