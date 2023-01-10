#! /usr/bin/env ruby


#########################################################
dir = File::dirname($0)
$: << File.join(dir, 'lib')


#########################################################
require 'getoptlong'

require 'Dir'
require 'procManage'
require 'basics'


#########################################################
$COMPHOMOGTEST = File.join(dir, 'compHomogTest.py')
$FDR_CORRECT = File.join(dir, 'additional_scripts', 'fdr_correction0.py')
$MODIFY_SEQ_TITLE_SED = File.join(dir, 'additional_scripts', 'modifySeqTitle.sed')


#########################################################
infiles = Array.new
indir = nil
outdir = nil
test_outdir = nil
aln_outdir = nil
failed_outdir = nil
suffix = 'aln'
arg_str = nil
pvalue_cutoff = 0.05
qvalue_cutoff = nil
is_fdr = false
cpu = 2
numMin = 2
is_output_aln = false
is_run_CHT = true
is_force = false
is_tolerate = false


pvalue_cutoff_info = Hash.new

# Examples for args
# -c bionj --nSims 1000 --rateModel wag --compModel wag


#########################################################
def runCompHomogTest(infiles, outdir, arg_str, cpu, is_run_CHT)
  cmds = Array.new
  outfiles = Array.new
  tree_tmp_dir = File.join(outdir, 'tmp')
  mkdir_with_force(tree_tmp_dir) unless Dir.exists?(tree_tmp_dir)

  infiles.each do |infile|
    c = getCorename(infile)
    copy_infile = File.join(outdir, c+'.fas')
    `cp #{infile} #{copy_infile}`
    #`sed -i '/^>/s/[-|]/_/g' #{copy_infile}`
    `sed -i -f #{$MODIFY_SEQ_TITLE_SED} #{copy_infile}`
    outfile = File.join(outdir, c+'.compHomogTest')
    #cmds << Proc.new{ system("#{$COMPHOMOGTEST} -d #{copy_infile} --tree_tmp_dir #{tree_tmp_dir} #{arg_str} 1>#{outfile}; rm #{copy_infile}") }
    cmds << Proc.new{ system("#{$COMPHOMOGTEST} -d #{copy_infile} --tree_tmp_dir #{tree_tmp_dir} #{arg_str} 1>#{outfile}") }
    outfiles << outfile
  end

  backgroundRunTask(cmds, cpu) if is_run_CHT

  return(outfiles)
end


def isCompHomogTestPass?(outfiles, pvalue_outfiles, is_fdr, pvalue_cutoff_info)
  pvalue_info = Hash.new
  numTruesInfo = Hash.new
  pvalue_out_fhs = Hash.new

  outfiles.each do |outfile|
    c = getCorename(outfile)
    pvalue_info[c] = getPvalues(outfile, pvalue_cutoff_info.keys)
  end

  if is_fdr
    pvalue_info = getQvalueInfo(pvalue_info)
  end

  pvalue_outfiles.each_pair do |type, pvalue_outfile|
    pvalue_out_fhs[type] = File.open(pvalue_outfile, 'w')
  end

  pvalue_info.each_pair do |c, pvalue_tmp_info|
    # is hetero
    numTruesInfo[c] = pvalue_tmp_info.keys.map{|type|pvalue_tmp_info[type] >= pvalue_cutoff_info[type]}.count{|i|i == true}
    pvalue_tmp_info.each_pair do |type, p|
      pvalue_out_fhs[type].puts [c, pvalue_tmp_info[type]].join("\t")
    end
  end
  
  pvalue_out_fhs.map{|k,v| v.close }

  return([pvalue_info, numTruesInfo])
end


def getPvalues(infile, types)
  pvalue_tmp_info = Hash.new
  in_fh = File.open(infile, 'r')
  isStartReading = false
  in_fh.each_line do |line|
    line.chomp!
    if line =~ /^# Output$/
      isStartReading = true and next
    end
    if isStartReading
      line_arr = line.split("\t")
      type = line_arr[0].to_sym
      pvalue = line_arr[1].to_f
      next if not types.include?(type)
      pvalue_tmp_info[type] = pvalue
    end
  end
  in_fh.close
  return(pvalue_tmp_info)
