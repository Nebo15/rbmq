defmodule Rbmq do

  def get_amqp_params do
    case Application.get_env(:rbmq, :amqp_params, nil) do
      params when is_list(params)
        -> params
      nil
        -> "amqp://guest:guest@localhost"
      _
        -> raise ":amqp_params must be a list. See https://hexdocs.pm/amqp/AMQP.Connection.html#open/1"
    end
  end
end
