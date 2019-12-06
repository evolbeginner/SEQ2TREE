#! /bin/env ruby


################################################################
dir = File.dirname($0)
lib_path = File.join(dir, 'lib')
$LOAD_PATH.unshift(lib_path)


################################################################
require 'procManage'


################################################################
@SUBMITHPC = 'submitHPC.sh'


################################################################
pid_outfiles = Array.new
cmds = Array.new


################################################################
a = Array.new(7,0)

#cmds = a.map{|i|"system (\"echo #{i}\") and sleep 6-#{i}"}
a.each_with_index do |ele, index|
  pid_outfile = File.join("tmp", index.to_s)
  pid_outfiles << pid_outfile
  cmd = "\`#{@SUBMITHPC} --cmd 'echo 5' -n 4 --lsf #{index}.lsf --do --force --bsub #{index}.haha --jid_out #{pid_outfile}\`"
  cmds << cmd
end

backgroundRunHPC(cmds, pid_outfiles, 3)


