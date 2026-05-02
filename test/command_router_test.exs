defmodule Snarky.CommandRouterTest do
  use ExUnit.Case
  alias Snarky.CommandRouter
  alias Snarky.CommandRouter.Command

  describe "transport commands" do
    test "record" do
      assert {:command, %Command{action: :record}} = CommandRouter.parse("record")
    end

    test "record track 8" do
      assert {:command, %Command{action: :record, target: {:track, 8}}} =
               CommandRouter.parse("record track 8")
    end

    test "stop" do
      assert {:command, %Command{action: :stop}} = CommandRouter.parse("stop")
    end

    test "play" do
      assert {:command, %Command{action: :play}} = CommandRouter.parse("play")
    end

    test "play it back" do
      assert {:command, %Command{action: :play}} = CommandRouter.parse("play it back")
    end

    test "pause" do
      assert {:command, %Command{action: :pause}} = CommandRouter.parse("pause")
    end

    test "rewind" do
      assert {:command, %Command{action: :rewind}} = CommandRouter.parse("rewind")
    end

    test "undo" do
      assert {:command, %Command{action: :undo}} = CommandRouter.parse("undo")
    end

    test "redo" do
      assert {:command, %Command{action: :redo}} = CommandRouter.parse("redo")
    end
  end

  describe "mix commands" do
    test "mute track 3" do
      assert {:command, %Command{action: :mute, target: {:track, 3}}} =
               CommandRouter.parse("mute track 3")
    end

    test "mute all" do
      assert {:command, %Command{action: :mute, target: :all}} =
               CommandRouter.parse("mute all")
    end

    test "mute everything" do
      assert {:command, %Command{action: :mute, target: :all}} =
               CommandRouter.parse("mute everything")
    end

    test "unmute track 5" do
      assert {:command, %Command{action: :unmute, target: {:track, 5}}} =
               CommandRouter.parse("unmute track 5")
    end

    test "solo track 2" do
      assert {:command, %Command{action: :solo, target: {:track, 2}}} =
               CommandRouter.parse("solo track 2")
    end

    test "arm track 1" do
      assert {:command, %Command{action: :arm, target: {:track, 1}}} =
               CommandRouter.parse("arm track 1")
    end

    test "disarm track 4" do
      assert {:command, %Command{action: :disarm, target: {:track, 4}}} =
               CommandRouter.parse("disarm track 4")
    end
  end

  describe "volume commands" do
    test "volume up track 3" do
      assert {:command, %Command{action: :volume_up, target: {:track, 3}}} =
               CommandRouter.parse("volume up track 3")
    end

    test "volume down track 5" do
      assert {:command, %Command{action: :volume_down, target: {:track, 5}}} =
               CommandRouter.parse("volume down track 5")
    end
  end

  describe "pan commands" do
    test "pan track 1 left" do
      assert {:command, %Command{action: :pan, target: {:track, 1}, params: %{direction: :left}}} =
               CommandRouter.parse("pan track 1 left")
    end

    test "pan track 2 right" do
      assert {:command, %Command{action: :pan, target: {:track, 2}, params: %{direction: :right}}} =
               CommandRouter.parse("pan track 2 right")
    end
  end

  describe "loop commands" do
    test "loop bar 12 to bar 20" do
      assert {:command, %Command{action: :loop, params: %{from: 12, to: 20}}} =
               CommandRouter.parse("loop bar 12 to bar 20")
    end

    test "loop from 4 to 8" do
      assert {:command, %Command{action: :loop, params: %{from: 4, to: 8}}} =
               CommandRouter.parse("loop from 4 to 8")
    end

    test "bare loop" do
      assert {:command, %Command{action: :loop}} = CommandRouter.parse("loop")
    end
  end

  describe "tempo commands" do
    test "set tempo to 120" do
      assert {:command, %Command{action: :set_tempo, params: %{bpm: 120}}} =
               CommandRouter.parse("set tempo to 120")
    end

    test "tempo 85" do
      assert {:command, %Command{action: :set_tempo, params: %{bpm: 85}}} =
               CommandRouter.parse("tempo 85")
    end
  end

  describe "effect commands" do
    test "add reverb to track 3" do
      assert {:command,
              %Command{action: :add_effect, target: {:track, 3}, params: %{effect: :reverb}}} =
               CommandRouter.parse("add reverb to track 3")
    end

    test "add plate reverb to track 1" do
      assert {:command,
              %Command{action: :add_effect, target: {:track, 1}, params: %{effect: :plate_reverb}}} =
               CommandRouter.parse("add plate reverb to track 1")
    end

    test "put some compression on track 5" do
      assert {:command,
              %Command{action: :add_effect, target: {:track, 5}, params: %{effect: :compressor}}} =
               CommandRouter.parse("put some compression on track 5")
    end

    test "remove delay from track 2" do
      assert {:command,
              %Command{action: :remove_effect, target: {:track, 2}, params: %{effect: :delay}}} =
               CommandRouter.parse("remove delay from track 2")
    end
  end

  describe "session commands" do
    test "save" do
      assert {:command, %Command{action: :save}} = CommandRouter.parse("save")
    end

    test "bounce" do
      assert {:command, %Command{action: :bounce}} = CommandRouter.parse("bounce")
    end

    test "export" do
      assert {:command, %Command{action: :export}} = CommandRouter.parse("export")
    end
  end

  describe "question routing" do
    test "why question" do
      assert {:question, _} = CommandRouter.parse("why does the bass sound muddy")
    end

    test "how question" do
      assert {:question, _} = CommandRouter.parse("how do i get more clarity on the guitar")
    end

    test "what question" do
      assert {:question, _} = CommandRouter.parse("what frequency is clashing")
    end

    test "question mark" do
      assert {:question, _} = CommandRouter.parse("is the snare too loud?")
    end
  end

  describe "track aliases" do
    test "mute the guitar" do
      assert {:command, %Command{action: :mute, target: {:track, 1}}} =
               CommandRouter.parse("mute the guitar")
    end

    test "solo the bass" do
      assert {:command, %Command{action: :solo, target: {:track, 2}}} =
               CommandRouter.parse("solo the bass")
    end

    test "arm drums" do
      assert {:command, %Command{action: :arm, target: {:track, 5}}} =
               CommandRouter.parse("arm drums")
    end
  end

  describe "ignored input" do
    test "random noise" do
      assert :ignored = CommandRouter.parse("uh yeah so anyway")
    end

    test "empty string" do
      assert :ignored = CommandRouter.parse("")
    end
  end
end
