defmodule RBMQ.ChannelTest do
  use ExUnit.Case
  import RBMQ.Connection
  doctest RBMQ.Connection.Channel

  defmodule TestConnection do
    use RBMQ.Connection,
      otp_app: :rbmq
  end

  defmodule TestChannelSupervisor do
    def start do
      import Supervisor.Spec, warn: false

      children = [
        supervisor(TestConnection, []),
      ]

      opts = [strategy: :one_for_one, name: TestChannelSupervisor]
      Supervisor.start_link(children, opts)
    end
  end

  setup do
    TestChannelSupervisor.start
    TestConnection.spawn_channel(:somename)
    %AMQP.Channel{conn: conn} = chan = TestConnection.get_channel(:somename)

    on_exit fn ->
      assert :ok = AMQP.Connection.close(conn)
    end

    [channel: chan]
  end

  test "runs channel callback" do
    assert :ok = RBMQ.Connection.Channel.run(:somename, fn chan ->
      assert %AMQP.Channel{} = chan
      :ok
    end)
  end

  # TODO: configuration tests

  # Channel should not loose its configuration when AQMP channel dies
  # test "recreates channels", context do
  #   # Kill channel
  #   Process.exit(context[:channel].pid, :shutdown)

  #   # ref = Process.monitor(context[:channel].pid)
  #   # assert_receive {:DOWN, ^ref, _, _, _}

  #   # Wait till it respawns
  #   :observer.start
  #   :timer.sleep(50000)

  #   # Doesn't spawn additional connections
  #   assert Supervisor.count_children(TestConnection).active == 1
  #   assert Supervisor.count_children(TestConnection).workers == 1

  #   # assert {:ok, %{message_count: 100, queue: @queue}} = TestProducer.status
  # end
end
