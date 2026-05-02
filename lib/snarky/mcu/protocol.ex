defmodule Snarky.MCU.Protocol do
  @moduledoc false

  # Transport
  def rewind, do: 0x5B
  def forward, do: 0x5C
  def stop, do: 0x5D
  def play, do: 0x5E
  def record, do: 0x5F

  # Per-channel buttons (add channel offset 0-7)
  def rec(ch), do: 0x00 + ch
  def solo(ch), do: 0x08 + ch
  def mute(ch), do: 0x10 + ch
  def select(ch), do: 0x18 + ch
  def vpot_click(ch), do: 0x20 + ch
  def fader_touch(ch), do: 0x68 + ch

  # VPot rotation CC numbers
  def vpot_cc(ch), do: 0x10 + ch

  # VPot rotation values
  def clockwise, do: 0x01
  def counter_clockwise, do: 0x41

  # Navigation
  def bank_left, do: 0x2E
  def bank_right, do: 0x2F
  def channel_left, do: 0x30
  def channel_right, do: 0x31
  def cursor_up, do: 0x60
  def cursor_down, do: 0x61
  def cursor_left, do: 0x62
  def cursor_right, do: 0x63
  def zoom, do: 0x64
  def scrub, do: 0x65

  # Jog wheel CC
  def jog_wheel_cc, do: 0x3C

  # Assignment
  def assign_track, do: 0x28
  def assign_send, do: 0x29
  def assign_pan, do: 0x2A
  def assign_plugin, do: 0x2B
  def assign_eq, do: 0x2C
  def assign_instrument, do: 0x2D

  # Function buttons
  def f1, do: 0x36
  def f2, do: 0x37
  def f3, do: 0x38
  def f4, do: 0x39
  def f5, do: 0x3A
  def f6, do: 0x3B
  def f7, do: 0x3C
  def f8, do: 0x3D

  # Modifiers
  def shift, do: 0x46
  def option, do: 0x47
  def control, do: 0x48
  def alt, do: 0x49

  # Session
  def save, do: 0x50
  def undo, do: 0x51
  def cancel, do: 0x52
  def enter, do: 0x53

  # Markers / Cycle
  def markers, do: 0x54
  def nudge, do: 0x55
  def cycle, do: 0x56
  def drop, do: 0x57
  def replace, do: 0x58
  def click, do: 0x59
  def solo_global, do: 0x5A

  # Note bang: press then release
  def bang(note) do
    [{:note, note, 127}, {:note, note, 0}]
  end

  # Fader: 14-bit pitch bend value (0-16383)
  # Approximate dB mapping for Logic Pro
  def db_to_fader(db) when db <= -70, do: 0
  def db_to_fader(db) when db >= 10, do: 16383

  def db_to_fader(db) do
    round((db + 70) / 80.0 * 16383)
  end

  def fader_to_db(value) when value <= 0, do: -70.0
  def fader_to_db(value) when value >= 16383, do: 10.0

  def fader_to_db(value) do
    Float.round(value / 16383.0 * 80.0 - 70.0, 1)
  end
end
