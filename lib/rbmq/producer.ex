defmodule RBMQ.Producer do
  @moduledoc """
  AMQP channel producer.

  You must configure connection (queue and exchange) before calling `publish/1` function.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use RBMQ.GenQueue, opts

      unless @channel_conf[:queue][:routing_key] do
        raise "You need to set queue routing key in #{__MODULE__} options."
      end

      unless is_binary(@channel_conf[:queue][:routing_key]) do
        raise "Queue routing key for #{__MODULE__} must be a string."
      end

      unless @channel_conf[:exchange] do
        raise "You need to configure exchange in #{__MODULE__} options."
      end

      unless @channel_conf[:exchange][:name] do
        raise "You need to set exchange name in #{__MODULE__} options."
      end

      unless is_binary(@channel_conf[:exchange][:name]) do
        raise "Exchange name key for #{__MODULE__} must be a string."
      end

      unless @channel_conf[:exchange][:type] do
        raise "You need to set exchange name in #{__MODULE__} options."
      end

      unless @channel_conf[:exchange][:type] in [:direct, :fanout, :topic, :headers] do
        raise "Incorrect exchange type in #{__MODULE__} options."
      end

      @doc """
      Publish new message to a linked channel.
      """
      def publish(data) do
        GenServer.call(__MODULE__, {:publish, data}, :infinity)
      end

      @doc false
      def handle_call({:publish, data}, _from, chan) do
        case Poison.encode(data) do
          {:ok, encoded_data} ->
            safe_publish(chan, encoded_data)
          {:error, _} = err ->
            {:reply, err, chan}
        end
      end

      defp safe_publish(chan, data) do
        safe_run fn(chan) ->
          cast(chan, data)
        end
      end

      defp cast(chan, data) do
        is_persistent = Keyword.get(config[:queue], :durable, false)

        case AMQP.Basic.publish(chan,
                                config[:exchange][:name],
                                config[:queue][:routing_key],
                                data,
                                [mandatory: true,
                                 persistent: is_persistent]) do
          :ok ->
            {:reply, :ok, chan}
          _ ->
            {:reply, :error, chan}
        end
      end
    end
  end

  @doc """
  Publish new message to a linked channel.

  If channel is down it will keep trying to send message with 3 second timeout.
  """
  @callback publish :: :ok | :error
end
