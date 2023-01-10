#! /bin/env ruby


def backgroundRunTask(cmds, max)
  pids = Array.new

  0.upto(max-1) do |index|
    break if cmds.size == 0
    cmd = cmds.shift
    pid = Process.fork {cmd.call}
  end

  begin
    while Process.wait(-1) > 0 do
      if cmds.size > 0
        cmd = cmds.shift
        pid = Process.fork{cmd.call}
      end
    end
  rescue Errno::ECHILD => e
    ;
  end

end


def backgroundRunHPC(cmds, jid_outfiles, max)
  a = Marshal.load(Marshal.dump(cmds))
  b = Marshal.load(Marshal.dump(jid_outfiles))

  jids = Array.new
  jid = nil
  1.upto(max) do |index|
    break if a.size == 0
    a, b, ids = submitOneJob(a, b, jids)
  end

  while jids.size > 0
    jids.each_with_index do |jid, index|
      status = `bjobs -l #{jid}`;
      if status =~ /Done successfully/
        #puts ["Delele", jids[index]].join("\t")
        jids.delete_at(index)
        if a.size > 0
          a, b, jids = submitOneJob(a, b, jids)
        end
      end
    end
    sleep 0.1
  end
end


def submitOneJob(a, b, jids)
  cmd = a.shift
  jid_outfile = b.shift
  eval cmd
  if ! $?.success?
    puts "Fatal error at #{cmd}"
    puts "Exiting ......"
    puts
    exit 1
  end
  jid = `grep -oP '(?<=<)[0-9]+(?=>)' #{jid_outfile}`.chomp
  jids << jid
  return([a, b, jids])
end


