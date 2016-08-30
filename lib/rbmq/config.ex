defmodule RBMQ.Config do
  @moduledoc """
  Configuration helpers for RBMQ package.
  """

  @doc false
  def get_otp_app(opts) do
    Keyword.fetch!(opts, :otp_app)
  end

  @defaults [
    host: {:system, "AQMP_HOST", "localhost"},
    port: {:system, "AQMP_PORT", 5672},
    username: {:system, "AQMP_USER", "guest"},
    password: {:system, "AQMP_PASSWORD", "guest"},
    virtual_host: {:system, "AQMP_VHOST", "/"},
    connection_timeout: {:system, "AQMP_TIMEOUT", 15_000},
  ]

  @doc """
  Read configuration from environment.

  You can use `{:system, "ENV", default_value}` or `{:system, "ENV"}` tuple to read
  configuration from environment variables in runtime.

  Initialize configs:

      config :rbmq, RBMQ.ConfigTest,
        host: {:system, "HOST", "localhost"},
        port: "5672",
        username: "guest",
        password: "guest",
        prefetch_count: "10",
        amqp_exchange: "rbmq_exchange",
        foo: {:system, "BAR"}

  Read configs:

    Rbmq.Config.get(MyApp.ConsumerQueue, :rbmq)

  """
  def get(module, opts \\ [otp_app: :rbmq]) do
    opts
    |> Keyword.get(:otp_app)
    |> Application.get_env(module, [])
    |> add_params(Keyword.delete(opts, :otp_app))
    |> add_params(@defaults)
    |> parse
  end

  defp parse(params) when is_list(params) do
    params
    |> Enum.map(fn {k, v} -> {k, parse_entry(v)} end)
    |> normalize_port
  end

  defp parse(_) do
    raise ArgumentError, "AQMP params must be a list. " <>
                         "See https://hexdocs.pm/amqp/AMQP.Connection.html#open/1"
  end

  def parse_entry({:system, env, default}) when is_binary(env) do
    parse_entry({:system, env}) || default
  end

  def parse_entry({:system, env}) when is_binary(env) do
    System.get_env(env)
  end

  def parse_entry(value) do
    value
  end

  defp normalize_port(params) do
    {_, params} = Keyword.get_and_update(params, :port, fn port ->
      case cast_integer(port) do
        :error ->
          raise ArgumentError, "can not convert AQMP port to an integer"
        port_int ->
          {port, port_int}
      end
    end)

    params
  end

  defp cast_integer(var) do
    case is_integer(var) do
      true ->
        var
      _ ->
        string_to_integer(var)
    end
  end

  defp string_to_integer(var) do
    case Integer.parse(var) do
      {num, _} ->
        num
      :error ->
        :error
    end
  end

  defp add_params(params, add) do
    add
    |> Keyword.merge(params)
  end
end
