globals("input", "linemap", "tokens")

local outf, next_token, unget_token, push_token_pos, pop_token_pos, discard_token_pos

local cur_expected_line = nil
local clean_line = true

local function emit_line_directive(bytepos)
   local new_expected_line = linemap:get(bytepos)
   if new_expected_line ~= cur_expected_line then
      if not clean_line then outf:write("\n") end
      outf:write("#line ", new_expected_line, " \"", input_file, "\"\n")
      clean_line = true
   end
   cur_expected_line = new_expected_line
end

local function emit(...)
   local arg = {...}
   for n=1,#arg do
      local q = tostring(arg[n])
      outf:write(q)
      local lbp = find_linebreak_positions(q)
      if #lbp ~= 0 then
         if cur_expected_line then
            cur_expected_line = cur_expected_line + #lbp
         end
         clean_line = lbp[#lbp] == #q+1
      else
         clean_line = false
      end
   end
end

local function emit_token(tok)
   if tok.beginpos then
      emit_line_directive(tok.beginpos)
   end
   if tok.prespace then
      emit(tok.prespace)
   end
   emit(tok.data)
   if tok.postspace then
      emit(tok.postspace)
   end
end

local function emit_type(type)
   if type.pos then
      emit_line_directive(type.pos)
   end
   emit(type.type)
end

local function emit_until_end_of_thing(tok)
   local brace_level = 0
   if not tok then tok = next_token() end
   while tok do
      if tok.data == "{" then
         brace_level = brace_level + 1
      elseif tok.data == "}" then
         brace_level = brace_level - 1
         if brace_level <= 0 then
            emit_token(tok)
            break
         end
      elseif tok.data == ";" then
         if brace_level == 0 then
            emit_token(tok)
            break
         end
      end
      emit_token(tok)
      tok = next_token()
   end
end

local function skip_until_end_of_thing(tok)
   local brace_level = 0
   if not tok then tok = next_token() end
   while tok do
      if tok.data == "{" then
         brace_level = brace_level + 1
      elseif tok.data == "}" then
         brace_level = brace_level - 1
         if brace_level <= 0 then
            break
         end
      elseif tok.data == ";" then
         if brace_level == 0 then
            break
         end
      end
      tok = next_token()
   end
end

local function expect_typename(soft)
   local ret = {}
   local tok = next_token()
   local pos = tok.beginpos
   if tok.data == "const" then
      ret[#ret+1] = tok.data
      tok = next_token()
   end
   if tok.data == "struct" or tok.data == "union" then
      ret[#ret+1] = tok.data
      tok = next_token()
      if tok.type ~= "identifier" then
         if not soft then
            err_at(tok.beginpos, "Expected an identifier (struct/union name)")
         end
         unget_token()
         return nil
      end
      if tok.data:sub(1,5) == "_elko" then
         err_at(tok.beginpos, "Identifiers with names beginning with `_elko` are not allowed within elkoroutines")
      end
      ret[#ret+1] = tok.data
      tok = next_token()
      unet_token()
      if tok.data == "{" then
         err_at(tok.beginpos, "You may not define a struct inside an elkoroutine declaration")
         skip_until_end_of_thing()
         return nil
      end
   else
      if tok.type ~= "identifier" then
         if not soft then
            err_at(tok.beginpos, "Expected an identifier (typename)")
         end
         unget_token()
         return nil
      end
      if tok.data:sub(1,5) == "_elko" then
         err_at(tok.beginpos, "Identifiers with names beginning with `_elko` are not allowed within elkoroutines")
      end
      if tok.data == "unsigned" or tok.data == "signed" then
         ret[#ret+1] = tok.data
         tok = next_token()
         if tok.data ~= "char" and tok.data ~= "short" and tok.data ~= "int"
         and tok.data ~= "long" then
            unget_token()
         end
      end
      if tok.data == "short" or tok.data == "long" then
         ret[#ret+1] = tok.data
         tok = next_token()
         if tok.data ~= "int" then
            unget_token()
         end
      end
      ret[#ret+1] = tok.data
   end
   while true do
      tok = next_token()
      if tok.data == "const" or tok.data == "*" then
         ret[#ret+1] = tok.data
      else
         unget_token()
         break
      end
   end
   return (table.concat(ret, " "):gsub(" *%* *", "*")), pos
end

local function expect_parameter_list()
   local tok = next_token()
   if tok.data ~= "(" then
      err_at(tok.beginpos, "Expected `(`")
      unget_token()
      return nil
   end
   local ret = {}
   while true do
      tok = next_token()
      if tok.data == ")" then break end
      unget_token()
      local pos = tok.beginpos
      local type = expect_typename()
      if not type then return nil end
      tok = next_token()
      if tok.type ~= "identifier" then
         err_at(tok.beginpos, "Expected an identifier")
         return nil
      end
      if tok.data:sub(1,5) == "_elko" then
         err_at(tok.beginpos, "Identifiers with names beginning with `_elko` are not allowed within elkoroutines")
      end
      ret[#ret+1] = {pos=pos, type=type, name=tok.data}
      tok = next_token()
      if tok.data == ")" then break
      elseif tok.data ~= "," then
         err_at(tok.beginpos, "Expected `,`")
         return nil
      end
   end
   return ret
end

local function shallow_clone(t)
   local ret = {}
   for n=1,#t do ret[n] = t[n] end
   return ret
end

local function eat_expression(into, terminators, frame)
   local tok = next_token()
   local paren_depth = 0
   while paren_depth > 0 or not terminators[tok.data] do
      if tok.data == "{" or tok.data == "}" then
         err_at(tok.beginpos, "Unexpected `%s` in expression", tok.data)
         fatal_errors()
      elseif tok.data == "(" then
         paren_depth = paren_depth + 1
      elseif tok.data == ")" then
         paren_depth = paren_depth - 1
         if paren_depth < 0 then
            err_at(tok.beginpos, "Too many `)` in expression")
            fatal_errors()
         end
      end
      if tok.type == "identifier" then
         for n=1,#frame do
            if frame[n].name == tok.data then
               tok.data = "_elko_state->frame"..frame.index.."."..tok.data
               break
            end
         end
      end
      into[#into+1] = tok
      tok = next_token()
   end
   unget_token()
end

local function handle_declaration(pos, type, inner_toks, frame)
   while true do
      local thistype = type
      local tok = next_token()
      while tok.data == "*" or tok.data == "const" do
         if tok.data == "*" then
            thistype = thistype .. " *"
         elseif tok.data == "const" then
            thistype = thistype .. " const"
         end
      end
      thistype = thistype:gsub(" *%* *", "*")
      if tok.type ~= "identifier" then
         err_at(tok.beginpos, "Expected an identifier (variable name in declaration)")
         return false
      end
      local nametok = tok
      local name = tok.data
      if name:sub(1,5) == "_elko" then
         err_at(tok.beginpos, "Identifiers with names beginning with `_elko` are not allowed within elkoroutines")
      end
      frame[#frame+1] = {pos=pos, type=thistype, name=name}
      tok = next_token();
      if tok.data == "=" then
         -- assign!
         inner_toks[#inner_toks+1] = {type="identifier", data="_elko_state->frame"..frame.index.."."..name, beginpos=nametok.beginpos, prespace=" ", postspace=" "}
         inner_toks[#inner_toks+1] = tok
         eat_expression(inner_toks, {[","]=true, [";"]=true}, frame)
         inner_toks[#inner_toks+1] = {type="punctuator", data=";"}
         tok = next_token()
      end
      if tok.data == "," then
         -- let's do another one!
      elseif tok.data == ";" then
         -- end of declaration!
         return true
      else
         err_at(tok.beginpos, "Expected `,` or `;`")
         fatal_errors()
      end
   end
end

local function emit_elkoroutine(static)
   local yield_type, yield_type_pos = expect_typename()
   if not yield_type then return skip_until_end_of_thing() end
   local tok = next_token()
   if tok.type ~= "identifier" then
      err_at(tok.beginpos, "Expected an identifier (elkoroutine name)")
      unget_token()
      return skip_until_end_of_thing()
   end
   if tok.data:sub(1,5) == "_elko" then
      err_at(tok.beginpos, "Identifiers with names beginning with `_elko` are not allowed within elkoroutines")
   end
   local base_name = tok.data
   local init_params = expect_parameter_list()
   if not init_params then return skip_until_end_of_thing() end
   local yield_params = expect_parameter_list()
   if not yield_params then return skip_until_end_of_thing() end
   tok = next_token()
   local inner_toks
   local frames
   local next_state = 1
   if tok.data == "{" then
      inner_toks = {tok, {data="_elko_top: case 0: {}"}}
      frames = {{index=1}}
      local brace_level = 1
      local current_frame = 1
      local framestack = {}
      local staato = true
      for n=1,#init_params do frames[1][#frames[1]+1] = init_params[n] end
      while brace_level > 0 do
         tok = next_token()
         if tok.data == "{" then
            inner_toks[#inner_toks+1] = tok
            framestack[brace_level] = current_frame
            brace_level = brace_level + 1
            local new_frame = #frames + 1
            frames[new_frame] = shallow_clone(frames[current_frame])
            frames[new_frame].index = new_frame
            current_frame = new_frame
            staato = true
         elseif tok.data == "}" then
            inner_toks[#inner_toks+1] = tok
            brace_level = brace_level - 1
            current_frame = framestack[brace_level]
            staato = true
         elseif tok.data == ";" then
            inner_toks[#inner_toks+1] = tok
            staato = true
         elseif tok.data == "else" then
            staato = false
         elseif tok.data == "return" then
            inner_toks[#inner_toks+1] = {beginpos=tok.beginpos, prespace=tok.prespace, postspace=tok.postspace, data="{_elko_state->_elko_case = "..next_state.."; return"}
            eat_expression(inner_toks, {[";"]=true}, frames[current_frame])
            local tok = next_token()
            tok.data = "; case "..next_state..": {}}"
            inner_toks[#inner_toks+1] = tok
            next_state = next_state + 1
            staato = true
         elseif staato then
            local pos = tok.beginpos
            unget_token()
            push_token_pos()
            local is_declaration = false
            local type = expect_typename(true)
            if type then
               tok = next_token()
               if tok.type == "identifier" or tok.data == "*" then
                  unget_token()
                  if handle_declaration(pos, type, inner_toks, frames[current_frame]) then
                     discard_token_pos()
                     is_declaration = true
                  end
               end
            end
            if not is_declaration then
               pop_token_pos()
               tok = next_token()
               staato = false
            end
         end
         if not staato then
            if tok.type == "identifier" then
               local frame = frames[current_frame]
               for n=1,#frame do
                  if frame[n].name == tok.data then
                     tok.data = "_elko_state->frame"..current_frame.."."..tok.data
                     break
                  end
               end
            end
            inner_toks[#inner_toks+1] = tok
         end
      end
   elseif tok.data == ";" then
      if static then
         err_at(tok.beginpos, "Static elkoroutines may not be forward-declared")
         return
      end
      err_at("Forward declarations are not implemented yet")
      return
   else
      err_at(tok.beginpos, "Expected `{` or `;`")
      return skip_until_end_of_thing()      
   end
   emit_line_directive(yield_type_pos)
   emit("union ", base_name, "_state {\n  int _elko_case;\n")
   for n=1, #frames do
      emit("  struct ", base_name, "_state_frame", n, " {\n    int _elko_case;\n")
      local frame = frames[n]
      for m=1,#frame do
         emit_line_directive(frame[m].pos)
         emit("    ", frame[m].type, " ", frame[m].name, ";\n")
      end
      emit("  } frame", n, ";\n")
   end
   emit("};\n")
   if not static then
      emit("int sizeof_", base_name, "_state = sizeof(", base_name, "_state);\n")
   end
   emit_line_directive(yield_type_pos)
   if static then emit("static ") end
   emit("void ", base_name, "_init(union ", base_name, "_state* _elko_state")
   for n=1,#init_params do
      emit(", ", init_params[n].type, " ", init_params[n].name)
   end
   emit(") {\n  _elko_state->_elko_case = 0;\n")
   for n=1,#init_params do
      emit("  _elko_state->frame1.", init_params[n].name, " = ", init_params[n].name, ";\n")
   end
   emit("}\n")
   if static then
      emit_type({pos=yield_type_pos, type="static "..yield_type})
   else
      emit_type({pos=yield_type_pos, type=yield_type})
   end
   emit(" ", base_name, "(union ", base_name, "_state* _elko_state")
   if inner_toks then
      assert(inner_toks[#inner_toks].data == "}")
      inner_toks[#inner_toks].data = "}goto _elko_top;}"
      for n=1,#yield_params do
         emit(", ", yield_params[n].type, " ", yield_params[n].name)
      end
      emit(") {\n")
      emit("  switch(_elko_state->_elko_case)")
      for n=1,#inner_toks do
         emit_token(inner_toks[n])
      end
   end
end

local function main()
   local f = assert(io.open(input_file, "rb"))
   input = assert(f:read("*a"))
   f:close()
   linemap = find_linebreak_positions(input)
   tokens = tokenize(input)
   if not tokens or fatal_errors() then return false end
   local token_n = 1
   unget_token = function() token_n = token_n - 1 end
   next_token = function(eof_ok)
      local ret = tokens[token_n]
      if not ret then
         if not eof_ok then
            err_at(#input, "Unexpected end of file")
            fatal_errors()
         else return ret end
      elseif ret.type == "unknown_char" then
         err_at(#input, "Unexpected character")
         fatal_errors()
      end
      token_n = token_n + 1
      return ret
   end
   local saved_positions = {}
   push_token_pos = function()
      saved_positions[#saved_positions+1] = token_n
   end
   pop_token_pos = function()
      token_n = saved_positions[#saved_positions]
      saved_positions[#saved_positions] = nil
   end
   discard_token_pos = function()
      saved_positions[#saved_positions] = nil
   end
   outf = assert(io.open(output_file, "wb"))
   outf:write("/* This file was automatically generated, and shouldn't be edited manually! */\n")
   while true do
      local tok = next_token(true)
      if not tok then break
      elseif tok.type == "comment" or tok.type == "directive" then
         emit_token(tok)
      elseif tok.data == "static" then
         -- might be starting a static elkoroutine
         local tok2 = next_token()
         if tok2.data == "elkoroutine" then
            -- yup!
            emit_elkoroutine(true)
         else
            -- nope!
            emit_token(tok)
            emit_token(tok2)
         end
      elseif tok.data == "elkoroutine" then
         -- elkoroutine!
         emit_elkoroutine(false)
      else
         emit_until_end_of_thing(tok)
      end
   end
   outf:close()
   return true
end

local s,e = xpcall(main, debug.traceback)
if not s then
   io.stderr:write(e,"\n")
   os.exit(1)
elseif not e then
   os.exit(1)
else
   fatal_errors()
end
