#!/usr/bin/env lua5.3
-- Simple Lua script to concatentate several others into one big, finished blob

-- Copyright ©2018 Solra Bizna. Permission is expressly granted to use this
-- file (assemble-elko.lua) and its contents, for any purpose, without
-- limitation, period.

io.write[[
#!/usr/bin/env lua5.3

-- This file is concatentated from several smaller files, to allow the
-- program's logic to be spread out without complicating its invocation
-- and/or distribution processes.

]]

for n=1,#arg do
   local f = assert(io.open(arg[n], "r"))
   local a = f:read("*a")
   f:close()
   assert(load(a,"@"..arg[n]))
   io.write(("load(%q,%q)()\n"):format(a, "@"..arg[n]))
end
