#! /usr/bin/env ruby


###################################################
require 'getoptlong'
require 'bio'
require 'parallel'

require 'Dir'
require 'SSW_bio'


###################################################
indir = nil
outdir = nil
sep = '|'
field = 1
cpu = 1
is_force = false
is_tolerate = false


###################################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--tolerate', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^--indir$/
      indir = value
    when /^--outdir$/
      outdir = value
    when /^--cpu$/
      cpu = cpu.to_i
    when /^--force$/
      is_force = true
    when /^--tolerate$/
      is_tolerate = true
  end
end


###################################################
mkdir_with_force(outdir, is_force, is_tolerate)


###################################################
infiles = read_infiles(indir)


Parallel.map(infiles, in_processes: cpu) do |infile|
  b = File.basename(infile)
  outfile = File.join(outdir, b)
  out_fh = File.open(outfile, 'w')

  seq_objs = read_seq_file(infile)
  seq_objs.each_pair do |title, f|
    title_arr = title.split(sep)
    title = title_arr[field-1]
    out_fh.puts '>' + title
    out_fh.puts f.seq
  end

  out_fh.close
end


