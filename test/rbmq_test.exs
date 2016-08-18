defmodule RbmqTest do
  use ExUnit.Case
  doctest Rbmq

  test "the truth" do
    {:ok, p} = MQ.Producer.start_link
    {:ok, c} = MQ.Consumer.start_link

     MQ.Producer.publish(p, "os_decision_queue", 1)
     MQ.Producer.publish(p, "os_decision_queue", 2)
     MQ.Producer.publish(p, "os_decision_queue", 6)
     MQ.Producer.publish(p, "os_decision_queue", 12)
     MQ.Producer.publish(p, "os_decision_engine_exchange", "5")
     MQ.Producer.publish(p, "os_decision_engine_exchange", "test")

       MQ.Consumer.get(c)
  end
end
