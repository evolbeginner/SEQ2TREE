#! /bin/env ruby


################################################################
dir = File.dirname($0)
lib_path = File.join(dir, 'lib')
$LOAD_PATH.unshift(lib_path)


################################################################
require 'getoptlong'

require 'bio'

require 'Dir'
require 'basics'
require 'procManage'


################################################################
@SUBMITHPC = 'submitHPC.sh'


################################################################
infiles = Array.new
indir = nil
suffixes = Array.new
outdir = nil
aligner = 'mafft'
other_outdir = nil
other_outdirs = Hash.new
cpu = 5
thread = 1
is_HPC = false
is_force = false

jid_outfiles = Array.new
cmds = Array.new


################################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--aligner', GetoptLong::REQUIRED_ARGUMENT],
  ['--other_outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--thread', GetoptLong::REQUIRED_ARGUMENT],
  ['--hpc', '--HPC', GetoptLong::NO_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT]
)


opts.each do |opt, value|
  case opt
    when /^-i$/
      value.split(',').map{|i|infiles << i}
    when /^--indir$/
      indir = value
    when /^--outdir$/
      outdir = value
    when /^--aligner$/
      aligner = value
    when /^--other_outdir$/
      other_outdir = value
    when /^--suffix$/
      suffixes << value.split(',')
    when /^--cpu$/
      cpu = value.to_i
    when /^--thread$/
      thread = value.to_i
    when /^--(hpc|HPC)$/
      is_HPC = true
    when /^--force$/
      is_force = true
  end
end


suffixes.flatten!


if outdir.nil?
  STDERR.puts "--outdir not specified! Exiting ......"; exit 0
end

mkdir_with_force(outdir, is_force)

if is_HPC
  if other_outdir.nil?
    STDERR.puts "--other_outdir not specified! Exiting ......"; exit 0
  end
  other_outdirs[:lsf] = File.join(other_outdir, 'lsf')
  other_outdirs[:bsub] = File.join(other_outdir, 'bsub')
  other_outdirs[:jid] = File.join(other_outdir, 'jid')
  other_outdirs.each_value do |v|
    `mkdir -p #{v}`
  end
end


################################################################
if not indir.nil?
  infiles = read_infiles(indir, suffixes)
end

infiles.flatten!

if infiles.empty?
  puts "Error! Infiles have to be given! Exiting ......"
  exit 1
end


################################################################
infiles.each_with_index do |infile, index|
  c = getCorename(infile)
  outdir = File.dirname(infile) if outdir.nil?
  aln_outfile = File.join(outdir, c+'.aln')

  if is_HPC
    lsf_outfile = File.join(other_outdirs[:lsf], c+'.lsf')
    bsub_outfile = File.join(other_outdirs[:bsub], c+'.bsub')
    jid_outfile = File.join(other_outdirs[:jid], c+'.jid')
    jid_outfiles << jid_outfile
    cmd = "\`#{@SUBMITHPC} --cmd 'mafft #{infile} > #{aln_outfile}' -n #{thread} --lsf #{lsf_outfile} --do --force --bsub #{bsub_outfile} --jid_out #{jid_outfile}\`"
  else
    #cmd = "system \"mafft --quiet --thread #{thread} #{infile} > #{aln_outfile}\""
    case aligner
      when 'mafft'
        num_of_seqs = `sed '/>/!d' #{infile} | wc -l | awk '{print $1}'`.to_i
        if num_of_seqs <= 3000
          cmd = Proc.new{`mafft --anysymbol --quiet --thread #{thread} #{infile} > #{aln_outfile}`}
        else # for many many genes
          cmd = Proc.new{`mafft --anysymbol --quiet --thread #{thread} --parttree --retree 1 #{infile} > #{aln_outfile}`}
        end
      when 'muscle'
        cmd = Proc.new{`muscle -quiet -in #{infile} -out #{aln_outfile}`}
    end
  end
  cmds << cmd
end


################################################################
if is_HPC
  backgroundRunHPC(cmds, jid_outfiles, cpu)
else
  backgroundRunTask(cmds, cpu)
end


