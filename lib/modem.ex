defmodule Lora.Modem do
  import Bitwise
  require Logger

  #alias ElixirALE.GPIO
  alias Circuits.GPIO
  alias Lora.Communicator
  alias Lora.Parameters
  alias Lora.Bits

  # def transmitting?(spi) do
  #   irq_flags = Communicator.read_register(spi, Parameters.register.irq_flags)

  #   unless (irq_flags &&& Parameters.irq.tx_done_mask) == 0,
  #     do: Communicator.write_register(spi, Parameters.register.irq_flags, Parameters.irq.tx_done_mask)

  #   if (Communicator.read_register(spi, Parameters.register.op_mode) &&& Parameters.mode.tx) == Parameters.mode.tx, do: true, else: false
  # end

  def begin(spi, frequency, lora_config, power \\ 17) do
    # Sleep mode
    Logger.debug(lora_config)
    Logger.debug("Power #{power}")
    sleep(spi)
    # reset ppm compensation
    # Set frequency
    set_frequency(frequency,spi)
    set_base_address(spi)
    # Set LNA boost
    set_LNA_boost(spi)
    # Set auto AGC
    set_auto_AGC(spi)
    # Set output power to 17 dBm
    set_tx_power(power,spi)

    set_coding_rate(spi,lora_config[:ec])
    set_bandwidth(spi,lora_config[:bw])
    set_spreading_factor(spi,lora_config[:sf])
    set_base_address(spi)
    #map_dio_5()
    # enable rxdone interrupt
    # default mode is receiver
    map_dio_0(:rx_done,spi)
    # start receiver
    receive_continuous_mode(spi)
  end

  def dio_5(:done) do
    # just return
    :ok
  end

  def dio_5() do
    # scan till DIO_5 complete
  end

  def map_dio_0(:rx_done,spi) do
    Communicator.write_register(spi,
    Parameters.register().dio_mapping_1,
    Parameters.irq_dio().rxdone)
  end

  def map_dio_0(:tx_done,spi) do
    Communicator.write_register(spi,
    Parameters.register().dio_mapping_1,
    Parameters.irq_dio().txdone)
  end

  # this is set to mode ready on reset so never really need it
  def map_dio_5(spi) do
    diomap = Communicator.read_register(spi,
      Parameters.register().dio_mapping_2)

    diomap = diomap ||| Parameters.irq_dio5

    Communicator.write_register(spi,
      Parameters.register().dio_mapping_2,
      diomap)
  end

  def enable_receiver_interrupts(spi) do
    # arm the rxtimeout, rxdone, crcerror interrupts
    Communicator.write_register(spi, Parameters.register().irq_flags, 0x70)
  end

 def sleep(spi) do
    Communicator.write_register(
      spi,
      Parameters.register().op_mode,
      Parameters.mode().long_range_mode ||| Parameters.mode().sleep
    )
  #  :timer.sleep(10)
  end

  def idle(spi) do
    Communicator.write_register(
      spi,
      Parameters.register().op_mode,
      Parameters.mode().long_range_mode ||| Parameters.mode().stdby
    )
  #  :timer.sleep(10)
  end

  def receive_continuous_mode(spi) do
     Communicator.write_register(
      spi,
      Parameters.register().op_mode,
      Parameters.mode().long_range_mode ||| Parameters.mode().rx_continuous
    )
  #  :timer.sleep(10)
  end

  def receive_single_mode(spi) do
      Communicator.write_register(
      spi,
      Parameters.register().op_mode,
      Parameters.mode().long_range_mode ||| Parameters.mode().rx_single
    )
    :timer.sleep(10)
  end

  def read_frq_error(spi) do
    msb = Communicator.read_register(spi, Parameters.register().freq_error_msb)
    mid = Communicator.read_register(spi, Parameters.register().freq_error_mid)
    lsb = Communicator.read_register(spi, Parameters.register().freq_error_lsb)
    [lsb: lsb, mid: mid, msb: msb]
  end

  @doc """
    API
    read a payload from lora device
  """
  def read_payload(spi,payload_len) do
    # initialise the ptr reg to the start of the received data
    currentAddr = Communicator.read_register(spi,Parameters.register().fifo_rx_current_addr)
    Communicator.write_register(spi,Parameters.register().fifo_addr_ptr,currentAddr)
    read_payload_message(spi,[],payload_len)
  end

  defp read_payload_message(_spi,payload,0) do
    Enum.reverse(payload)
  end

  defp read_payload_message(spi,payload,byte_count) do
    read_payload_message( spi,[read_payload_byte(spi)|payload], byte_count-1)
  end

  defp read_payload_byte(spi) do
    Communicator.read_register(spi, Parameters.register().fifo)
  end


  def snr(spi), do: Communicator.read_register(spi, Parameters.register().pkt_snr_value) * 0.25

  def rssi(spi,frequency) do
    rssi_value = Communicator.read_register(spi, Parameters.register().pkt_rssi_value)
    rssi_value - if frequency < 868.0e6, do: 164, else: 157
  end

  def irq_flags(spi) do
    Communicator.read_register(spi, Parameters.register().irq_flags)
  end

  def irq_mask(spi) do
    Communicator.read_register(spi, Parameters.register().irq_mask)
  end

  def set_fifo_current_addr(spi) do
    current_addr = Communicator.read_register(spi, Parameters.register().fifo_rx_current_addr)
    Communicator.write_register(spi, Parameters.register().fifo_addr_ptr, current_addr)
    #idle(spi)
  end

  def reset(rst) do
    GPIO.write(rst, 1)
    :timer.sleep(20)
    GPIO.write(rst, 0)
    :timer.sleep(20)
    GPIO.write(rst, 1)
    :timer.sleep(10)
  end

  def tx_done_flag(spi) do
    Communicator.write_register(
      spi,
      Parameters.register().irq_flags,
      Parameters.irq().tx_done_mask
    )
  end

  def reset_fifo_payload(spi) do
    # Reset FIFO address and payload length
    Communicator.write_register(spi, Parameters.register().fifo_addr_ptr, 0)
    Communicator.write_register(spi, Parameters.register().payload_length, 128)
  end

  def set_frequency(freq,spi) do
    frt = trunc((trunc(freq) <<< 19) / 32_000_000)
    Communicator.write_register(spi, Parameters.register().frf_msb, frt >>> 16)
    Communicator.write_register(spi, Parameters.register().frf_mid, frt >>> 8)
    Communicator.write_register(spi, Parameters.register().frf_lsb, frt >>> 0)
    #set_ppm_comp_reg(0,spi)
  end

  def set_ppm_comp_reg(ppm_comp,spi) do
    Communicator.write_register(spi,
    Parameters.register().ppm_compensation,
    ppm_comp)
  end

  # def set_tx_power(spi, level, output_pin) when output_pin == Parameters.pa.output_rfo_pin do
  #   cond do
  #     level < 0 -> Communicator.write_register(spi, Parameters.register.pa_config, 0x70 ||| 0)
  #     level > 14 -> Communicator.write_register(spi, Parameters.register.pa_config, 0x70 ||| 14)
  #     level >= 0 -> Communicator.write_register(spi, Parameters.register.pa_config, 0x70 ||| level)
  #   end
  # end

  def set_tx_power(level,spi) do
    if level > 17 do
      Communicator.write_register(spi, Parameters.register().pa_dac, 0x87)
      set_ocp(140, spi)

      if level > 20,
        do:
          Communicator.write_register(
            spi,
            Parameters.register().pa_config,
            Parameters.pa().boost ||| 15
          ),
        else:
          Communicator.write_register(
            spi,
            Parameters.register().pa_config,
            Parameters.pa().boost ||| level - 5
          )
    else
      Communicator.write_register(spi, Parameters.register().pa_dac, 0x84)
      set_ocp(100, spi)

      if level < 2,
        do:
          Communicator.write_register(
            spi,
            Parameters.register().pa_config,
            Parameters.pa().boost ||| 0
          ),
        else:
          Communicator.write_register(
            spi,
            Parameters.register().pa_config,
            Parameters.pa().boost ||| level - 2
          )
    end
  end

  # oveerload currrent protection
  def set_ocp(ocp,spi) do
    cond do
      ocp <= 120 ->
        Communicator.write_register(
          spi,
          Parameters.register().ocp,
          0x20 ||| (0x1F &&& uint8((uint8(ocp) - 45) / 5))
        )

      ocp <= 240 ->
        Communicator.write_register(
          spi,
          Parameters.register().ocp,
          0x20 ||| (0x1F &&& uint8((uint8(ocp) + 30) / 10))
        )

      ocp > 240 ->
        Communicator.write_register(spi, Parameters.register().ocp, 0x20 ||| (0x1F &&& 27))
    end
  end

  def set_ldo_flag(spi) do
    spf = get_spreading_factor(spi)
    bw = get_signal_band_width(spi)
    if spf == 6 do
      write_ldo(spi,0)
    else
      unless bw == nil do
        symbol_duration = 1000 / (bw / (1 <<< spf))

        ldo_on = if symbol_duration > 16, do: 1, else: 0

        write_ldo(spi,ldo_on)
      end
    end
  end

  defp  write_ldo(spi,ldo_on) do
    Communicator.write_register(
        spi,
        Parameters.register().modem_config_3,
        Bits.bit_write(
          Communicator.read_register(spi, Parameters.register().modem_config_3),
          3,
          ldo_on
        )
      )
  end

  def set_spreading_factor(spi,sf) do
    if sf == 6 do
      Communicator.write_register(spi, Parameters.register().detection_optimize, 0xC5)  # changed from 0xC5
      Communicator.write_register(spi, Parameters.register().detection_threshold, 0x0C)
      enable_crc(spi) # force crc enabled if sf = 6
      set_header_mode(spi,false) # force implicit mode with sf = 6
    else
      Communicator.write_register(spi, Parameters.register().detection_optimize, 0xC3)
      Communicator.write_register(spi, Parameters.register().detection_threshold, 0x0A)
    end

    config2 = Communicator.read_register(spi, Parameters.register().modem_config_2)

    sf_ = (config2 &&& 0x0F) ||| (sf <<< 4 &&& 0xF0)
    Communicator.write_register(spi, Parameters.register().modem_config_2, sf_)
    set_ldo_flag(spi)
  end

  def set_bandwidth(spi,sbw) do
    reg = Communicator.read_register(spi, Parameters.register().modem_config_1)

    Parameters.bw_freqs()
    |> Enum.filter(fn {_i, f} -> sbw <= f end)
    |> List.first()
    |> set_bw(spi, reg)

    set_ldo_flag(spi)
  end

  defp set_bw({bw, _freq},spi,reg) do
    Communicator.write_register(
      spi,
      Parameters.register().modem_config_1,
      (reg &&& 0x0F) ||| bw <<< 4
    )
  end

  defp set_coding_rate( spi, coding_rate) do
    reg = Communicator.read_register(spi, Parameters.register().modem_config_1)

    coding_bits = (coding_rate - 4) <<< 1

    Communicator.write_register(
      spi,
      Parameters.register().modem_config_1,
      (reg &&& 0xF1) ||| coding_bits
    )
  end


  def set_base_address(spi) do
    # Set base addresses
    Communicator.write_register(spi, Parameters.register().fifo_tx_base_addr, 0)
    Communicator.write_register(spi, Parameters.register().fifo_rx_base_addr, 0)
  end

  def set_LNA_boost(spi),
    do:
      Communicator.write_register(
        spi,
        Parameters.register().lna,
        Communicator.read_register(spi, Parameters.register().lna) ||| 0x03
      )

  def set_auto_AGC(spi),
    do: Communicator.write_register(spi, Parameters.register().modem_config_3, 0x04)

  # set explicit / implicit mode
  def set_header_mode(spi,expl) do
    modem_config_1 = Communicator.read_register(spi, Parameters.register().modem_config_1)

    if expl,
      do:
        Communicator.write_register(
          spi,
          Parameters.register().modem_config_1,
          modem_config_1 &&& Parameters.header(expl)
        ),
      else:

        Communicator.write_register(
          spi,
          Parameters.register().modem_config_1,
          modem_config_1 ||| Parameters.header(expl)
        )

    reset_fifo_payload(spi)
  end

  def enable_crc(spi),
    do:
      Communicator.write_register(
        spi,
        Parameters.register().modem_config_2,
        Communicator.read_register(spi, Parameters.register().modem_config_2) ||| 0x04
      )

  def disable_crc(spi),
    do:
      Communicator.write_register(
        spi,
        Parameters.register().modem_config_2,
        Communicator.read_register(spi, Parameters.register().modem_config_2) ||| 0xFB
      )

  def get_signal_band_width(spi) do
    bw = Communicator.read_register(spi, Parameters.register().modem_config_1) >>> 4
    Parameters.bw_freqs()[bw]
  end

  def get_spreading_factor(spi) do
    config = Communicator.read_register(spi, Parameters.register().modem_config_2)
    config >>> 4
  end

  def get_version(spi), do: Communicator.read_register(spi, Parameters.register().version)


  defp uint8(val) do
    cond do
      val < 0 ->
        teste = 256 + trunc(val)

        if teste < 0 do
          uint8(teste)
        else
          teste
        end

      val <= 255 ->
        trunc(val)

      val > 255 ->
        rem(trunc(val), 256)
    end
  end


  # defp change_third_bit(value, bit), do: if(bit == 0, do: value &&& 0xF7, else: value ||| 8)
end
