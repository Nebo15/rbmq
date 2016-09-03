defmodule RBMQ.Connection.Guard do
  @moduledoc """
  Guard of connections. Notifies supervisor when it needs to restart connection and notify channels.
  """
  use GenServer
  require Logger

  def start_link(mod, name) do
    GenServer.start_link(__MODULE__, mod, name: name)
  end

  def init(mod) do
    {:ok, mod}
  end

  def monitor(guard_pid, pid) do
    GenServer.cast(guard_pid, {:monitor, pid})
  end

  @doc false
  def handle_cast({:monitor, pid}, mod) do
    Process.monitor(pid)
    {:noreply, mod}
  end

  @doc false
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, mod) do
    Logger.error "AMQP connection #{inspect mod} went down"

    # Stop minitoring dead connection
    Process.demonitor(monitor_ref, [:flush])

    # Establish new connection
    conn = apply(mod, :connect, [])

    # Update all childs
    mod
    |> Supervisor.which_children()
    |> Enum.filter(fn {_, child, type, _} ->
      is_pid(child) && Process.alive?(child) && type == :worker
    end)
    |> Enum.map(fn {_, child, _, _} ->
      RBMQ.Connection.Channel.reconnect(child, conn)
    end)

    # apply(mod, :update_connection, [childs])

    {:noreply, mod}
  end
end
