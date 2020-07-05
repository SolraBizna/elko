globals("find_linebreak_positions")

local lpeg = require "lpeg"

-- linear search... TODO: replace me with one that "takes a hint"
local function get_line(self, byte)
   for n=1,#self do
      if byte < self[n] then return n end
   end
   return #self+1
end

function find_linebreak_positions(input)
   local ret = {}
   local curpos = 1
   while curpos <= #input do
      local nextpos = lpeg.match(linebreak_finder, input, curpos)
      if not nextpos then break end
      ret[#ret+1] = nextpos
      curpos = nextpos
   end
   ret.get = get_line
   return ret
end

