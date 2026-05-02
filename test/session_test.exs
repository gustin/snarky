defmodule Snarky.SessionTest do
  use ExUnit.Case

  test "initial state has 8 tracks" do
    state = Snarky.Session.get_state()
    assert map_size(state.tracks) == 8
  end

  test "tracks have alias names from config" do
    track = Snarky.Session.get_track(1)
    assert track.name == "guitar"
  end

  test "track_command updates armed state" do
    cmd = %Snarky.CommandRouter.Command{action: :arm, target: {:track, 1}}
    Snarky.Session.track_command(cmd)
    Process.sleep(10)
    track = Snarky.Session.get_track(1)
    assert track.armed == true
  end

  test "track_command updates muted state" do
    cmd = %Snarky.CommandRouter.Command{action: :mute, target: {:track, 3}}
    Snarky.Session.track_command(cmd)
    Process.sleep(10)
    track = Snarky.Session.get_track(3)
    assert track.muted == true
  end

  test "mute all mutes every track" do
    cmd = %Snarky.CommandRouter.Command{action: :mute, target: :all}
    Snarky.Session.track_command(cmd)
    Process.sleep(10)
    state = Snarky.Session.get_state()
    assert Enum.all?(state.tracks, fn {_, t} -> t.muted end)
  end

  test "set_tempo updates tempo" do
    cmd = %Snarky.CommandRouter.Command{action: :set_tempo, params: %{bpm: 140}}
    Snarky.Session.track_command(cmd)
    Process.sleep(10)
    state = Snarky.Session.get_state()
    assert state.tempo == 140
  end

  test "add_effect appends to track effects" do
    cmd = %Snarky.CommandRouter.Command{
      action: :add_effect,
      target: {:track, 1},
      params: %{effect: :reverb}
    }

    Snarky.Session.track_command(cmd)
    Process.sleep(10)
    track = Snarky.Session.get_track(1)
    assert :reverb in track.effects
  end

  test "describe returns session summary string" do
    desc = Snarky.Session.describe()
    assert is_binary(desc)
    assert desc =~ "BPM"
  end
end
