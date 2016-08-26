defmodule RbmqTest do
  use ExUnit.Case
  doctest Rbmq
  use AMQP

  @p1 "p1"
  @c1 "c1"
  @exchange "test_exchange"
  @queue "os_decision_queue"

  def consumer_callback(chan, tag, redelivered, _payload, _key) do
    try do
      :timer.sleep(5)
      Basic.ack chan, tag
    rescue
      _ -> Basic.reject chan, tag, requeue: not redelivered
    end
  end

  test "the processes spawn" do

    assert {:ok, pid1} = Rbmq.start_consumer_supervisor
    assert {:ok, pid2} = Rbmq.start_producer_supervisor

    assert {:ok, _pid} = Rbmq.spawn_producer(@p1, @queue, 10, @exchange)
    assert {:ok, _pid} = Rbmq.spawn_consumer(@c1, @queue, &consumer_callback/5, @exchange)
    assert {:ok, _pid} = Rbmq.spawn_consumer("c2", @queue, &consumer_callback/5, @exchange)
    assert {:ok, _pid} = Rbmq.spawn_consumer("c3", @queue, &consumer_callback/5, @exchange)
    assert {:ok, _pid} = Rbmq.spawn_consumer("c4", @queue, &consumer_callback/5, @exchange)

    assert :ok == Rbmq.publish(@p1, @queue, 1)
    assert :ok == Rbmq.publish(@p1, @queue, 1)
    assert :ok == Rbmq.publish(@p1, @queue, "string")
    assert :ok == Rbmq.publish(@p1, @queue, [:list])
    assert :ok == Rbmq.publish(@p1, @queue, %{map: "really"})


    for n <- 1..1000 do
      assert :ok == Rbmq.publish(@p1, @queue, n)
    end

    :timer.sleep(2000)

    assert {:ok, %{consumer_count: 4, message_count: 0, queue: @queue}} = Rbmq.status(@c1, @queue)

    assert Process.exit(pid1, :kill)
    assert Process.exit(pid2, :kill)
  end

  test "exchange must be a list" do
    assert {:ok, pid1} = Rbmq.start_consumer_supervisor
    assert {:ok, pid2} = Rbmq.start_producer_supervisor

    {:error, {:EXIT, {%RuntimeError{message: err_msg}, _}}} =
    Rbmq.spawn_consumer(@p1, @queue, &consumer_callback/5, :exchange)
    assert "exchange name must be a string" == err_msg

    {:error, {:EXIT, {%RuntimeError{message: err_msg}, _}}} =
    Rbmq.spawn_producer(@p1, @queue, 10, :exchange)

    assert "exchange name must be a string" == err_msg

    assert Process.exit(pid1, :kill)
    assert Process.exit(pid2, :kill)
  end

  test "prefetch_count must be an integer" do
    assert {:ok, pid1} = Rbmq.start_producer_supervisor

    {:error, {:EXIT, {%RuntimeError{message: err}, _}}} = Rbmq.spawn_producer(@p1, @queue, [])
    assert "prefetch_count must be an integer" == err

    {:error, {:EXIT, {%RuntimeError{message: err}, _}}} = Rbmq.spawn_producer(@p1, @queue, "invalid")
    assert "can not convert prefetch_count to an integer" == err

    assert Process.exit(pid1, :kill)
  end

  test "supervisor restart consumer and producer processes" do
    p1 = "p100"
    c1 = "c100"
    queue = "os_decision_queue"

    assert {:ok, pid1} = Rbmq.start_producer_supervisor
    assert {:ok, _pid} = Rbmq.spawn_producer(p1, queue)

    assert {:ok, pid2} = Rbmq.start_consumer_supervisor
    assert {:ok, _pid} = Rbmq.spawn_consumer(c1, queue, &consumer_callback/5)

    proc1 = {:n, :l, {:queue, c1}}
    proc2 = {:n, :l, {:queue, p1}}

    assert proc1
    |> :gproc.where
    |> Process.exit(:kill)

    assert proc2
    |> :gproc.where
    |> Process.exit(:kill)

    :timer.sleep(150)

    assert :undefined != :gproc.where({:n, :l, {:queue, c1}})
    assert :undefined != :gproc.where({:n, :l, {:queue, p1}})

    assert Process.exit(pid1, :kill)
    assert Process.exit(pid2, :kill)
  end
end
