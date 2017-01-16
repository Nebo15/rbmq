defmodule RBMQ.Connection do
  @moduledoc """
  AMQP connection supervisor.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Supervisor
      use Confex, opts
      require Logger
      alias AMQP.Connection
      alias RBMQ.Connection.Helper

      @guard_name String.to_atom("#{__MODULE__}.Guard")
      @worker_config Keyword.delete(opts, :otp_app)
      @inline_options opts

      def connect(timeout \\ 10_000) do
        case Helper.open_connection(config()) do
          {:ok, conn} ->
            # Get notifications when the connection goes down
            RBMQ.Connection.Guard.monitor(@guard_name, conn.pid)
            conn
          {:error, _} ->
            Logger.warn "Trying to restart connection in #{inspect timeout} microseconds"
            # Reconnection loop
            :timer.sleep(timeout)
            connect()
        end
      end

      def close do
        Process.exit(@guard_name, :normal)
        Supervisor.stop(__MODULE__)
      end

      def start_link do
        RBMQ.Connection.Guard.start_link(__MODULE__, @guard_name)
        Supervisor.start_link(__MODULE__, [], name: __MODULE__)
      end

      def spawn_channel(name) do
        Supervisor.start_child(__MODULE__, [name])
      end

      def get_channel(name) do
        RBMQ.Connection.Channel.get(name)
      end

      def configure_channel(name, conf) do
        RBMQ.Connection.Channel.set_config(name, conf)
      end

      def close_channel(name) do
        pid = Process.whereis(name)
        :ok = RBMQ.Connection.Channel.close(pid)
        Supervisor.terminate_child(__MODULE__, pid)
      end

      def init(_conf) do
        conf = [connection: connect(), config: @worker_config]

        children = [
          worker(RBMQ.Connection.Channel, [conf], restart: :transient)
        ]

        supervise(children, strategy: :simple_one_for_one)
      end
    end
  end
end
