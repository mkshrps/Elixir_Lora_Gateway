defmodule Lora.Utils do
alias Lora.Parameters
alias Lora.Communicator
require Logger

def dump_registers(spi) do
    regmap = Parameters.register
    Enum.each(regmap, fn {key,value} -> Logger.info(
      "Name #{key}, #{Integer.to_string(value,16)}, Value #{Integer.to_string(Communicator.read_register(spi,value),16)} ") end)
  end

  def  get_reg(reg, spi) do
    value = Communicator.read_register(spi,reg)
    %{:reg => Integer.to_string(reg), :value => Integer.to_string(value)  }
  end

end
