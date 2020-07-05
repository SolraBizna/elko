globals("err_at", "error_count", "fatal_errors")

error_count = 0

function err_at(byteno, format, ...)
   local message = format:format(...)
   io.stderr:write(("%s:%i: %s\n"):format(input_file,
                                          linemap:get(byteno),
                                          message))
   error_count = error_count + 1
end

function fatal_errors()
   if error_count > 0 then
      if error_count == 1 then
         io.stderr:write("Aborting due to 1 error.\n")
      else
         io.stderr:write("Aborting due to ",error_count," errors.\n")
      end
      os.exit(1)
   else
      return false
   end
end
