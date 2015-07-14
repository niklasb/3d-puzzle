#!/usr/bin/env ruby

class Array
  # rotate the array so that i is the new start index
  def rotate(i)
    i %= size
    if i == 0
      self.clone
    else
      self[i..-1] + self[0..(i-1)]
    end
  end
end
