defmodule Lora.AutoTune do
  import Bitwise
  require Logger
  alias Lora.Modem


  def ppm_compensation(frequency, frq_error) do
    (frq_error/(frequency/10.0E6)) * 0.95
    |> round()
  end

  def tune(frequency,frequency_error,_ppm_comp,spi) when (abs(frequency_error) > 300) do
    new_frq = (frequency - frequency_error) |> round
    Logger.info("new frq #{new_frq}")
    Modem.idle(spi)
    Modem.set_frequency(new_frq,spi)
    Modem.receive_continuous_mode(spi)
    #Modem.set_ppm_comp_reg(ppm_comp,spi)
    {:ok,[frequency: new_frq, ppm: 0]}

  end

  def tune(frequency,_frequency_error,_ppm_comp,_spi) do
     {:ok,[frequency: frequency, ppm: 0]}
  end

  # 128 234 13
  def calculate_frq_error([lsb: lsb ,mid: mid , msb: msb],bw_hz) do
    msb1 = msb &&& 0x07

    val = msb1 <<< 8
    val = val + mid
    val = val <<< 8
    val = val + lsb
    val = check_sign(msb, val)

    xtal = get_xtal_const()
    bw = get_bw_const(bw_hz)    # div by 500
    val =  val * xtal
    val = val * (bw)
    round(val)
  end

  def check_sign(msb, val) when msb > 0x07 do
    val - 524288
  end

  def check_sign(_msb, val) do
    val
  end

  def get_bw_const(bw) do

    bw = bw  /  500000.0
    Logger.info("bandwidth - #{bw}")
    bw
  end

  def get_xtal_const() do
    # 2^24
    x = 1 <<< 24
    x /32.0e6
  end

end
