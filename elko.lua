#!/usr/bin/env lua5.3

-- This file is concatentated from several smaller files, to allow the
-- program's logic to be spread out without complicating its invocation
-- and/or distribution processes.

load("--[[\
\
   Copyright ©2018-2020 Solra Bizna.\
\
   This program is free software: you can redistribute it and/or modify it\
   under the terms of the GNU General Public License as published by the Free\
   Software Foundation, either version 3 of the License, or (at your option)\
   any later version.\
\
   This program is distributed in the hope that it will be useful, but WITHOUT\
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or\
   FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for\
   more details.\
\
   You should have received a copy of the GNU General Public License along with\
   this program. If not, see <https://www.gnu.org/licenses/>.\
\
]]\
\
local declared = {}\
function globals(...)\
   for _,v in ipairs{...} do\
      declared[v] = true\
   end\
end\
\
-- require ahead so that we fail as early as possible if the libraries aren't\
-- available, and so that our global system isn't in place to potentially foul\
-- them up\
require \"lpeg\"\
require \"lfs\"\
\
local _mt = {}\
function _mt:__newindex(k,v)\
   if not declared[k] then\
      error(\"Undeclared global: \"..tostring(k), 2)\
   else\
      rawset(self,k,v)\
   end\
end\
_mt.__index = _mt.__newindex\
setmetatable(_G, _mt)\
\
globals(\"input_file\", \"output_file\")\
\
-- Parse command line options\
local n = 1\
local cmdline_bad = false\
while n <= #arg do\
   if arg[n] == \"--\" then\
      table.remove(arg, n)\
      break\
   elseif arg[n]:sub(1,1) == \"-\" then\
      local opts = table.remove(arg, n)\
      for m=2,#opts do\
         local opt = opts:sub(m,m)\
         if opt == \"o\" then\
            if arg[n] == nil then\
               io.stderr:write(\"Missing argument to -o\\n\")\
               cmdline_bad = true\
            elseif output_file then\
               io.stderr:write(\"Multiple occurrences of -o\\n\")\
               cmdline_bad = true\
            else\
               output_file = table.remove(arg, n)\
            end\
         else\
            io.stderr:write(\"Unknown option: \",opt,\"\\n\")\
            cmdline_bad = true\
         end\
      end\
   else\
      n = n + 1\
   end\
end\
\
if #arg == 0 then\
   io.stderr:write(\"Please specify an input file\\n\")\
   cmdline_bad = true\
elseif #arg > 1 then\
   io.stderr:write(\"More than one input file cannot be specified\\n\")\
   cmdline_bad = true\
else\
   input_file = arg[1]\
end\
\
if not output_file then\
   io.stderr:write(\"No output file specified\\n\")\
   cmdline_bad = true\
end\
\
if cmdline_bad then\
   io.write[[\
Usage: elko -o output.c input.elko\
]]\
   os.exit(1)\
end\
\
","@src/top.lua")()
load("local old_exit = os.exit\
function os.exit(status)\
   if status ~= 0 then\
      os.remove(output_file)\
   end\
   old_exit(status)\
end\
","@src/exit_guard.lua")()
load("globals(\"linebreak_finder\", \"lex\")\
\
local lpeg = require \"lpeg\"\
local C,Cp,Ct,Cc,S,P,R,V = lpeg.C,lpeg.Cp,lpeg.Ct,lpeg.Cc,lpeg.S,lpeg.P,lpeg.R,lpeg.V\
\
linebreak_finder = P(1 - (P\"\\r\\n\" + P\"\\n\" + P\"\\r\"))^0 * (P\"\\r\\n\" + P\"\\n\" + P\"\\r\") * Cp();\
\
lex = P{\
   V\"eof\" + V\"token\";\
   eof = V\"prespace\" * P(-1) * Cc(\"eof\");\
   token = V\"prespace\" * (V\"comment\" + V\"directive\" + V\"identifier\" + V\"number\"\
                             + V\"char_literal\" + V\"string_literal\"\
                             + V\"punctuator\" + V\"unknown_char\") * V\"postspace\";\
   prespace = C((V\"whitespace\" - V\"linebreak\")^0) * Cp();\
   postspace = C(V\"whitespace\"^0) * Cp();\
   comment = Cc(\"comment\") * C(V\"sl_comment\" + V\"ml_comment\");\
   sl_comment = P\"//\" * (1 - V\"linebreak\")^0;\
   ml_comment = P\"/*\" * (1 - P\"*/\")^0;\
   directive = Cc\"directive\" * C(P\"#\" * (P\"\\\\\"*V\"linebreak\" + (1 - V\"linebreak\"))^0);\
   identifier = Cc\"identifier\" * C(R(\"__\",\"az\",\"AZ\")*R(\"__\",\"az\",\"AZ\",\"09\")^0),\
   number = Cc\"number\" * C(R\"09\" * (R(\"09\",\"AF\",\"af\")+S\".xulXUL+-\")^0),\
   whitespace = S\" \\t\\v\\n\\f\\r\";\
   linebreak = P\"\\r\\n\" + P\"\\n\" + P\"\\r\";\
   char_literal = Cc\"literal\" * C(P\"'\" * (V\"literal_el\" - P\"'\")^0 * P\"'\");\
   string_literal = Cc\"literal\" * C(P'\"' * (V\"literal_el\" - P'\"')^0 * P'\"');\
   literal_el = (P\"\\\\\" * (P\"x\" * R(\"09\",\"AF\",\"af\")^1\
                             + (R\"07\" * R\"07\"^-2)\
                             + 1)) + 1;\
   punctuator = Cc\"punctuator\" * C(P\"->\"+P\"++\"+P\"--\"+P\"<<=\"+P\">>=\"+P\"<=\"+P\">=\"\
                                      +P\"==\"+P\"!=\"+P\"&&\"+P\"||\"+P\"*=\"+P\"/=\"\
                                      +P\"%=\"+P\"+=\"+P\"-=\"+P\"<<\"+P\">>\"+P\"&=\"\
                                      +P\"^=\"+P\"|=\"\
                                      +S\"[](){}.&*+-~!/%<>^|?:;=,\");\
   unknown_char = Cc\"unknown_char\" + C(1);\
}\
","@src/lex.lua")()
load("globals(\"err_at\", \"error_count\", \"fatal_errors\")\
\
error_count = 0\
\
function err_at(byteno, format, ...)\
   local message = format:format(...)\
   io.stderr:write((\"%s:%i: %s\\n\"):format(input_file,\
                                          linemap:get(byteno),\
                                          message))\
   error_count = error_count + 1\
end\
\
function fatal_errors()\
   if error_count > 0 then\
      if error_count == 1 then\
         io.stderr:write(\"Aborting due to 1 error.\\n\")\
      else\
         io.stderr:write(\"Aborting due to \",error_count,\" errors.\\n\")\
      end\
      os.exit(1)\
   else\
      return false\
   end\
end\
","@src/err_at.lua")()
load("globals(\"find_linebreak_positions\")\
\
local lpeg = require \"lpeg\"\
\
-- linear search... TODO: replace me with one that \"takes a hint\"\
local function get_line(self, byte)\
   for n=1,#self do\
      if byte < self[n] then return n end\
   end\
   return #self+1\
end\
\
function find_linebreak_positions(input)\
   local ret = {}\
   local curpos = 1\
   while curpos <= #input do\
      local nextpos = lpeg.match(linebreak_finder, input, curpos)\
      if not nextpos then break end\
      ret[#ret+1] = nextpos\
      curpos = nextpos\
   end\
   ret.get = get_line\
   return ret\
end\
\
","@src/find_linebreak_positions.lua")()
load("globals(\"tokenize\")\
\
local lpeg = require \"lpeg\"\
\
function tokenize(input)\
   local ret = {}\
   local pos = 1\
   while pos <= #input do\
      local prespace, beginpos, type, data, postspace, endpos\
         = assert(lpeg.match(lex, input, pos))\
      if type == \"eof\" then\
         if #ret > 0 then\
            ret[#ret].postspace = ret[#ret].postspace .. prespace\
         end\
         break\
      end\
      ret[#ret+1] = {\
         prespace=prespace,\
         beginpos=beginpos,\
         type=type,\
         data=data,\
         postspace=postspace,\
         endpos=endpos,\
      }\
      pos = endpos\
   end\
   return ret\
end\
","@src/tokenize.lua")()
load("globals(\"input\", \"linemap\", \"tokens\")\
\
local outf, next_token, unget_token, push_token_pos, pop_token_pos, discard_token_pos\
\
local cur_expected_line = nil\
local clean_line = true\
\
local function emit_line_directive(bytepos)\
   local new_expected_line = linemap:get(bytepos)\
   if new_expected_line ~= cur_expected_line then\
      if not clean_line then outf:write(\"\\n\") end\
      outf:write(\"#line \", new_expected_line, \" \\\"\", input_file, \"\\\"\\n\")\
      clean_line = true\
   end\
   cur_expected_line = new_expected_line\
end\
\
local function emit(...)\
   local arg = {...}\
   for n=1,#arg do\
      local q = tostring(arg[n])\
      outf:write(q)\
      local lbp = find_linebreak_positions(q)\
      if #lbp ~= 0 then\
         if cur_expected_line then\
            cur_expected_line = cur_expected_line + #lbp\
         end\
         clean_line = lbp[#lbp] == #q+1\
      else\
         clean_line = false\
      end\
   end\
end\
\
local function emit_token(tok)\
   if tok.beginpos then\
      emit_line_directive(tok.beginpos)\
   end\
   if tok.prespace then\
      emit(tok.prespace)\
   end\
   emit(tok.data)\
   if tok.postspace then\
      emit(tok.postspace)\
   end\
end\
\
local function emit_type(type)\
   if type.pos then\
      emit_line_directive(type.pos)\
   end\
   emit(type.type)\
end\
\
local function emit_until_end_of_thing(tok)\
   local brace_level = 0\
   if not tok then tok = next_token() end\
   while tok do\
      if tok.data == \"{\" then\
         brace_level = brace_level + 1\
      elseif tok.data == \"}\" then\
         brace_level = brace_level - 1\
         if brace_level <= 0 then\
            emit_token(tok)\
            break\
         end\
      elseif tok.data == \";\" then\
         if brace_level == 0 then\
            emit_token(tok)\
            break\
         end\
      end\
      emit_token(tok)\
      tok = next_token()\
   end\
end\
\
local function skip_until_end_of_thing(tok)\
   local brace_level = 0\
   if not tok then tok = next_token() end\
   while tok do\
      if tok.data == \"{\" then\
         brace_level = brace_level + 1\
      elseif tok.data == \"}\" then\
         brace_level = brace_level - 1\
         if brace_level <= 0 then\
            break\
         end\
      elseif tok.data == \";\" then\
         if brace_level == 0 then\
            break\
         end\
      end\
      tok = next_token()\
   end\
end\
\
local function expect_typename(soft)\
   local ret = {}\
   local tok = next_token()\
   local pos = tok.beginpos\
   if tok.data == \"const\" then\
      ret[#ret+1] = tok.data\
      tok = next_token()\
   end\
   if tok.data == \"struct\" or tok.data == \"union\" then\
      ret[#ret+1] = tok.data\
      tok = next_token()\
      if tok.type ~= \"identifier\" then\
         if not soft then\
            err_at(tok.beginpos, \"Expected an identifier (struct/union name)\")\
         end\
         unget_token()\
         return nil\
      end\
      if tok.data:sub(1,5) == \"_elko\" then\
         err_at(tok.beginpos, \"Identifiers with names beginning with `_elko` are not allowed within elkoroutines\")\
      end\
      ret[#ret+1] = tok.data\
      tok = next_token()\
      unet_token()\
      if tok.data == \"{\" then\
         err_at(tok.beginpos, \"You may not define a struct inside an elkoroutine declaration\")\
         skip_until_end_of_thing()\
         return nil\
      end\
   else\
      if tok.type ~= \"identifier\" then\
         if not soft then\
            err_at(tok.beginpos, \"Expected an identifier (typename)\")\
         end\
         unget_token()\
         return nil\
      end\
      if tok.data:sub(1,5) == \"_elko\" then\
         err_at(tok.beginpos, \"Identifiers with names beginning with `_elko` are not allowed within elkoroutines\")\
      end\
      if tok.data == \"unsigned\" or tok.data == \"signed\" then\
         ret[#ret+1] = tok.data\
         tok = next_token()\
         if tok.data ~= \"char\" and tok.data ~= \"short\" and tok.data ~= \"int\"\
         and tok.data ~= \"long\" then\
            unget_token()\
         end\
      end\
      if tok.data == \"short\" or tok.data == \"long\" then\
         ret[#ret+1] = tok.data\
         tok = next_token()\
         if tok.data ~= \"int\" then\
            unget_token()\
         end\
      end\
      ret[#ret+1] = tok.data\
   end\
   while true do\
      tok = next_token()\
      if tok.data == \"const\" or tok.data == \"*\" then\
         ret[#ret+1] = tok.data\
      else\
         unget_token()\
         break\
      end\
   end\
   return (table.concat(ret, \" \"):gsub(\" *%* *\", \"*\")), pos\
end\
\
local function expect_parameter_list()\
   local tok = next_token()\
   if tok.data ~= \"(\" then\
      err_at(tok.beginpos, \"Expected `(`\")\
      unget_token()\
      return nil\
   end\
   local ret = {}\
   while true do\
      tok = next_token()\
      if tok.data == \")\" then break end\
      unget_token()\
      local pos = tok.beginpos\
      local type = expect_typename()\
      if not type then return nil end\
      tok = next_token()\
      if tok.type ~= \"identifier\" then\
         err_at(tok.beginpos, \"Expected an identifier\")\
         return nil\
      end\
      if tok.data:sub(1,5) == \"_elko\" then\
         err_at(tok.beginpos, \"Identifiers with names beginning with `_elko` are not allowed within elkoroutines\")\
      end\
      ret[#ret+1] = {pos=pos, type=type, name=tok.data}\
      tok = next_token()\
      if tok.data == \")\" then break\
      elseif tok.data ~= \",\" then\
         err_at(tok.beginpos, \"Expected `,`\")\
         return nil\
      end\
   end\
   return ret\
end\
\
local function shallow_clone(t)\
   local ret = {}\
   for n=1,#t do ret[n] = t[n] end\
   return ret\
end\
\
local function eat_expression(into, terminators, frame)\
   local tok = next_token()\
   local paren_depth = 0\
   while paren_depth > 0 or not terminators[tok.data] do\
      if tok.data == \"{\" or tok.data == \"}\" then\
         err_at(tok.beginpos, \"Unexpected `%s` in expression\", tok.data)\
         fatal_errors()\
      elseif tok.data == \"(\" then\
         paren_depth = paren_depth + 1\
      elseif tok.data == \")\" then\
         paren_depth = paren_depth - 1\
         if paren_depth < 0 then\
            err_at(tok.beginpos, \"Too many `)` in expression\")\
            fatal_errors()\
         end\
      end\
      if tok.type == \"identifier\" then\
         for n=1,#frame do\
            if frame[n].name == tok.data then\
               tok.data = \"_elko_state->frame\"..frame.index..\".\"..tok.data\
               break\
            end\
         end\
      end\
      into[#into+1] = tok\
      tok = next_token()\
   end\
   unget_token()\
end\
\
local function handle_declaration(pos, type, inner_toks, frame)\
   while true do\
      local thistype = type\
      local tok = next_token()\
      while tok.data == \"*\" or tok.data == \"const\" do\
         if tok.data == \"*\" then\
            thistype = thistype .. \" *\"\
         elseif tok.data == \"const\" then\
            thistype = thistype .. \" const\"\
         end\
      end\
      thistype = thistype:gsub(\" *%* *\", \"*\")\
      if tok.type ~= \"identifier\" then\
         err_at(tok.beginpos, \"Expected an identifier (variable name in declaration)\")\
         return false\
      end\
      local nametok = tok\
      local name = tok.data\
      if name:sub(1,5) == \"_elko\" then\
         err_at(tok.beginpos, \"Identifiers with names beginning with `_elko` are not allowed within elkoroutines\")\
      end\
      frame[#frame+1] = {pos=pos, type=thistype, name=name}\
      tok = next_token();\
      if tok.data == \"=\" then\
         -- assign!\
         inner_toks[#inner_toks+1] = {type=\"identifier\", data=\"_elko_state->frame\"..frame.index..\".\"..name, beginpos=nametok.beginpos, prespace=\" \", postspace=\" \"}\
         inner_toks[#inner_toks+1] = tok\
         eat_expression(inner_toks, {[\",\"]=true, [\";\"]=true}, frame)\
         inner_toks[#inner_toks+1] = {type=\"punctuator\", data=\";\"}\
         tok = next_token()\
      end\
      if tok.data == \",\" then\
         -- let's do another one!\
      elseif tok.data == \";\" then\
         -- end of declaration!\
         return true\
      else\
         err_at(tok.beginpos, \"Expected `,` or `;`\")\
         fatal_errors()\
      end\
   end\
end\
\
local function emit_elkoroutine(static)\
   local yield_type, yield_type_pos = expect_typename()\
   if not yield_type then return skip_until_end_of_thing() end\
   local tok = next_token()\
   if tok.type ~= \"identifier\" then\
      err_at(tok.beginpos, \"Expected an identifier (elkoroutine name)\")\
      unget_token()\
      return skip_until_end_of_thing()\
   end\
   if tok.data:sub(1,5) == \"_elko\" then\
      err_at(tok.beginpos, \"Identifiers with names beginning with `_elko` are not allowed within elkoroutines\")\
   end\
   local base_name = tok.data\
   local init_params = expect_parameter_list()\
   if not init_params then return skip_until_end_of_thing() end\
   local yield_params = expect_parameter_list()\
   if not yield_params then return skip_until_end_of_thing() end\
   tok = next_token()\
   local inner_toks\
   local frames\
   local next_state = 1\
   if tok.data == \"{\" then\
      inner_toks = {tok, {data=\"_elko_top: case 0: {}\"}}\
      frames = {{index=1}}\
      local brace_level = 1\
      local current_frame = 1\
      local framestack = {}\
      local staato = true\
      for n=1,#init_params do frames[1][#frames[1]+1] = init_params[n] end\
      while brace_level > 0 do\
         tok = next_token()\
         if tok.data == \"{\" then\
            inner_toks[#inner_toks+1] = tok\
            framestack[brace_level] = current_frame\
            brace_level = brace_level + 1\
            local new_frame = #frames + 1\
            frames[new_frame] = shallow_clone(frames[current_frame])\
            frames[new_frame].index = new_frame\
            current_frame = new_frame\
            staato = true\
         elseif tok.data == \"}\" then\
            inner_toks[#inner_toks+1] = tok\
            brace_level = brace_level - 1\
            current_frame = framestack[brace_level]\
            staato = true\
         elseif tok.data == \";\" then\
            inner_toks[#inner_toks+1] = tok\
            staato = true\
         elseif tok.data == \"else\" then\
            staato = false\
         elseif tok.data == \"return\" then\
            inner_toks[#inner_toks+1] = {beginpos=tok.beginpos, prespace=tok.prespace, postspace=tok.postspace, data=\"{_elko_state->_elko_case = \"..next_state..\"; return\"}\
            eat_expression(inner_toks, {[\";\"]=true}, frames[current_frame])\
            local tok = next_token()\
            tok.data = \"; case \"..next_state..\": {}}\"\
            inner_toks[#inner_toks+1] = tok\
            next_state = next_state + 1\
            staato = true\
         elseif staato then\
            local pos = tok.beginpos\
            unget_token()\
            push_token_pos()\
            local is_declaration = false\
            local type = expect_typename(true)\
            if type then\
               tok = next_token()\
               if tok.type == \"identifier\" or tok.data == \"*\" then\
                  unget_token()\
                  if handle_declaration(pos, type, inner_toks, frames[current_frame]) then\
                     discard_token_pos()\
                     is_declaration = true\
                  end\
               end\
            end\
            if not is_declaration then\
               pop_token_pos()\
               tok = next_token()\
               staato = false\
            end\
         end\
         if not staato then\
            if tok.type == \"identifier\" then\
               local frame = frames[current_frame]\
               for n=1,#frame do\
                  if frame[n].name == tok.data then\
                     tok.data = \"_elko_state->frame\"..current_frame..\".\"..tok.data\
                     break\
                  end\
               end\
            end\
            inner_toks[#inner_toks+1] = tok\
         end\
      end\
   elseif tok.data == \";\" then\
      if static then\
         err_at(tok.beginpos, \"Static elkoroutines may not be forward-declared\")\
         return\
      end\
      err_at(\"Forward declarations are not implemented yet\")\
      return\
   else\
      err_at(tok.beginpos, \"Expected `{` or `;`\")\
      return skip_until_end_of_thing()      \
   end\
   emit_line_directive(yield_type_pos)\
   emit(\"union \", base_name, \"_state {\\n  int _elko_case;\\n\")\
   for n=1, #frames do\
      emit(\"  struct \", base_name, \"_state_frame\", n, \" {\\n    int _elko_case;\\n\")\
      local frame = frames[n]\
      for m=1,#frame do\
         emit_line_directive(frame[m].pos)\
         emit(\"    \", frame[m].type, \" \", frame[m].name, \";\\n\")\
      end\
      emit(\"  } frame\", n, \";\\n\")\
   end\
   emit(\"};\\n\")\
   if not static then\
      emit(\"int sizeof_\", base_name, \"_state = sizeof(\", base_name, \"_state);\\n\")\
   end\
   emit_line_directive(yield_type_pos)\
   if static then emit(\"static \") end\
   emit(\"void \", base_name, \"_init(union \", base_name, \"_state* _elko_state\")\
   for n=1,#init_params do\
      emit(\", \", init_params[n].type, \" \", init_params[n].name)\
   end\
   emit(\") {\\n  _elko_state->_elko_case = 0;\\n\")\
   for n=1,#init_params do\
      emit(\"  _elko_state->frame1.\", init_params[n].name, \" = \", init_params[n].name, \";\\n\")\
   end\
   emit(\"}\\n\")\
   if static then\
      emit_type({pos=yield_type_pos, type=\"static \"..yield_type})\
   else\
      emit_type({pos=yield_type_pos, type=yield_type})\
   end\
   emit(\" \", base_name, \"(union \", base_name, \"_state* _elko_state\")\
   if inner_toks then\
      assert(inner_toks[#inner_toks].data == \"}\")\
      inner_toks[#inner_toks].data = \"}goto _elko_top;}\"\
      for n=1,#yield_params do\
         emit(\", \", yield_params[n].type, \" \", yield_params[n].name)\
      end\
      emit(\") {\\n\")\
      emit(\"  switch(_elko_state->_elko_case)\")\
      for n=1,#inner_toks do\
         emit_token(inner_toks[n])\
      end\
   end\
end\
\
local function main()\
   local f = assert(io.open(input_file, \"rb\"))\
   input = assert(f:read(\"*a\"))\
   f:close()\
   linemap = find_linebreak_positions(input)\
   tokens = tokenize(input)\
   if not tokens or fatal_errors() then return false end\
   local token_n = 1\
   unget_token = function() token_n = token_n - 1 end\
   next_token = function(eof_ok)\
      local ret = tokens[token_n]\
      if not ret then\
         if not eof_ok then\
            err_at(#input, \"Unexpected end of file\")\
            fatal_errors()\
         else return ret end\
      elseif ret.type == \"unknown_char\" then\
         err_at(#input, \"Unexpected character\")\
         fatal_errors()\
      end\
      token_n = token_n + 1\
      return ret\
   end\
   local saved_positions = {}\
   push_token_pos = function()\
      saved_positions[#saved_positions+1] = token_n\
   end\
   pop_token_pos = function()\
      token_n = saved_positions[#saved_positions]\
      saved_positions[#saved_positions] = nil\
   end\
   discard_token_pos = function()\
      saved_positions[#saved_positions] = nil\
   end\
   outf = assert(io.open(output_file, \"wb\"))\
   outf:write(\"/* This file was automatically generated, and shouldn't be edited manually! */\\n\")\
   while true do\
      local tok = next_token(true)\
      if not tok then break\
      elseif tok.type == \"comment\" or tok.type == \"directive\" then\
         emit_token(tok)\
      elseif tok.data == \"static\" then\
         -- might be starting a static elkoroutine\
         local tok2 = next_token()\
         if tok2.data == \"elkoroutine\" then\
            -- yup!\
            emit_elkoroutine(true)\
         else\
            -- nope!\
            emit_token(tok)\
            emit_token(tok2)\
         end\
      elseif tok.data == \"elkoroutine\" then\
         -- elkoroutine!\
         emit_elkoroutine(false)\
      else\
         emit_until_end_of_thing(tok)\
      end\
   end\
   outf:close()\
   return true\
end\
\
local s,e = xpcall(main, debug.traceback)\
if not s then\
   io.stderr:write(e,\"\\n\")\
   os.exit(1)\
elseif not e then\
   os.exit(1)\
else\
   fatal_errors()\
end\
","@src/main.lua")()
