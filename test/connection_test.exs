defmodule RBMQ.ConnectionTest do
  use ExUnit.Case
  import RBMQ.Connection
  doctest RBMQ.Connection

  defmodule TestConnection do
    use RBMQ.Connection,
      otp_app: :rbmq,
      queue: [
        name: "test_qeueue_1",
        error_name: "test_qeueue_1_error",
        routing_key: "test_qeueue_1"
      ],
      exchange: [
        name: "test_queue_1_exchange",
        type: :direct,
        durable: true
      ],
      qos: [
        prefetch_count: 100
      ]
  end

  defmodule TestConnectionWithExternalConfig do
    use RBMQ.Connection, otp_app: :rbmq
  end

  defmodule TestConnectionWithoutConfig do
    use RBMQ.Connection, otp_app: :rbmq
  end

  defmodule TestConnectionWithQOS do
    use RBMQ.Connection,
      otp_app: :rbmq,
      qos: [
        prefetch_count: 100
      ]
  end

  defmodule TestConnectionWithQueue do
    use RBMQ.Connection,
      otp_app: :rbmq,
      queue: [
        name: "test_qeueue_2",
        error_name: "test_qeueue_2_error",
        routing_key: "test_qeueue_2"
      ]
  end

  defmodule TestConnectionWithExchange do
    use RBMQ.Connection,
      otp_app: :rbmq,
      exchange: [
        name: "test_queue_2_exchange",
        type: :direct,
        durable: true
      ]
  end

  defmodule TestConnectionWithExchangeAndQueue do
    use RBMQ.Connection,
      otp_app: :rbmq,
      queue: [
        name: "test_qeueue_3",
        error_name: "test_qeueue_3_error",
        routing_key: "test_qeueue_2"
      ],
      exchange: [
        name: "test_qeueue_2_exchange",
        type: :direct,
        durable: true
      ]
  end

  test "starts connection" do
    assert {:ok, _} = TestConnection.start_link()
  end

  test "starts multiple connections" do
    assert {:ok, _} = TestConnection.start_link()
    assert {:ok, _} = TestConnectionWithExchangeAndQueue.start_link()
  end

  test "returns channel without config" do
    TestConnectionWithoutConfig.start_link()
    assert {:ok, _} = TestConnectionWithoutConfig.spawn_channel(:somename)

    %AMQP.Channel{conn: conn} = TestConnectionWithoutConfig.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)
  end

  test "reads external config" do
    System.put_env("CUST_MQ_HOST", "localhost")
    System.put_env("CUST_MQ_PORT", "5672")

    TestConnectionWithExternalConfig.start_link()
    assert {:ok, _} = TestConnectionWithExternalConfig.spawn_channel(:somename)

    %AMQP.Channel{conn: conn} = TestConnectionWithExternalConfig.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)

    System.delete_env("CUST_MQ_HOST")
    System.delete_env("CUST_MQ_PORT")
  end

  test "configures channel" do
    TestConnectionWithoutConfig.start_link()
    assert {:ok, _} = TestConnectionWithoutConfig.spawn_channel(:somename)
    %AMQP.Channel{conn: conn} = TestConnectionWithoutConfig.get_channel(:somename)

    conf = [
      queue: [
        name: "test_qeueue_4",
        error_name: "test_qeueue_4_error",
        routing_key: "test_qeueue_4"
      ],
      exchange: [
        name: "test_qeueue_2_exchange",
        type: :direct,
        durable: true
      ],
      qos: [
        prefetch_count: 100
      ]
    ]

    assert :ok = TestConnectionWithoutConfig.configure_channel(:somename, conf)
    assert :ok = AMQP.Connection.close(conn)
  end

  test "returns channel with qos config" do
    TestConnectionWithQOS.start_link()
    assert {:ok, _} = TestConnectionWithQOS.spawn_channel(:somename)

    %AMQP.Channel{conn: conn} = TestConnectionWithQOS.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)
  end

  test "returns channel with queue config" do
    TestConnectionWithQueue.start_link()
    assert {:ok, _} = TestConnectionWithQueue.spawn_channel(:somename)

    %AMQP.Channel{conn: conn} = TestConnectionWithQueue.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)
  end

  test "returns channel with exchange config" do
    TestConnectionWithExchange.start_link()
    assert {:ok, _} = TestConnectionWithExchange.spawn_channel(:somename)

    %AMQP.Channel{conn: conn} = TestConnectionWithExchange.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)
  end

  test "returns channel with queue and exchange config" do
    TestConnectionWithExchangeAndQueue.start_link()
    assert {:ok, _} = TestConnectionWithExchangeAndQueue.spawn_channel(:somename)

    %AMQP.Channel{conn: conn} = TestConnectionWithExchangeAndQueue.get_channel(:somename)
    assert :ok = AMQP.Connection.close(conn)
  end

  test "spawns multiple channels" do
    TestConnection.start_link()

    TestConnection.spawn_channel(:somename)
    assert %AMQP.Channel{} = TestConnection.get_channel(:somename)

    assert Supervisor.count_children(TestConnection).workers == 1
    assert Supervisor.count_children(TestConnection).active == 1

    TestConnection.spawn_channel(:othername)
    assert %AMQP.Channel{conn: conn} = TestConnection.get_channel(:othername)

    assert Supervisor.count_children(TestConnection).workers == 2
    assert Supervisor.count_children(TestConnection).active == 2

    assert :ok = AMQP.Connection.close(conn)
  end

  test "restarts connection" do
    TestConnectionWithQueue.start_link()
    TestConnectionWithQueue.spawn_channel(:somename)

    %AMQP.Channel{conn: conn} = TestConnectionWithQueue.get_channel(:somename)

    # :timer.sleep(20000)

    # Kill connection, it dies with channels
    ref = Process.monitor(conn.pid)
    AMQP.Connection.close(conn)
    assert_receive {:DOWN, ^ref, _, _, _}

    # Wait till channel restarts
    :timer.sleep(1000)

    assert %AMQP.Channel{} = chan = TestConnectionWithQueue.get_channel(:somename)
    assert {:ok, _} = AMQP.Queue.status(chan, "test_qeueue_2")
  end

  test "closes channels" do
    TestConnection.start_link()
    {:ok, chan} = TestConnection.spawn_channel(:somename)
    %AMQP.Channel{conn: conn} = TestConnection.get_channel(:somename)

    assert Process.alive?(chan)
    assert Supervisor.count_children(TestConnection).workers == 1
    assert Supervisor.count_children(TestConnection).active == 1

    TestConnection.close_channel(:somename)

    refute Process.alive?(chan)
    assert Supervisor.count_children(TestConnection).workers == 0
    assert Supervisor.count_children(TestConnection).active == 0

    assert :ok = AMQP.Connection.close(conn)
  end

  test "restarts channels" do
    TestConnection.start_link()
    assert {:ok, chan} = TestConnection.spawn_channel(:somename)

    # Kill channel
    Process.exit(chan, :error)
    ref = Process.monitor(chan)
    assert_receive {:DOWN, ^ref, _, _, _}

    # Wait till it respawns
    :timer.sleep(100)

    assert %AMQP.Channel{conn: conn} = TestConnection.get_channel(:somename)

    assert :ok = AMQP.Connection.close(conn)
  end

  test "restarts bare channels without config loss" do
    TestConnectionWithoutConfig.start_link()
    TestConnectionWithoutConfig.spawn_channel(:somename)
    initial_channel = TestConnectionWithoutConfig.get_channel(:somename)

    # Configure channel
    conf = [
      queue: [
        name: "test_qeueue_6",
        error_name: "test_qeueue_6_error",
        routing_key: "test_qeueue_6"
      ],
      exchange: [
        name: "test_qeueue_2_exchange",
        type: :direct,
        durable: true
      ],
      qos: [
        prefetch_count: 100
      ]
    ]

    TestConnectionWithoutConfig.configure_channel(:somename, conf)

    ref = Process.monitor(initial_channel.pid)
    AMQP.Channel.close(initial_channel)
    assert_receive {:DOWN, ^ref, _, _, _}

    # Wait till channel restarts
    :timer.sleep(1000)

    assert %AMQP.Channel{conn: conn} =
             new_channel = TestConnectionWithoutConfig.get_channel(:somename)

    # New channel should work properly
    assert AMQP.Queue.message_count(new_channel, conf[:queue][:name]) == 0

    # And it should be a different channel
    refute initial_channel.pid == new_channel.pid

    assert :ok = AMQP.Connection.close(conn)
  end
end
