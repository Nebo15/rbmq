defmodule RBMQ.Consumer do
  @moduledoc """
  AQMP channel producer.

  You must configure connection (queue and exchange) before calling `publish/1` function.

  TODO: take look at genevent and defimpl Stream (use as Stream) for consumers.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use RBMQ.GenQueue, opts

      defp init_worker(chan, opts) do
        {:ok, _consumer_tag} = AMQP.Basic.consume(chan, opts[:queue][:name])
        chan
      end

      # Confirmation sent by the broker after registering this process as a consumer
      def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:noreply, state}
      end

      # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
      def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
        {:stop, :shutdown, state}
      end

      # Confirmation sent by the broker to the consumer process after a Basic.cancel
      def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:stop, :normal, state}
      end

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, state) do
        consume(payload, [tag: tag, redelivered?: redelivered, channel: state])
        {:noreply, state}
      end

      def ack(conn, tag) do
        AMQP.Basic.ack(conn, tag)
      end

      def nack(conn, tag) do
        AMQP.Basic.nack(conn, tag)
      end

      def cancel(chan, tag) do
        AMQP.Basic.cancel(chan, tag)
      end

      def consume(_payload, [tag: tag, redelivered?: _redelivered, channel: chan]) do
        # Mark this message as unprocessed
        nack(chan, tag)
        # Stop consumer from receiving more messages
        cancel(chan, tag)
        raise "#{__MODULE__}.consume/2 is not implemented"
      end

      defoverridable [consume: 2]
    end
  end

  @doc """
  Receiver of messages.

  If channel is down it will keep trying to send message with 3 second timeout.
  """
  @callback consume :: :ok | :error
end
