defmodule RBMQ.Producer do
  @moduledoc """
  AQMP channel producer.

  You must configure connection (queue and exchange) before calling `publish/1` function.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use RBMQ.GenQueue, opts

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
