#! /usr/bin/env ruby


require 'getoptlong'

require 'bio'

require 'SSW_bio'
require 'Dir'


#########################################################
indir = nil
infiles = Array.new
suffix = nil
outfile = nil
num = 1

seq_objs = Hash.new{|h,k|h[k]={}}
aln_info = Hash.new{|h,k|h[k]=[]}
combined_objs = Hash.new{|h,k|h[k]=[]}


#########################################################
def examine_aln(aln_info)
  all_definitions = Array.new
  aln_info.each_pair do |index, arr|
    if not arr.all?{|f|f.seq.size == arr[0].seq.size}
      STDERR.puts "Fatal error! The infile No. #{index+1} is not aligned."
      STDERR.puts "Exiting ......"
      exit(1)
    else
      arr.each do |f|
        all_definitions << f.definition
      end
    end
  end
  return(all_definitions)
end


#########################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
  ['-o', '--out', GetoptLong::REQUIRED_ARGUMENT],
  ['-n', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^-i$/
      infiles << value.split(',')
    when /^--indir$/
      indir = value
    when /^--suffix$/
      suffix = value
    when /^(-o|--out)$/
      outfile = value
    when '-n'
      num = value.to_i
  end
end


out_fh = outfile.nil? ? STDOUT : File.open(outfile, 'w')


#########################################################
if not indir.nil?
  infiles = read_infiles(indir, suffix)
end

infiles.flatten!

if infiles.empty?
  puts "Error! Infiles have to be given! Exiting ......"
  exit 1
end


#########################################################
seq_objs = read_alns_into_2D_hash(infiles)
aln_info = read_alns_into_aln_info(infiles)

all_definitions = examine_aln(aln_info).uniq!


#########################################################
seq_objs.each_pair do |definition, v|
  next if ((0..infiles.size-1).select{|i|v.include?(i)}).size < num
  0.upto(infiles.size-1) do |index|
    seq = nil
    if v.include?(index)
      seq = v[index].seq
    else
      seq = Array.new(aln_info[index][0].seq.size, '-').join('')
    end
    combined_objs[definition] << seq
  end
end


combined_objs.each_pair do |definition, arr|
  out_fh.puts '>' + definition
  out_fh.puts arr.join('')
end

out_fh.close if out_fh != STDOUT


