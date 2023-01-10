#! /usr/bin/env ruby


###############################################################
require 'getoptlong'
require 'parallel'

require 'Dir'
require 'util'


###############################################################
BMGE = File.expand_path("~/software/phylo/BMGE-1.12/BMGE.jar")

indir = nil
cpu = 1
outdir = nil
is_force = false
type = 'AA'


###############################################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--type', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '--indir'
      indir = value
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
    when '--cpu'
      cpu = value.to_i
    when '--type'
      type = value
  end
end


###############################################################
mkdir_with_force(outdir, is_force)

infiles = read_infiles(indir)


###############################################################
Parallel.map(infiles, in_processes:cpu) do |infile|
  c = getCorename(infile)
  out_fas = File.join(outdir, c+'.aln')
  out_html = File.join(outdir, c+'.html')
  `java -jar #{BMGE} -i #{infile} -h 1 -g 1 -t #{type} -of #{out_fas} -oh #{out_html} -s fast`
  puts [c, 'DONE!'].join("\t")
end


