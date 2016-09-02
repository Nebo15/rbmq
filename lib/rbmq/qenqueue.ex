defmodule RBMQ.GenQueue do
  @moduledoc false

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      require Logger

      @connection Keyword.get(opts, :connection)
      @channel_name String.to_atom("#{__MODULE__}.Channel")
      @channel_conf Keyword.delete(opts, :connection)

      unless @connection do
        raise "You need to implement connection module and pass it in :connection option."
      end

      def start_link do
        GenServer.start_link(__MODULE__, @channel_conf, name: __MODULE__)
      end

      def init(opts) do
        case Process.whereis(@connection) do
          nil ->
            # Connection doesn't exist, lets fail to recover later
            {:error, :noconn}
          _ ->
            @connection.spawn_channel(@channel_name)
            @connection.configure_channel(@channel_name, opts)

            chan = get_channel
            |> init_worker(opts)

            {:ok, chan}
        end
      end

      defp init_worker(chan, _opts) do
        chan
      end

      defp get_channel do
        chan = @channel_name
        |> @connection.get_channel
      end

      def status do
        GenServer.call(__MODULE__, :status)
      end

      defp config do
        RBMQ.Connection.Channel.get_config(@channel_name)
      end

      def handle_call(:status, _from, chan) do
        {:reply, AMQP.Queue.status(chan, config[:queue][:name]), chan}
      end

      @doc """
      This method can be overrided to initialize
      """
      def handle_cast(:init, chan) do
        {:reply, :ok, chan}
      end

      defoverridable [init_worker: 2]
    end
  end

  @doc """
  Create a link to worker process. Used in supervisors.
  """
  @callback start_link :: Supervisor.on_start

  @doc """
  Get queue status.
  """
  @callback status :: {:ok, %{consumer_count: integer,
                              message_count: integer,
                              queue: String.t()}}
                    | {:error, String.t()}
end
