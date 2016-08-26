use Mix.Config

config :rbmq, amqp_exchange: "rbmq_exchange"

config :rbmq, prefetch_count: "10"

config :rbmq, amqp_params: [
  host: "localhost",
  port: "5672",
  username: "guest",
  password: "guest",
]
