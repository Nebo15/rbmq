defmodule RBMQ.Connection.HelperTest do
  use ExUnit.Case
  import RBMQ.Connection.Helper
  use AMQP
  doctest RBMQ.Connection.Helper

  defmodule SampleConfigurator do
    use Confex, otp_app: :rbmq
  end

  alias RBMQ.Connection.HelperTest.SampleConfigurator

  setup do
    Application.delete_env(:rbmq, SampleConfigurator)
  end

  test "invalid host raise exception" do
    Application.put_env(:rbmq, SampleConfigurator, [port: 1234])

    assert_raise RuntimeError, "AMQP connection was refused", fn ->
      SampleConfigurator.config
      |> open_connection!
    end
  end

  test "timeout raises exception" do
    Application.put_env(:rbmq, SampleConfigurator, [host: "example.com", connection_timeout: 50])

    assert_raise RuntimeError, "AMQP connection timeout", fn ->
      SampleConfigurator.config
      |> open_connection!
    end
  end

  test "invalid credentials raise exception" do
    Application.put_env(:rbmq, SampleConfigurator, [password: "1234"])

    assert_raise RuntimeError, ~r/AMQP authorization failed: 'ACCESS_REFUSED[^']*'/, fn ->
      SampleConfigurator.config
      |> open_connection!
    end
  end

  test "invalid vhost raise exception" do
    Application.put_env(:rbmq, SampleConfigurator, [virtual_host: "somevhost"])

    assert_raise RuntimeError, "AMQP vhost not allowed", fn ->
      SampleConfigurator.config
      |> open_connection!
    end
  end

  test "channel closes" do
    SampleConfigurator.config
    |> open_connection!
    |> open_channel!
    |> close_channel
  end

  test "producer connection initializes" do
    queue_name = "test_queue_for_producer"
    queue_exchange = "test_exchange_for_producer"

    SampleConfigurator.config
    |> open_connection!
    |> open_channel!
    |> declare_queue(queue_name, queue_name <> "_error", durable: true)
    |> declare_exchange(queue_exchange, :direct, durable: true)
    |> bind_queue(queue_name, queue_exchange, [routing_key: queue_name])
  end

  test "consumer connection initializes" do
    queue_name = "test_queue_for_consumer"

    SampleConfigurator.config
    |> open_connection!
    |> open_channel!
    |> set_channel_qos(prefetch_count: 100)
    |> declare_queue(queue_name, queue_name <> "_error", durable: true)
  end
end
