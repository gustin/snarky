defmodule SnarkyTest do
  use ExUnit.Case
  doctest Snarky

  test "greets the world" do
    assert Snarky.hello() == :world
  end
end
