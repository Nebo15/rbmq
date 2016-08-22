defmodule RBMQ.Genserver.Interface do
  
  def get_amqp_params do
    case Application.get_env(:rbmq, :amqp_params, nil) do
      params when is_list(params) ->
        params
      nil ->
        "amqp://guest:guest@localhost"
      _ ->
        raise ":amqp_params must be a list. See https://hexdocs.pm/amqp/AMQP.Connection.html#open/1"
    end
  end
  
  def via_tuple(name) do
    {:via, :gproc, {:n, :l, {:queue, "consumer_#{name}"}}}
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