local old_exit = os.exit
function os.exit(status)
   if status ~= 0 then
      os.remove(output_file)
   end
   old_exit(status)
end
