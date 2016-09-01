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

# defmodule AP.BatchQueueProducer do

#   use RBMQ.NewProducer, [
#     otp_app: :ap,
#     queue: [
#       name: "decision_queue",
#       error_name: "decision_queue_errors",
#       routing_key: "decision_queue"
#     ],
#     exchange: [
#       name: "queue_exchange",
#       type: :direct,
#       durable: true
#     ]
#   ]

#   def cast_publish() do

#   end

#   def call_publush() do

#   end
# end

# defmodule RBMQ.Producer do
#   @type t :: module

#   @doc false
#   defmacro __using__(opts) do
#     quote bind_quoted: [opts: opts] do
#       import RBMQ.Connector

#       @config RBMQ.Config.get(__MODULE__, opts)

#       cond do
#         !Keyword.has_key?(@config, :queue) ->
#           raise "queue config is not set in #{inspect __MODULE__}"
#         !Keyword.has_key?(@config[:queue], :name) ->
#           raise "queue name is not set in #{inspect __MODULE__}"
#         !Keyword.has_key?(@config, :exchange) ->
#           raise "exchange config is not set in #{inspect __MODULE__}"
#         !Keyword.has_key?(@config[:exchange], :name) ->
#           raise "exchange name is not set in #{inspect __MODULE__}"
#         !Keyword.has_key?(@config[:exchange], :name) ->
#           raise "exchange name is not set in #{inspect __MODULE__}"
#       end

#       def config do
#         @config
#       end

#       defp conn do
#         config
#         |> open_connection!
#         |> open_channel!

#       end

#       # def start_link(repo, otp_app, adapter, opts) do
#       #   opts = config(repo, otp_app, opts)
#       #   name = opts[:name] || Application.get_env(otp_app, repo)[:name] || repo
#       #   Supervisor.start_link(__MODULE__, {repo, otp_app, adapter, opts}, [name: name])
#       # end

#       # def start_link(opts \\ []) do
#       #   Ecto.Repo.Supervisor.start_link(__MODULE__, @otp_app, @adapter, opts)
#       # end

#       # def stop(pid, timeout \\ 5000) do
#       #   Supervisor.stop(pid, :normal, timeout)
#       # end
#     end
#   end
# end

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
#   def init({chan, config}) do
#     chan = chan
#     |> declare_queue(config[:queue][:name], config[:queue][:error_name], config[:queue])
#     |> declare_exchange(config[:exchange][:name], config[:exchange][:type], config[:exchange])
#     |> bind_queue(config[:queue][:name], config[:exchange][:name], [routing_key: config[:queue][:routing_key] || ""])

#     {:ok, chan}
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

# # {queue, exchange, prefetch_count}

# # {:ok, conn} = Connection.open(get_amqp_params)
# #     {:ok, chan} = Channel.open(conn)

# #     Queue.declare(chan, queue_err, durable: true)
# #     Queue.declare(chan, queue, durable: true, arguments: [
# #       {"x-dead-letter-exchange", :longstr, ""},
# #       {"x-dead-letter-routing-key", :longstr, queue_err}
# #     ])
# #     Exchange.direct(chan, exchange, durable: true)
# #     Queue.bind(chan, queue, exchange, [routing_key: queue])
# #     AMQP.Confirm.select(chan)

# #     {:ok, {chan, [exchange: exchange]}}
