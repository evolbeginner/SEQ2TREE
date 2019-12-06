#! /usr/bin/env ruby


######################################################
require 'getoptlong'

require 'Dir'
require 'SSW_bio'


######################################################
infile = nil
outdir = nil
model = nil
cpu = 1
is_force = false
type = "AA"

mdef_dir = File.expand_path("~/tools/self_bao_cun/IQTREE/recoding/new_model/")


######################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['-m', '--model', GetoptLong::REQUIRED_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--type', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '-i'
      infile = value
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
    when '-m', '--model'
      model = value
    when '--type'
      type = value
    when '--cpu'
      cpu = value =~ /^\d+$/ ? value.to_i : value
  end
end


######################################################
mkdir_with_force(outdir, is_force)


######################################################
if model.nil?
  STDERR.puts "model has to be given! Exiting ......"
  exit 1
end


if model =~ /SR4|dayhoff4/i
  mdef = File.join(mdef_dir, model+'.nex')
  unless File.exists?(mdef)
    STDERR.puts "#{mdef} does not exist! Exiting ......"; exit 1
  end
end


######################################################
type = guessSeqType(infile).to_s

# generate guide tree
outdir1 = File.join(outdir, 'guide')
mkdir_with_force(outdir1, is_force)
puts "building guide tree ......"
mrate = type =~ /DNA|NA/i ? "GTR" : "LG"
mrate = 'GTR' if model =~ /SR4|dayhoff4/i
`iqtree -redo -s #{infile} -m #{mrate}+G+F -pre #{outdir1}/iqtree -nt #{cpu} -bb 1000`

# PMSF
puts "building pmsf tree ......"
case model
  when /SR4|dayhoff4/i
    `iqtree -redo -s #{infile} -m #{model} -pre #{outdir}/iqtree -ft #{outdir1}/iqtree.contree -nt #{cpu} -bb 1000 -mdef #{mdef}`
  else
    `iqtree -redo -s #{infile} -m LG+#{model}+G+F -pre #{outdir}/iqtree -ft #{outdir1}/iqtree.contree -nt #{cpu} -bb 1000`
end


