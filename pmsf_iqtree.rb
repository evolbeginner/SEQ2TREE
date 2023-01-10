#! /usr/bin/env ruby


######################################################
require 'getoptlong'

require 'Dir'
require 'SSW_bio'


######################################################
IQTREE="iqtree"

infile = nil
outdir = nil
model = nil
guide_tree = nil
cpu = 1
is_force = false
type = "AA"
tree_add_cmd = ''

mdef_dir = File.expand_path("~/tools/self_bao_cun/IQTREE/recoding/new_model/")


######################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['-m', '--model', GetoptLong::REQUIRED_ARGUMENT],
  ['--guide_tree', GetoptLong::REQUIRED_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--type', GetoptLong::REQUIRED_ARGUMENT],
  ['--tree_add_cmd', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--iqtree1.6', GetoptLong::NO_ARGUMENT],
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
    when '--guide_tree'
      guide_tree = value
    when '--type'
      type = value
    when '--tree_add_cmd'
      tree_add_cmd = value
    when '--cpu'
      cpu = value =~ /^\d+$/ ? value.to_i : value
    when '--iqtree1.6'
      IQTREE = "iqtree1.6"
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
if guide_tree.nil?
  outdir1 = File.join(outdir, 'guide')
  mkdir_with_force(outdir1, is_force)
  puts "building guide tree ......"
  #mrate = type =~ /DNA|NA/i ? "GTR" : "LG"
  mrate = type =~ /DNA|NA/i ? "GTR" : "LG4M"
  mrate = 'GTR' if model =~ /SR4|dayhoff4/i
  `#{IQTREE} -redo -s #{infile} -m #{mrate}+G -bb 1000 -pre #{outdir1}/iqtree -nt #{cpu} #{tree_add_cmd}`
  guide_tree = File.join(outdir1, "iqtree.treefile") #guide_tree is here!
else
  ;
end

# PMSF
puts "building pmsf tree ......"
case model
  when /SR4|dayhoff4/i
    `#{IQTREE} -redo -s #{infile} -m #{model} -pre #{outdir}/iqtree -ft #{guide_tree} -nt #{cpu} -bb 1000 -mdef #{mdef} #{tree_add_cmd} -wbtl`
  else
    `#{IQTREE} -redo -s #{infile} -m LG+#{model}+G+F -pre #{outdir}/iqtree -ft #{guide_tree} -nt #{cpu} -bb 1000 #{tree_add_cmd} -wbtl`
end


