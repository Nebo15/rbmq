defmodule RBMQ.Connector do
  use AMQP
  require Logger

  @doc """
  Open AQMP connection.

  # Options
    * `:username` - The name of a user registered with the broker (defaults to \"guest\");
    * `:password` - The password of user (defaults to \"guest\");
    * `:virtual_host` - The name of a virtual host in the broker (defaults to \"/\");
    * `:host` - The hostname of the broker (defaults to \"localhost\");
    * `:port` - The port the broker is listening on (defaults to `5672`);
    * `:channel_max` - The channel_max handshake parameter (defaults to `0`);
    * `:frame_max` - The frame_max handshake parameter (defaults to `0`);
    * `:heartbeat` - The hearbeat interval in seconds (defaults to `0` - turned off);
    * `:connection_timeout` - The connection timeout in milliseconds (defaults to `15_000`);
    * `:ssl_options` - Enable SSL by setting the location to cert files (defaults to `none`);
    * `:client_properties` - A list of extra client properties to be sent to the server, defaults to `[]`;
    * `:socket_options` - Extra socket options. These are appended to the default options. \
                          See http://www.erlang.org/doc/man/inet.html#setopts-2 \
                          and http://www.erlang.org/doc/man/gen_tcp.html#connect-4 \
                          for descriptions of the available options.

  See: https://hexdocs.pm/amqp/AMQP.Connection.html#open/1
  """
  def open_connection!(conn_opts) do
    case open_connection(conn_opts) do
      {:ok, %Connection{} = conn} ->
        conn
      {:error, message} ->
        raise message
    end
  end

  @doc """
  Same as `open_connection!/1`, but returns {:ok, conn} or {:error, reason} tuples.
  """
  def open_connection(conn_opts) do
    Logger.debug "Establishing new AQMP connection, with opts: #{inspect conn_opts}"
    case Connection.open(conn_opts) do
      {:ok, %Connection{}} = res ->
        res
      {:error, :econnrefused} ->
        Logger.error "AQMP refused connection, opts: #{inspect conn_opts}"
        {:error, "AQMP connection was refused"}
      {:error, :timeout} ->
        Logger.error "AQMP connection timeout, opts: #{inspect conn_opts}"
        {:error, "AQMP connection timeout"}
      {:error, {:auth_failure, message}} ->
        Logger.error "AQMP authorization failed, opts: #{inspect conn_opts}"
        {:error, "AQMP authorization failed: #{inspect message}"}
      {:error, reason} ->
        Logger.error "Error during AQMP connection establishing, opts: #{inspect conn_opts}"
        {:error, "#{inspect reason}"}
    end
  end

  @doc """
  Open new AQMP channel inside a connection.

  See: https://hexdocs.pm/amqp/AMQP.Channel.html#open/1
  """
  def open_channel!(%Connection{} = conn) do
    Logger.debug "Opening new AQMP channel"
    case Channel.open(conn) do
      {:ok, chan} ->
        chan
      {:error, reason} ->
        Logger.error "Can't create new AQMP channel"
        raise reason
    end
  end

  @doc """
  Set channel QOS policy. Especially useful when you want to limit number of
  unacknowledged request per worker.

  # Options
    * `:prefetch_size` - Limit of unacknowledged messages (in bytes).
    * `:prefetch_count` - Limit of unacknowledged messages (count).
    * `:global` - If `global` is set to `true` this applies to the \
                  entire Connection, otherwise it applies only to the specified Channel.

  See: https://hexdocs.pm/amqp/AMQP.Basic.html#qos/2
  """
  def set_channel_qos(%Channel{} = chan, opts) do
    Logger.debug "Changing channel QOS to #{inspect opts}"
    Basic.qos(chan, opts)

    chan
  end

  @doc """
  Declare AQMP queue. You can omit `error_queue`, then dead letter queue won't be created.
  Dead letter queue is hardcoded to be durable.

  # Options
    * `:durable` - If set, keeps the Queue between restarts of the broker
    * `:auto-delete` - If set, deletes the Queue once all subscribers disconnect
    * `:exclusive` - If set, only one subscriber can consume from the Queue
    * `:passive` - If set, raises an error unless the queue already exists

  See: https://hexdocs.pm/amqp/AMQP.Queue.html#declare/3
  """
  def declare_queue(%Channel{} = chan, queue, error_queue, opts) when is_binary(error_queue) do
    Logger.debug "Declaring new queue '#{queue}' with dead letter queue '#{error_queue}'. Options: #{inspect opts}"

    opts = Keyword.merge([
      arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, error_queue}
      ]
    ], opts)

    Queue.declare(chan, error_queue, durable: true)
    Queue.declare(chan, queue, opts)

    chan
  end

  def declare_queue(%Channel{} = chan, queue, _, opts) do
    Logger.debug "Declaring new queue '#{queue}' without dead letter queue. Options: #{inspect opts}"
    Queue.declare(chan, queue, opts)

    chan
  end

  @doc """
  Declare AQMP exchange. Exchange is durable whenever queue is durable.

  # Types:
    *   `:direct` - direct exchange.
    *   `:fanout` - fanout exchange.
    *   `:topic` - topic exchange.
    *   `:headers` - headers exchange.

  See: https://hexdocs.pm/amqp/AMQP.Queue.html#declare/3
  """
  def declare_exchange(%Channel{} = chan, exchange, type \\ :direct, opts \\ []) do
    Logger.debug "Declaring new exchange '#{exchange}' of type '#{inspect type}'. Options: #{inspect opts}"
    Exchange.declare(chan, exchange, type, opts)

    chan
  end

  @doc """
  Bind AQMP queue to Exchange.

  See: https://hexdocs.pm/amqp/AMQP.Queue.html#bind/4
  """
  def bind_queue(%Channel{} = chan, queue, exchange, opts) do
    Logger.debug "Binding new queue '#{queue}' to exchange '#{exchange}'. Options: #{inspect opts}"
    Queue.bind(chan, queue, exchange, opts)

    chan
  end
end
