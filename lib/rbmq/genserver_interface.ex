defmodule Rbmq.Genserver.Interface do
  @moduledoc """
  Supervisor interface for RabbitMQ Producers and Consumers.
  """

  def get_amqp_params do
    get_amqp_params Application.get_env(:rbmq, :amqp_params)
  end

  defp get_amqp_params(params) when is_list(params) do
    params
  end

  defp get_amqp_params(_) do
    raise ":amqp_params must be a list. See https://hexdocs.pm/amqp/AMQP.Connection.html#open/1"
  end

  def get_exchange(nil) do
    get_exchange Application.get_env(:rbmq, :amqp_exchange)
  end

  def get_exchange(exchange) when is_binary(exchange) do
    exchange
  end

  def get_exchange(_) do
    raise "exchange name must be a string"
  end

  def get_prefetch_count(nil) do
    get_prefetch_count Application.get_env(:rbmq, :prefetch_count, 10)
  end

  def get_prefetch_count(num) when is_integer(num) do
    num
  end

  def get_prefetch_count(_) do
    raise "prefetch_count must be an integer"
  end

  def via_tuple(name) do
    {:via, :gproc, {:n, :l, {:queue, name}}}
  end

  def get_server(name) do
    server = via_tuple(name)
    case GenServer.whereis(server) do
      nil -> {:error, "process with name '#{name}' does not exists"}
      _   -> {:ok, server}
    end
  end

  def server_call({:ok, server}, data) do
    GenServer.call(server, data)
  end

  def server_call({:error, reason}, _) do
    {:error, reason}
  end
end
