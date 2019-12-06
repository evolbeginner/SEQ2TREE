#! /usr/bin/env ruby


####################################################
require 'getoptlong'

require 'Dir'
require 'SSW_bio'
require 'util'


####################################################
indir = nil
outdir = nil
is_force = false
min = 1

seq_objs = Hash.new{|h,k|h[k]={}}
basenames = Array.new


####################################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--min', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '--indir'
      indir = value
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
    when '--min'
      min = value.to_i
  end
end


####################################################
mkdir_with_force(outdir, is_force)

infiles = read_infiles(indir)

infiles.each do |infile|
  b = File.basename(infile)
  basenames << b
  seq_objs0 = read_seq_file(infile)  
  seq_objs0.each do |k,f|
    seq_objs[k][b] = f
  end
end


####################################################
puts "Before removing:\t#{seq_objs.size}"

seq_objs.delete_if{|seqTitle, v| v.size < min }

puts "After removing:\t#{seq_objs.size}"

basenames.each do |b|
  outfile = File.join(outdir, b)
  out_fh = File.open(outfile, 'w')
  seq_objs.each_pair do |seqTitle, v|
    next unless v.include?(b)
    out_fh.puts '>' + seqTitle
    out_fh.puts v[b].seq
  end
  out_fh.close
end


