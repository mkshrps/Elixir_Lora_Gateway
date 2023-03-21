defmodule Lora.Bits do
  import Bitwise

  def testbit(pattern,bit) do

    (bit &&& pattern) != 0
  end

end
