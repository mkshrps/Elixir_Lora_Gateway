

defmodule Lora.UkhasModes do

  @doc """
  From Ukhas pits code defines the lora modes for ukhas transmissions
  {EXPLICIT_MODE, ERROR_CODING_4_8, BANDWIDTH_20K8, SPREADING_11, 8,    60, "Telemetry"},			// 0: Normal mode for telemetry
	{IMPLICIT_MODE, ERROR_CODING_4_5, BANDWIDTH_20K8, SPREADING_6,  0,  1400, "SSDV"},				// 1: Normal mode for SSDV
	{EXPLICIT_MODE, ERROR_CODING_4_8, BANDWIDTH_62K5, SPREADING_8,  0,  2000, "Repeater"},			// 2: Normal mode for repeater network
	{EXPLICIT_MODE, ERROR_CODING_4_6, BANDWIDTH_250K, SPREADING_7,  0,  8000, "Turbo"},				// 3: Normal mode for high speed images in 868MHz band
	{IMPLICIT_MODE, ERROR_CODING_4_5, BANDWIDTH_250K, SPREADING_6,  0, 16828, "TurboX"},			// Fastest mode within IR2030 in 868MHz band
	{EXPLICIT_MODE, ERROR_CODING_4_8, BANDWIDTH_41K7, SPREADING_11, 0,   200, "Calling"},			// Calling mode
	{IMPLICIT_MODE, ERROR_CODING_4_5, BANDWIDTH_41K7, SPREADING_6,  0,  2800, "Uplink"},			// Uplink mode for 868
	{EXPLICIT_MODE, ERROR_CODING_4_5, BANDWIDTH_20K8, SPREADING_7,  0,  2800, "Telnet"},			// 7: Telnet-style comms with HAB on 434
	{IMPLICIT_MODE, ERROR_CODING_4_5, BANDWIDTH_62K5, SPREADING_6,  0,  4500, "SSDV Repeater"},		// 8: SSDV Repeater Network
"""

  def ukhas_mode(0), do: [sf: 11, bw: 20.8E3, ec: 8, explicit: true, payload: nil, ldo: 8]
  def ukhas_mode(1), do: [sf: 6, bw: 20.8E3, ec: 5, explicit: false, payload: 255,ldo: 0]
  def ukhas_mode(2), do: [sf: 8, bw: 62.58E3,ec: 8, explicit: true, payload: nil,ldo: 0]
  def ukhas_mode(3), do: [sf: 7, bw: 250.0E3,ec: 6, explicit: true, payload: nil,ldo: 0]
  def ukhas_mode(4), do: [sf: 6, bw: 250.0E3,ec: 5, explicit: false, payload: 255,ldo: 0]
  def ukhas_mode(5), do: [sf: 11, bw: 41.7E3,ec: 8, explicit: true, payload: nil,ldo: 0]
  def ukhas_mode(6), do: [sf: 6, bw: 250.0E3,ec: 5, explicit: false, payload: 255,ldo: 0]
  def ukhas_mode(7), do: [sf: 7, bw: 20.8E3,ec: 5, explicit: true, payload: nil,ldo: 0]
  def ukhas_mode(8), do: [sf: 6, bw: 62.5E3,ec: 5, explicit: false, payload: 255,ldo: 0]

end