end


def getQvalueInfo(pvalue_info)
  qvalues = Hash.new{|h,k|h[k]=[]}

  pvalue_info.each_pair do |c, v|
    v.each_pair do |type, pvalue|
      qvalues[type] << pvalue
    end
  end

  qvalues.each_pair do |type, arr|
    pvalue_str = arr.join(',')
    qvalue_str = `#{$FDR_CORRECT} --num #{pvalue_str}`.chomp
    qvalues[type] = qvalue_str.split(',').map{|i|i.to_f}
  end

  pvalue_info.each_pair do |c, v|
    v.each_key do |type|
      pvalue_info[c][type] = qvalues[type].shift
    end
  end

  return(pvalue_info)
end


def get_pvalue_cutoffs(value)
  pvalue_cutoff_info = Hash.new
  value.split(',').each do |v|
    type, pvalue_cutoff = v.split(':')
    pvalue_cutoff_info[type.to_sym] = pvalue_cutoff.to_f
  end
  return(pvalue_cutoff_info)
end


def getFinalRes(numTruesInfo, numMin)
  finalRes = Hash.new
  numTruesInfo.each_pair do |c, num|
    v = (num >= numMin) ? true : false
    finalRes[c] = v
  end
  return(finalRes)
end


def outputRes(infiles, finalRes, aln_outdir, failed_outdir)
  infiles.each do |infile|
    c = getCorename(infile)
    if finalRes[c]
      `cp #{infile} #{aln_outdir}`
    else
      `cp #{infile} #{failed_outdir}`
    end
  end
end


#########################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
  ['--arg', GetoptLong::REQUIRED_ARGUMENT],
  ['-p', GetoptLong::REQUIRED_ARGUMENT],
  ['-q', GetoptLong::REQUIRED_ARGUMENT],
  ['-n', GetoptLong::REQUIRED_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--no_run_CHT', GetoptLong::NO_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--tolerate', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^-i$/
      infiles << value.split(',')
    when /^--indir$/
      indir = value
    when /^--outdir$/
      outdir = value
    when /^--suffix$/
      suffix = value
    when /^--arg$/
      arg_str = value
    when /^-p$/
      pvalue_cutoff_info = get_pvalue_cutoffs(value)
    when /^-q$/
      pvalue_cutoff_info = get_pvalue_cutoffs(value)
      is_fdr = true
    when /^-n$/
      numMin = value.to_i
    when /^--cpu$/
      cpu = value.to_f
    when /^--no_run_CHT$/
      is_run_CHT = false
      is_tolerate = true
    when /^--force$/
      is_force = true
  end
end


#########################################################
if numMin.nil?
  STDERR.puts "-n has to be a positive integer."
  exit(1)
end


mkdir_with_force(outdir, is_force, is_tolerate)

test_outdir = File.join(outdir, 'testRes')
aln_outdir = File.join(outdir, 'aln')
failed_outdir = File.join(outdir, 'failed_aln')
mkdir_with_force(test_outdir, is_force, is_tolerate)
mkdir_with_force(aln_outdir, is_force, is_tolerate)
mkdir_with_force(failed_outdir, is_force, is_tolerate)

pvalue_outfiles = {:chi2=>File.join(outdir,'chi2.pvalue'), :sim=>File.join(outdir,'sim.pvalue')}


#########################################################
infiles = read_infiles(indir, suffix) if not indir.nil?

outfiles = runCompHomogTest(infiles, test_outdir, arg_str, cpu, is_run_CHT)

pvalue_info, numTruesInfo = isCompHomogTestPass?(outfiles, pvalue_outfiles, is_fdr, pvalue_cutoff_info)

finalRes = getFinalRes(numTruesInfo, numMin)

if not aln_outdir.nil?
  outputRes(infiles, finalRes, aln_outdir, failed_outdir)
else
  finalRes.keys.map{|k|puts [k, finalRes[k]].join("\t")}
end


