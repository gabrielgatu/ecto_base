defmodule EctoBaseTest do
  use ExUnit.Case
  doctest EctoBase

  test "greets the world" do
    assert EctoBase.hello() == :world
  end
end
