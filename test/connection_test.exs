defmodule RBMQ.ConnectionTest do
  use ExUnit.Case, async: true
  import RBMQ.Connection
  doctest RBMQ.Connection

  defmodule TestConnection do
    use RBMQ.Connection,
      otp_app: :rbmq,
      queue: [
        name: "decision_queue",
        error_name: "decision_queue_errors",
        routing_key: "decision_queue"
      ],
      exchange: [
        name: "queue_exchange",
        type: :direct,
        durable: true,
      ],
      qos: [
        prefetch_count: 100
      ]

    def callback(arg) do
      IO.inspect(arg)
    end
  end

  test "creates channel" do
    TestConnection.start_link
    TestConnection.spawn_channel(:somename)
    assert %AMQP.Channel{conn: conn} = TestConnection.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)
  end

  test "restarts connection" do
    TestConnection.start_link
    TestConnection.spawn_channel(:somename)
    assert %AMQP.Channel{conn: conn} = TestConnection.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)
  end

  # TODO: how to test killed channels?
  # test "restarts channel" do
  #   TestConnection.start_link
  #   TestConnection.spawn_channel(:somename)

  #   %AMQP.Channel{conn: %AMQP.Connection{} = conn} = TestConnection.get_channel(:somename)
  #   # IO.inspect chan_pid

  #   # :timer.sleep(20000)

  #   # Close connection
  #   # AMQP.Connection.close(conn)
  #   Process.exit(conn.pid, :kill)
  #   # ref = Process.monitor(conn.pid)
  #   # assert_receive {:DOWN, ^ref, _, _, _}


  #   # Wait till it respawns
  #   :timer.sleep(200)

  #   assert %AMQP.Channel{} = chan = TestConnection.get_channel(:somename)
  #   IO.inspect AMQP.Channel.status(chan, "decision_queue")
  # end

  test "runs channel callback" do
    TestConnection.start_link
    {:ok, chan} = TestConnection.spawn_channel(:somename)

    # Kill channel
    Process.exit(chan, :error)
    ref = Process.monitor(chan)
    assert_receive {:DOWN, ^ref, _, _, _}

    # Wait till it respawns
    :timer.sleep(100)

    assert %AMQP.Channel{conn: conn} = TestConnection.get_channel(:somename)
    assert :ok = RBMQ.Connection.Channel.run(:somename, fn _ -> :ok end)
    assert :ok = AMQP.Connection.close(conn)
  end
end
