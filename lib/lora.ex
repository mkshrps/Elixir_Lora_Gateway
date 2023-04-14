  defmodule Lora do
    use GenServer

    @server Lora.Server
    @server_name Lora

  @doc """
  API for lora comms

  Start and link a new GenServer for Lora radio.

  Can be set the parameters of
    spi: SPI port "spidev0.0 or spidev0.1 etc
    rst: GPIO pin for the reset of radio.
    spi_speed:
    dio0: irq pin for RFMxx (required for receiver)

    # standard values: `spi: "spidev0.1", spi_speed: 8_000_000, rst: 25`
      {:ok, lora} = Lora.start_link()
    or
      {:ok, lora} = Lora.start_link([spi: "spidev0.1", spi_speed: 5_000_000, rst: 27])

  """
  def start_link(config \\ []), do: GenServer.start_link(@server,config, [name: @server_name])

  @doc """
  Initialize the Lora Radio and set your frequency work.
      {:ok, lora} = Lora.start_link()
      Lora.begin(lora, 433.0e6)
  """
  def begin(frequency), do: GenServer.call(@server_name, {:begin, frequency})
  @doc """
  Set the Lora UKHAS mode
      Lora.set_ukhas_mode(mode \\ 1)
  """
  def set_ukhas_mode(mode \\ 1), do: GenServer.cast(@server_name,{:set_ukhas_mode, mode})

  @doc """
  Set the Lora frequency
  """
  def set_frq(frequency), do: GenServer.cast(@server_name,{:set_frq,frequency})

  @doc """
    set auto tune mode
  """
  def set_auto_tune(set), do: GenServer.cast(@server_name,{:set_auto_tune,set})
  @doc """
  Set the Lora Radio in sleep mode.
      Lora.sleep()
  """

  def sleep(), do: GenServer.cast(@server_name, :sleep)
  @doc """
  Awake the Lora Radio.
      Lora.awake(lora_pid)
  """
  def awake(), do: GenServer.cast(@server_name, :awake)

  @doc """
  Set Spreading Factor. `sf` is a value between 6 and 12. Standar value is 6.

      Lora.set_spreading_factor(lora_pid, 10)
  """
  def set_spreading_factor( sf \\ 6) when sf >= 6 and sf <= 12,
    do: GenServer.cast(@server_name, {:set_sf, sf})
  @doc """
  Set Trasmission Signal Bandwidth.

      Lora.set_signal_bandwidth(lora_pid, 31.25e3)
  """
  def set_signal_bandwidth( sbw), do: GenServer.cast(@server_name, {:set_sbw, sbw})
  @doc """
  This is a verify digit add in the data message.

      Lora.enable_crc(lora_pid)
  """
  def enable_crc(), do: GenServer.cast(@server_name, :enable_crc)
  @doc """
  Remove the verify digit.

      Lora.disable_crc(lora_pid)
  """
  def disable_crc(), do: GenServer.cast(@server_name, :disable_crc)
  @doc """
  Send data for other radios.

      Lora.send(lora_pid, "hello world")
      Lora.send(lora_pid, %{value: 10})
  """
  def send( data, header \\ true) do
    GenServer.cast(@server_name, :sender_mode)
    GenServer.cast(@server_name, {:send, data, header})
  end

end
