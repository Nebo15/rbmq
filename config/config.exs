# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :rbmq, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:rbmq, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# Disable logger if you don't want to see verbose messages
# config :logger, level: :info

# RabbitMQ config
config :rbmq, RBMQ.ConnectionTest.TestConnectionWithExternalConfig,
    host: {:system, "CUST_MQ_HOST", "other_host"},
    port: {:system, "CUST_MQ_PORT", 1234},
    username: {:system, "MQ_USER", "guest"},
    password: {:system, "MQ_PASSWORD", "guest"},
    virtual_host: {:system, "MQ_VHOST", "/"},
    connection_timeout: {:system, "MQ_TIMEOUT", 15_000}

config :rbmq, RBMQ.ProducerTest.TestProducerWithExternalConfig,
  queue: [
    name: {:system, "CUST_QUEUE_NAME"},
  ]
