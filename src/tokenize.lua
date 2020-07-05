globals("tokenize")

local lpeg = require "lpeg"

function tokenize(input)
   local ret = {}
   local pos = 1
   while pos <= #input do
      local prespace, beginpos, type, data, postspace, endpos
         = assert(lpeg.match(lex, input, pos))
      if type == "eof" then
         if #ret > 0 then
            ret[#ret].postspace = ret[#ret].postspace .. prespace
         end
         break
      end
      ret[#ret+1] = {
         prespace=prespace,
         beginpos=beginpos,
         type=type,
         data=data,
         postspace=postspace,
         endpos=endpos,
      }
      pos = endpos
   end
   return ret
end
