#! /usr/bin/env ruby


#########################################################
require 'parallel'


#########################################################
dir = File.dirname($0)
lib_path = File.join(dir, 'lib')
$LOAD_PATH.unshift(lib_path)


#########################################################
require 'getoptlong'
require 'parallel'

require 'Dir'
require 'basics'


#########################################################
$TRIMAL=File.expand_path("/home-user/software/trimAl/trimal-1.4.1/source/trimal")


#########################################################
indir = nil
infiles = Array.new
suffix = nil
outdir = nil
is_RML = false
is_seqoverlap = false
is_nogaps = false
cpu = 5
is_force = false
is_tolerate = false


#########################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--trimal_path', GetoptLong::REQUIRED_ARGUMENT],
  ['--nogap', '--nogaps', GetoptLong::NO_ARGUMENT],
  ['--RML', GetoptLong::NO_ARGUMENT],
  ['--seqoverlap', GetoptLong::NO_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--tolerate', GetoptLong::NO_ARGUMENT]
)


opts.each do |opt, value|
  case opt
    when /^-i$/
      infiles << value.split(',')
    when /^--indir$/
      indir = value
    when /^--suffix$/
      suffix = value
    when /^--outdir$/
      outdir = value
    when /^--trimal_path$/
      $TRIMAL=value
    when /^--RML$/i
      is_RML = true
    when /^--seqoverlap$/
      is_seqoverlap = true
    when /^--nogaps?$/
      is_nogaps = true
    when /^--cpu$/
      cpu = value.to_i
    when /^--force$/
      is_force = true
    when /^--tolerate$/
      is_tolerate = true
  end
end


mkdir_with_force(outdir, is_force, is_tolerate)


#########################################################
if not indir.nil?
  infiles = read_infiles(indir, suffix)
end

infiles.flatten!

if infiles.empty?
  puts "Error! Infiles have to be given! Exiting ......"
end


#########################################################
results = Parallel.map(infiles, in_processes: cpu) do |infile|
  c = getCorename(infile)
  outfile = File.join(outdir, c+'.aln')
  if is_RML
    system("#{$TRIMAL} -in #{infile} -out #{outfile} -automated1 -resoverlap 0.55 -seqoverlap 60")
  elsif is_nogaps
    system("#{$TRIMAL} -in #{infile} -out #{outfile} -nogaps")
  elsif is_seqoverlap
    system("#{$TRIMAL} -in #{infile} -out #{outfile} -st 0.001 -resoverlap 0.75 -seqoverlap 80 2>/dev/null")
  else
    system("#{$TRIMAL} -in #{infile} -out #{outfile} -st 0.001")
    #system("#{$TRIMAL} -in #{infile} -out #{outfile} -st 0.001 -resoverlap 0.75 -seqoverlap 80 2>/dev/null")
  end
end


