defmodule Lora.Bits do
  import Bitwise

  def testbit(pattern,bit) do

    (bit &&& pattern) != 0
  end

  def bit_write(value, bit, subs) do
    {ini, fim} = list_bits(value) |> add_zeros(bit) |> Enum.split(bit)
    [_h | t] = fim
    Enum.reverse(ini ++ [subs] ++ t) |> listbits_to_integer()
  end

  defp add_zeros(list, bit, state \\ [], i \\ 0) do
    if length(list) <= bit and length(state) <= bit do
      if i <= length(list) - 1 do
        add_zeros(list, bit, state ++ [Enum.at(list, i)], i + 1)
      else
        add_zeros(list, bit, state ++ [0], i + 1)
      end
    else
      if bit <= length(list) - 1, do: list, else: state
    end
  end

  defp listbits_to_integer(list, state \\ 0, pot \\ 0) do
    if pot < length(list) do
      val = list |> Enum.reverse() |> Enum.at(pot)
      listbits_to_integer(list, state + :math.pow(2, pot) * val, pot + 1)
    else
      trunc(state)
    end
  end

  defp list_bits(value, state \\ []) do
    unless div(value, 2) == 0 do
      list_bits(div(value, 2), state ++ [rem(value, 2)])
    else
      state ++ [rem(value, 2)]
    end
  end

end
