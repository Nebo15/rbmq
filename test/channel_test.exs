defmodule RBMQ.ChannelTest do
  use ExUnit.Case, async: true
  import RBMQ.Connection
  doctest RBMQ.Connection.Channel

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
  end

  test "returns channel" do
    TestConnection.start_link
    assert {:ok, _} = TestConnection.spawn_channel(:somename)

    chan = TestConnection.get_channel(:somename)
    assert %AMQP.Channel{conn: conn} = chan

    assert :ok = AMQP.Connection.close(conn)
  end

  test "runs channel callback" do
    TestConnection.start_link
    assert {:ok, _} = TestConnection.spawn_channel(:somename)
    %AMQP.Channel{conn: conn} = TestConnection.get_channel(:somename)

    assert :ok = RBMQ.Connection.Channel.run(:somename, fn chan ->
      assert %AMQP.Channel{} = chan
      :ok
    end)

    assert :ok = AMQP.Connection.close(conn)
  end
end
