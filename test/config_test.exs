defmodule RBMQ.ConfigTest do
  use ExUnit.Case
  doctest RBMQ.Config

  test "parse config" do
    setup_default_env

    assert [host: "testhost",
            port: 1011,
            username: "testuser",
            password: "pass",
            virtual_host: "foohost",
            connection_timeout: 15_000,
            prefetch_count: "10",
            amqp_exchange: "rbmq_exchange",
            foo: nil] = RBMQ.Config.get(__MODULE__, [otp_app: :rbmq])
    reset_env
  end

  test "parse config from environment" do
    setup_default_env

    System.put_env("HOST", "somehost")
    System.put_env("BAR", "foo")

    assert [host: "somehost",
            port: 1011,
            username: "testuser",
            password: "pass",
            virtual_host: "foohost",
            connection_timeout: 15_000,
            prefetch_count: "10",
            amqp_exchange: "rbmq_exchange",
            foo: "foo"] = RBMQ.Config.get(__MODULE__, [otp_app: :rbmq])

    System.delete_env("HOST")
    System.delete_env("BAR")

    reset_env
  end

  test "defaults don't override defined opts" do
    Application.put_env(:rbmq, __MODULE__, [
       port: 1234,
       error_queue: "some_queue",
    ])

    assert [host: "localhost",
            username: "guest",
            password: "guest",
            virtual_host: "/",
            connection_timeout: 15_000,
            port: 1234,
            error_queue: "some_queue"] = RBMQ.Config.get(__MODULE__, [otp_app: :rbmq])
    reset_env
  end

  test "works without config in env" do
    assert [host: "localhost",
            port: 5672,
            username: "guest",
            password: "guest",
            virtual_host: "/",
            connection_timeout: 15_000] = RBMQ.Config.get(__MODULE__, [otp_app: :rbmq])
  end

  test "works with default otp app" do
    assert [host: "localhost",
            port: 5672,
            username: "guest",
            password: "guest",
            virtual_host: "/",
            connection_timeout: 15_000] = RBMQ.Config.get(__MODULE__)
  end

  test "works with unexistent app" do
    assert [host: "localhost",
            port: 5672,
            username: "guest",
            password: "guest",
            virtual_host: "/",
            connection_timeout: 15_000] = RBMQ.Config.get(__MODULE__, [otp_app: :myapp])
  end

  test "defaults reads env" do
    System.put_env("AMQP_HOST", "somehost")
    System.put_env("AMQP_PORT", "1234")
    System.put_env("AMQP_USER", "foo")
    System.put_env("AMQP_PASSWORD", "bar")
    System.put_env("AMQP_VHOST", "foohost")
    res = RBMQ.Config.get(__MODULE__, [otp_app: :rbmq])
    System.delete_env("AMQP_HOST")
    System.delete_env("AMQP_PORT")
    System.delete_env("AMQP_USER")
    System.delete_env("AMQP_PASSWORD")
    System.delete_env("AMQP_VHOST")

    assert [host: "somehost",
            port: 1234,
            username: "foo",
            password: "bar",
            virtual_host: "foohost",
            connection_timeout: 15_000] = res
  end

  defp setup_default_env do
    Application.put_env(:rbmq, __MODULE__, [
       host: {:system, "HOST", "testhost"},
       port: "1011",
       username: "testuser",
       password: "pass",
       virtual_host: "foohost",
       connection_timeout: 15_000,
       prefetch_count: "10",
       amqp_exchange: "rbmq_exchange",
       foo: {:system, "BAR"}
    ])
  end

  defp reset_env do
    Application.delete_env(:rbmq, __MODULE__)
  end
end
