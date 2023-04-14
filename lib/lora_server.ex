defmodule Lora.Server do
  @moduledoc """
  This is a module for receiving HAB data using Lora Radios.

  Radios:
      Semtech SX1276/77/78/79 based boards.
  """
  use GenServer
  alias Circuits.SPI
  alias Circuits.GPIO
  alias Lora.Modem
  alias Lora.Bits
  alias Lora.AutoTune
  require Logger

  # SPI
  @lora_default_spi "spidev0.1"
  @lora_default_spi_frequency 8_000_000
  @lora_default_reset_pin 25
  @lora_default_dio0_pin 22
  @lora_default_dio1_pin 23
  @lora_default_dio2_pin 24
  # hardwire the name od the manager genserver for now
  @comms_manager_server SensorHubComms
  @doc """
  initialise lora receiver
  the following options are available
  :spi "spidev0.0" , "spidev0.1"
  :spi_speed
  :frq frequency value
  :ukhas_mode 0,1,2 \\ 1
  :receiver true/false \\ true
  :rst reset pin \\ 25
  :dio0 DIO0 pin \\ 22

  Ukhas mode sets the following lora parameters

  :bw lora bandwidth setting
  :sf lora spreading factor (6-12)
  :crc on/off
  :error_coding
  :payload_length \\ 255 only applies to sf6 (ukhas mode 1)
  :ukhas_mode 0,1,2

  initially the modem config is set by a UKHAS mode (default 1) with format
  [sf: ::6 - 12, bw: , ec: 5-8, explicit: true/false, payload: nil || 255]
  custom configuration can be set manually following initialisation
  """
  def init(config) do
    pin_reset = Keyword.get(config, :rst, @lora_default_reset_pin)
    pin_dio_0 = Keyword.get(config, :dio0, @lora_default_dio0_pin)
    _pin_dio_1 = Keyword.get(config, :dio1, @lora_default_dio1_pin)
    _pin_dio_2 = Keyword.get(config, :dio2, @lora_default_dio2_pin)

    device = Keyword.get(config, :spi, @lora_default_spi)
    speed_hz = Keyword.get(config, :spi_speed, @lora_default_spi_frequency)

    {:ok, spi} = start_spi(device, [speed_hz: speed_hz])

    Logger.info("Lora: Start Device")
    {:ok, rst} = GPIO.open(pin_reset, :output)
    {:ok, dio0} = GPIO.open(pin_dio_0,:input, pull_mode: :pullup)

    GPIO.set_interrupts(dio0,:rising)

    Modem.reset(rst)
    mode = Keyword.get(config, :ukhas_mode, 1)
    modem_config = Lora.UkhasModes.ukhas_mode(mode)

    {:ok,
     %{
         spi: spi,
         rst: rst,
         dio0: dio0,
         config: %{frequency: 0, header: true,
         modem_config: modem_config,
         packet_index: 0,
         on_receive: nil},
         current_mode: :rxdone,
         rssi: 0,
         snr: 0,
         last_payload: [],
         last_msg_status: :none,
         auto_tune: true,
         frq_err: 0,
         ppm_comp: 0
         }}
  end



  def handle_call({:begin, frequency}, _from, state) do

    version = Modem.get_version(state.spi)

    if version == 0x12 do
      Modem.begin(state.spi,frequency,state.config.modem_config )

      # enable receiver interrupt
      Modem.enable_receiver_interrupts(state.spi)
      #    Process.send_after(self(), :receiver_mode, 500)
      {:reply, :ok, %{state | :config => %{state[:config] | :frequency => frequency}}}
    else
      Logger.error("Lora: Not a Valid Version")
      {:reply, {:error, :version}, state}
    end
  end

  # DIO0 interrupt handler
  def handle_info({:circuits_gpio, @lora_default_dio0_pin, _timestamp, _value}, state) do
    #Logger.info("dio0 triggered")
    state = process_rx_interrupt(msg_ok?(state.spi),state)
    # send the payload to the comms manager
    payload_data = %{payload: state.last_payload, status: state.last_msg_status, frq: state.config.frequency, rssi: state.rssi, snr: state.snr}
    # send to supervisor uploader
    GenServer.cast(@comms_manager_server,{:process_payload,payload_data})

    # Autotune if anabled
    frequency_error = Modem.read_frq_error(state.spi)
                      |> AutoTune.calculate_frq_error(Modem.get_signal_band_width(state.spi))

    # calculate ppm compensation value
    #ppm_comp = AutoTune.ppm_compensation(state.config.frequency,frequency_error)

      new_frq = if state.auto_tune do
        {:ok,[frequency: new_frq, ppm: _new_ppm]} =
        AutoTune.tune(state.config.frequency,frequency_error,0,state.spi)
        new_frq
      end

    Logger.info("measured  frq error #{frequency_error}")

    state = %{state | :config => %{state[:config] | frequency:  new_frq }}

    Logger.info("state frequency - #{state.config.frequency}")
    Modem.enable_receiver_interrupts(state.spi)
    {:noreply, state}
  end

  def handle_info(:send_ok, state) do
    Logger.debug("Lora: message sent")

    Modem.tx_done_flag(state.spi)

    {:noreply, state}
  end

  def handle_info(:send_error, state) do
    Logger.error("Lora: Send Timeout")
    {:noreply, state}
  end

  def handle_cast({:set_ukhas_mode,mode},state) do
    modem_config = Lora.UkhasModes.ukhas_mode(mode)
    state = if(mode >= 0 && mode <=2) do
      set_modem_params(modem_config,state.spi)
      put_in(state.config,:modem_config,modem_config)
    end
    {:noreply,state}
  end


  def handle_cast({:set_sf, sf}, state) do
    Modem.set_spreading_factor(state.spi,sf)
    {:noreply, state}
  end

  def handle_cast({:set_sbw, sbw}, state) do
    Modem.set_bandwidth(state.spi,sbw)
    {:noreply, state}
  end

  def handle_cast(:sleep, state) do
    # Put in sleep mode
    Modem.sleep(state.spi)
    #SPI.release(state.spi.pid)
    {:noreply, state}
  end

  def handle_cast(:awake, state) do
    operator = state.spi.operator

    {:ok, spi} = start_spi(operator.device, operator.speed_hz)
    new_spi = %{state[:spi] | pid: spi}

    Modem.idle(new_spi)
    {:noreply, %{state | :spi => new_spi}}
  end

  def handle_cast(:enable_crc, state) do
    Modem.enable_crc(state.spi)
    {:noreply, state}
  end

  def handle_cast(:disable_crc, state) do
    Modem.disable_crc(state.spi)
    {:noreply, state}
  end

  def handle_cast({:header_mode, value}, state) do
    Modem.set_header_mode( state.spi,value)
    {:noreply, %{state | :config => %{state[:config] | :header => value}}}
  end

  def handle_cast({:set_frq, frequency},state) do
    Modem.set_frequency(frequency,state.spi)
    {:noreply, %{state | :config => %{state[:config] | :frequency => frequency}}}
  end

  def handle_cast({:set_auto_tune, set},state) do
    state = Map.put(state,:auto_tune,set)
    {:noreply, state}
  end

 defp start_spi(device, opts) do
    {:ok, spi} = SPI.open(device,opts)
    {:ok, spi}
  end

  @doc """
  process the DIO0 interrupt payload message
  :ok indicates valid payload
  :error indicates invalid payload
  """
  def process_rx_interrupt(:ok,state) do
    payload = Modem.read_payload(state.spi,state.config.modem_config[:payload])
    rssi = Modem.rssi(state.spi,state.config.frequency)
    snr = Modem.snr(state.spi)
    Logger.info("payload = #{payload}")
    Logger.info("RSSI -  #{rssi}")
    Logger.info("SNR - #{snr}")
    #Modem.reset_fifo_payload(state.spi)
    state = Map.put(state,:rssi,rssi)
    state = Map.put(state,:snr,snr)
    state = Map.put(state,:last_payload,payload)
    state = Map.put(state,:last_msg_status,:ok)
    state
  end

  def process_rx_interrupt(:error,state) do
    rssi = Modem.rssi(state.spi,state.config.frequency)
    snr = Modem.snr(state.spi)
    Logger.info("CRC Error")
    Logger.info("RSSI -  #{rssi}")
    Logger.info("SNR - #{snr}")
    #Modem.reset_fifo_payload(state.spi)
    state = Map.put(state,:rssi,rssi)
    state = Map.put(state,:snr,snr)
    state = Map.put(state,:last_payload,"")
    state = Map.put(state,:last_msg_status,:crc_error)
    state

  end

  # read the interrupt register
  # test the crc error bit
  # returns :ok or :error
  def msg_ok?(spi) do
    crc_mask = Lora.Parameters.irq().payload_crc_error_mask
    Modem.irq_flags(spi)
    |> check_crc(crc_mask)
  end

  def check_crc(reg,crcbit) do
    case Bits.testbit(reg,crcbit) do
      true -> :error
      false -> :ok
    end
  end


    def  set_modem_params(lora_config,spi) do
      op_mode = Modem.read_op_mode(spi)
      Modem.sleep(spi)
      Modem.set_coding_rate(spi,lora_config[:ec])
      Modem.set_bandwidth(spi,lora_config[:bw])
      Modem.set_spreading_factor(spi,lora_config[:sf])
      Modem.set_op_mode(op_mode,spi)
    end
end
