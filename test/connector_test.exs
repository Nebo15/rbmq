defmodule RBMQ.ConnectorTest do
  use ExUnit.Case
  import RBMQ.Connector
  use AMQP
  doctest RBMQ.Connector

  test "invalid host raise exception" do
    assert_raise RuntimeError, "AQMP connection was refused", fn ->
      RBMQ.ConfigTest
      |> RBMQ.Config.get([otp_app: :rbmq, port: 1234])
      |> open_connection!
    end
  end

  test "timeout raises exception" do
    assert_raise RuntimeError, "AQMP connection timeout", fn ->
      RBMQ.ConfigTest
      |> RBMQ.Config.get([otp_app: :rbmq, host: "example.com", connection_timeout: 50])
      |> open_connection!
    end
  end

  test "invalid credentials raise exception" do
    assert_raise RuntimeError, ~r/AQMP authorization failed: 'ACCESS_REFUSED[^']*'/, fn ->
      RBMQ.ConfigTest
      |> RBMQ.Config.get([otp_app: :rbmq, password: "1234"])
      |> open_connection!
    end
  end

  test "invalid vhost raise exception" do
    assert_raise RuntimeError, ~r/AQMP authorization failed: 'ACCESS_REFUSED[^']*'/, fn ->
      RBMQ.ConfigTest
      |> RBMQ.Config.get([otp_app: :rbmq, password: "1234"])
      |> open_connection!
    end
  end

  test "channel closes" do
    RBMQ.ConfigTest
    |> RBMQ.Config.get([otp_app: :rbmq])
    |> open_connection!
    |> open_channel!
    |> close_channel
  end

  test "producer connection initializes" do
    queue_name = "test_queue"
    queue_exchange = "test_exchange"

    RBMQ.ConfigTest
    |> RBMQ.Config.get([otp_app: :rbmq])
    |> open_connection!
    |> open_channel!
    |> declare_queue(queue_name, queue_name <> "_error", durable: true)
    |> declare_exchange(queue_exchange, :direct, durable: true)
    |> bind_queue(queue_name, queue_exchange, [routing_key: queue_name])
  end

  test "consumer connection initializes" do
    queue_name = "test_queue"

    RBMQ.ConfigTest
    |> RBMQ.Config.get([otp_app: :rbmq])
    |> open_connection!
    |> open_channel!
    |> set_channel_qos(prefetch_count: 100)
    |> declare_queue(queue_name, queue_name <> "_error", durable: true)
  end
end
