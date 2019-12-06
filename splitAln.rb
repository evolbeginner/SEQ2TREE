#! /usr/bin/env ruby


##########################################################
require 'getoptlong'
require 'bio'

require 'SSW_bio'
require 'Dir'


##########################################################
aln_file = nil
partition_file = nil
outdir = nil
is_force = false

gene2range = Hash.new


##########################################################
opts = GetoptLong.new(
  ['--aln', GetoptLong::REQUIRED_ARGUMENT],
  ['-p', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '--aln'
      aln_file = value
    when '-p'
      partition_file = value
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
  end
end


##########################################################
mkdir_with_force(outdir, is_force)


##########################################################
is_start = false
in_fh = File.open(partition_file, 'r')
in_fh.each_line do |line|
  #[data_blocks]
  #mito-MitoCOG0059 = 1-415
  line.chomp!
  if line == '[data_blocks]'
    is_start = true
    next
  end
  break if line =~ /^## SCHEMES/
  if is_start
    gene, range = line.split(' = ')
    gene2range[gene] = range.split('-').map{|i|i.to_i}
  end
end
in_fh.close


##########################################################
seqObjs = read_seq_file(aln_file)

gene2range.each_pair do |gene, range|
  index1, index2 = [range[0]-1, range[1]-1]
  outfile = File.join(outdir, gene+'.aln')
  out_fh = File.open(outfile, 'w')
  seqObjs.each_pair do |title, obj|
    out_fh.puts '>'+title
    out_fh.puts obj.seq[index1, index2-index1+1]
  end
  out_fh.close
end


