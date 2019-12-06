#! /usr/bin/env ruby


############################################################
require 'getoptlong'
require 'parallel'
require 'tempfile'

require 'Dir'


############################################################
$BMGE = File.expand_path("~/software/phylo/BMGE-1.12/BMGE.jar")

indir = nil
outdir = nil
cpu = 1
is_sponge = false
is_force = false


############################################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--sponge', GetoptLong::NO_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '--indir'
      indir = value
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
    when '--sponge'
      is_sponge = true
    when '--cpu'
      cpu = value.to_i
  end
end


############################################################
mkdir_with_force(outdir, is_force) if not is_sponge


############################################################
infiles = read_infiles(indir)

Parallel.map(infiles, in_processes:cpu) do |infile|
  b = File.basename(infile)
  tmp = Tempfile.new(b)
  if is_sponge
    `java -jar #{$BMGE} -i #{infile} -h 1 -g 1 -t AA -s fast -of #{tmp.path}; mv #{tmp.path} #{infile}`
  else
    outfile = File.join(outdir, b)
    `java -jar #{$BMGE} -i #{infile} -h 1 -g 1 -t AA -s fast -of #{outfile}`
  end
end


