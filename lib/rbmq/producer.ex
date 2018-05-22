defmodule RBMQ.Producer do
  @moduledoc """
  AMQP channel producer.

  You must configure connection (queue and exchange) before calling `publish/1` function.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use RBMQ.GenQueue, opts

      def validate_config!(conf) do
        unless conf[:queue][:routing_key] do
          raise "You need to set queue routing key in #{__MODULE__} options."
        end

        case conf[:queue][:routing_key] do
          {:system, _, _} ->
            :ok

          {:system, _} ->
            :ok

          str when is_binary(str) ->
            :ok

          unknown ->
            raise "Queue routing key for #{__MODULE__} must be a string or env link, " <>
                    "'#{inspect(unknown)}' given."
        end

        unless conf[:exchange] do
          raise "You need to configure exchange in #{__MODULE__} options."
        end

        unless conf[:exchange][:name] do
          raise "You need to set exchange name in #{__MODULE__} options."
        end

        case conf[:exchange][:name] do
          {:system, _, _} ->
            :ok

          {:system, _} ->
            :ok

          str when is_binary(str) ->
            :ok

          unknown ->
            raise "Exchange name key for #{__MODULE__} must be a string or env link, " <>
                    "'#{inspect(unknown)}' given."
        end

        unless conf[:exchange][:type] do
          raise "You need to set exchange name in #{__MODULE__} options."
        end

        unless conf[:exchange][:type] in [:direct, :fanout, :topic, :headers] do
          raise "Incorrect exchange type in #{__MODULE__} options."
        end

        conf
      end

      @doc """
      Publish new message to a linked channel.
      """
      def publish(data) do
        GenServer.call(__MODULE__, {:publish, data}, :infinity)
      end

      @doc false
      def handle_call({:publish, data}, _from, chan) do
        case Jason.encode(data) do
          {:ok, encoded_data} ->
            safe_publish(chan, encoded_data)

          {:error, _} = err ->
            {:reply, err, chan}
        end
      end

      defp safe_publish(chan, data) do
        safe_run(fn chan ->
          cast(chan, data)
        end)
      end

      defp cast(chan, data) do
        conf = chan_config()

        is_persistent = Keyword.get(conf[:queue], :durable, false)

        case AMQP.Basic.publish(
               chan,
               conf[:exchange][:name],
               conf[:queue][:routing_key],
               data,
               mandatory: true,
               persistent: is_persistent
             ) do
          :ok ->
            {:reply, :ok, chan}

          _ ->
            {:reply, :error, chan}
        end
      end

      defoverridable validate_config!: 1
    end
  end

  @doc """
  Publish new message to a linked channel.

  If channel is down it will keep trying to send message with 3 second timeout.
  """
  @callback publish :: :ok | :error
end
