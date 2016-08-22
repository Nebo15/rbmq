defmodule RbmqTest do
  use ExUnit.Case
  doctest Rbmq

  test "the truth" do
    p1 = "p1"

    queue1 = "os_decision_queue"
    queue2 = "os_decision_next"

    RBMQ.SupervisorProducer.start_link
    RBMQ.SupervisorProducer.start_producer(p1, queue1)

    c1 = "c1"
    c2 = "c2"
    c3 = "c3"
    c4 = "c4"
    c5 = "c5"


    {:ok, conn} = Postgrex.start_link(hostname: "localhost", username: "postgres", password: "postgres", database: "rbmq")
    Postgrex.query(conn, "TRUNCATE sample", [])

    RBMQ.SupervisorConsumer.start_link
    RBMQ.SupervisorConsumer.start_consumer(c1, queue1)
    RBMQ.SupervisorConsumer.start_consumer(c2, queue1)
    RBMQ.SupervisorConsumer.start_consumer(c3, queue1)
#    RBMQ.SupervisorConsumer.start_consumer(c4, queue1)
#    RBMQ.SupervisorConsumer.start_consumer(c5, queue1)
#    RBMQ.SupervisorConsumer.start_consumer("c6", queue2)
#    RBMQ.SupervisorConsumer.start_consumer("c7", queue2)
#    RBMQ.SupervisorConsumer.start_consumer("c8", queue2)
#    RBMQ.SupervisorConsumer.start_consumer("c9", queue2)
#    RBMQ.SupervisorConsumer.start_consumer("c10", queue2)
#    RBMQ.SupervisorConsumer.start_consumer("c11", "os_decision_next")

    for n <- 1..10000, do: MQ.Producer.publish(p1, queue1, n)

#    :timer.sleep(15000)

    IO.inspect MQ.Consumer.status(c1, queue1)
    IO.inspect MQ.Consumer.status(c1, queue2)
    IO.inspect MQ.Consumer.status(c1, "#{queue1}_error")
    IO.inspect MQ.Consumer.status(c1, "#{queue2}_error")



#    MQ.Consumer.get(c4, "#{queue2}_error")
#    MQ.Consumer.get(c5, "#{queue2}_error")

  end

  test "supervisor restart consumer and producer processes" do
    p1 = "p100"
    c1 = "c100"
    queue = "os_decision_queue"

    RBMQ.SupervisorProducer.start_link
    RBMQ.SupervisorProducer.start_producer(p1, queue)

    RBMQ.SupervisorConsumer.start_link
    RBMQ.SupervisorConsumer.start_consumer(c1, queue)

    assert :gproc.where({:n, :l, {:queue, "consumer_#{c1}"}}) |> Process.exit(:kill)
    assert :gproc.where({:n, :l, {:queue, "producer_#{p1}"}}) |> Process.exit(:kill)

    :timer.sleep(150)

    assert :undefined != :gproc.where({:n, :l, {:queue, "consumer_#{c1}"}})
    assert :undefined != :gproc.where({:n, :l, {:queue, "producer_#{p1}"}})
  end
end
