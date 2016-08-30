defmodule Rbmq.SupervisorConsumer do
  @moduledoc """
  Supervisor for RabbitMQ Consumers.
  """
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :consumer_supervisor)
  end

  def spawn_consumer(name, queue, callback, exchange \\ nil) do
    Supervisor.start_child(:consumer_supervisor, [name, queue, callback, exchange])
  end

  def init(_) do
    children = [
      worker(Rbmq.Consumer, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end

defmodule RBMQ.NewProducer do
  @type t :: module

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use AMQP

      otp_app = RBMQ.Config.get_otp_app(opts)
      config = RBMQ.Config.get(__MODULE__, otp_app)

      @otp_app otp_app
      @config config
      @conn Connection.open(@config)

      def config do
        RBMQ.Config.get(__MODULE__, @otp_app)
      end

      def start_link(repo, otp_app, adapter, opts) do
        opts = config(repo, otp_app, opts)
        name = opts[:name] || Application.get_env(otp_app, repo)[:name] || repo
        Supervisor.start_link(__MODULE__, {repo, otp_app, adapter, opts}, [name: name])
      end

      def start_link(opts \\ []) do
        Ecto.Repo.Supervisor.start_link(__MODULE__, @otp_app, @adapter, opts)
      end

      def stop(pid, timeout \\ 5000) do
        Supervisor.stop(pid, :normal, timeout)
      end
    end
  end
end

# defmodule RBMQ.Producer.Supervisor do
#   @moduledoc false
#   use Supervisor

#   @doc false
#   def start_link(name, conn) do
#     Supervisor.start_link(__MODULE__, [conn: conn], name: name)
#   end

#   @doc false
#   def spawn_consumer(name, queue, exchange callback) do
#     Supervisor.start_child(name, [name, queue, callback, exchange])
#   end

#   @doc false
#   def init(opts) do
#     children = [
#       worker(RBMQ.Consumer.Worker, opts, restart: :transient)
#     ]

#     supervise(children, strategy: :simple_one_for_one)
#   end
# end

# defmodule RBMQ.Producer.Worker do
#   @moduledoc """
#   GenServer for AQMP workers.
#   """

#   use GenServer
#   use AMQP
#   import RBMQ.Connector

#   @doc false
#   def init({conn, {queue, error_queue, queue_opts}, exchange}) do
#     Channel.open(conn)
#     |> declare_queue(queue, error_queue, queue_opts)
#     |>

#     Exchange.direct(chan, exchange, durable: true)
#   end

#   def start_link(state, opts \\ []) do
#     GenServer.start_link(__MODULE__, state, opts)
#   end

#   def handle_call(:pop, _from, [h | t]) do
#     {:reply, h, t}
#   end

#   def handle_cast({:push, h}, t) do
#     {:noreply, [h | t]}
#   end
# end

# {queue, exchange, prefetch_count}

# {:ok, conn} = Connection.open(get_amqp_params)
#     {:ok, chan} = Channel.open(conn)

#     Queue.declare(chan, queue_err, durable: true)
#     Queue.declare(chan, queue, durable: true, arguments: [
#       {"x-dead-letter-exchange", :longstr, ""},
#       {"x-dead-letter-routing-key", :longstr, queue_err}
#     ])
#     Exchange.direct(chan, exchange, durable: true)
#     Queue.bind(chan, queue, exchange, [routing_key: queue])
#     AMQP.Confirm.select(chan)

#     {:ok, {chan, [exchange: exchange]}}
