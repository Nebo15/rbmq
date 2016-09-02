defmodule RBMQ.Connection do
  @moduledoc """
  AQMP connection supervisor.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Supervisor
      require Logger
      alias AMQP.Connection
      alias RBMQ.Connection.Helper

      @worker_config Keyword.delete(opts, :otp_app)
      @config RBMQ.Config.get(__MODULE__, opts)

      defp connect(timeout \\ 10_000) do
        case Helper.open_connection(@config) do
          {:ok, conn} ->
            # Get notifications when the connection goes down
            # Process.monitor(conn.pid)
            conn
          {:error, _} ->
            Logger.warn "Trying to restart connection in #{inspect timeout} microseconds"
            # Reconnection loop
            :timer.sleep(timeout)
            connect
        end
      end

      def handle_info({:DOWN, monitor_ref, :process, pid, _reason}) do
        Logger.error "AQMP connection #{inspect pid} went down"
        Process.demonitor(monitor_ref, [:flush])

        conn = [connection: connect(), config: @worker_config]

        # Tell all open channels to update their connections
        __MODULE__
        |> Supervisor.which_children
        |> Enum.filter(fn {_, child, type, _} ->
          is_pid(child) && Process.alive?(child) && type == :worker
        end)
        |> Enum.map(fn {_, child, _, _} ->
          RBMQ.Connection.Channel.reconnect(child, conn)
        end)

        :noreply
      end

      def start_link do
        Supervisor.start_link(__MODULE__, [], name: __MODULE__)
      end

      def spawn_channel(name) do
        Supervisor.start_child(__MODULE__, [name])
      end

      def get_channel(name) do
        RBMQ.Connection.Channel.get(name)
      end

      def configure_channel(name, config) do
        RBMQ.Connection.Channel.set_config(name, config)
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
