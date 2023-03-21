defmodule Lora.UkhasModes do

  def ukhas_mode(0), do: [sf: 11, bw: 20.8E3, ec: 8, explicit: true, payload: nil]
  def ukhas_mode(1), do: [sf: 6, bw: 20.8E3, ec: 5, explicit: false, payload: 255]
  def ukhas_mode(2), do: [sf: 8, bw: 62.58E3,ec: 8, explicit: true, payload: nil]

end
