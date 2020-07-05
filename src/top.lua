--[[

   Copyright ©2018-2020 Solra Bizna.

   This program is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the Free
   Software Foundation, either version 3 of the License, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
   more details.

   You should have received a copy of the GNU General Public License along with
   this program. If not, see <https://www.gnu.org/licenses/>.

]]

local declared = {}
function globals(...)
   for _,v in ipairs{...} do
      declared[v] = true
   end
end

-- require ahead so that we fail as early as possible if the libraries aren't
-- available, and so that our global system isn't in place to potentially foul
-- them up
require "lpeg"
require "lfs"

local _mt = {}
function _mt:__newindex(k,v)
   if not declared[k] then
      error("Undeclared global: "..tostring(k), 2)
   else
      rawset(self,k,v)
   end
end
_mt.__index = _mt.__newindex
setmetatable(_G, _mt)

globals("input_file", "output_file")

-- Parse command line options
local n = 1
local cmdline_bad = false
while n <= #arg do
   if arg[n] == "--" then
      table.remove(arg, n)
      break
   elseif arg[n]:sub(1,1) == "-" then
      local opts = table.remove(arg, n)
      for m=2,#opts do
         local opt = opts:sub(m,m)
         if opt == "o" then
            if arg[n] == nil then
               io.stderr:write("Missing argument to -o\n")
               cmdline_bad = true
            elseif output_file then
               io.stderr:write("Multiple occurrences of -o\n")
               cmdline_bad = true
            else
               output_file = table.remove(arg, n)
            end
         else
            io.stderr:write("Unknown option: ",opt,"\n")
            cmdline_bad = true
         end
      end
   else
      n = n + 1
   end
end

if #arg == 0 then
   io.stderr:write("Please specify an input file\n")
   cmdline_bad = true
elseif #arg > 1 then
   io.stderr:write("More than one input file cannot be specified\n")
   cmdline_bad = true
else
   input_file = arg[1]
end

if not output_file then
   io.stderr:write("No output file specified\n")
   cmdline_bad = true
end

if cmdline_bad then
   io.write[[
Usage: elko -o output.c input.elko
]]
   os.exit(1)
end

