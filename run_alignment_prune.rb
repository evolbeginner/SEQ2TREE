#! /bin/env ruby


#####################################################
DIR = File.dirname(__FILE__)


#####################################################
require 'getoptlong'
require 'parallel'

require 'Dir'
require 'util'


#####################################################
indir = nil
outdir = nil
is_force = false
cpu = 1

ALIGNMENT_PRUNER = File.join(DIR, "additional_scripts", "alignment_pruner.pl")
TRIMAL = File.expand_path("~/software/sequence_analysis/trimal/source/trimal")


#####################################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT]
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
  end
end


#####################################################
chi2_outdir = File.join(outdir, 'chi2')
aln_outdir = File.join(outdir, 'aln')
site_pruned_outdir = File.join(outdir, "site_pruned_aln")
site_pruned_chi_outdir = File.join(outdir, "site_pruned_chi_aln")

mkdir_with_force(outdir, is_force)
mkdir_with_force(chi2_outdir, is_force)
mkdir_with_force(aln_outdir, is_force)
mkdir_with_force(site_pruned_outdir, is_force)


#####################################################
infiles = read_infiles(indir)

Parallel.map(infiles, in_threads: cpu) do |infile|
  b = File.basename(infile)
  c = getCorename(b)

  chi2_outfile = File.join(chi2_outdir, c+'.chi2')
  `perl #{ALIGNMENT_PRUNER} --file #{infile} --chi2_test documentation | awk 'BEGIN{OFS="\t"}{print $1,$2,$3,$4}' | sort -t $'\t' -nk 3 > #{chi2_outfile}`

  exclude_list = File.join(chi2_outdir, c+'.exclude_list')
  `sed "/\*$/!d" #{chi2_outfile} | cut -f2 | sed 's!^!/^!; s!$!/!' > #{exclude_list}`
  #`tail -n 70 #{chi2_outfile} | cut -f2 | sed 's!^!/^!; s!$!/!' > #{exclude_list}`

  aln_outfile = File.join(aln_outdir, c+'.aln')
  `ruby ~/tools/self_bao_cun/basic_process_mini/get_subseq.rb -i #{infile} --seq_excluded_from_file #{exclude_list} > #{aln_outfile}`

  # remove columns with all gaps
  `#{TRIMAL} -in #{aln_outfile} -noallgaps | sponge #{aln_outfile}`

  0.upto(9).each do |i|
    sub_outdir1 = File.join(site_pruned_outdir, '0.'+i.to_s); mkdir_with_force(sub_outdir1, false, true)
    sub_outdir2 = File.join(site_pruned_chi_outdir, '0.'+i.to_s); mkdir_with_force(sub_outdir2, false, true)
    site_pruned_outfile = File.join(sub_outdir1, b)
    site_pruned_chi_outfile = File.join(sub_outdir2, b)

    p = i == 0 ? 0.001 : '0.'+i.to_s
    # trimed
    `perl #{ALIGNMENT_PRUNER} --file #{infile} --chi2_prune f#{p} > #{site_pruned_outfile}`
    # untrimmed
    `perl #{ALIGNMENT_PRUNER} --file #{aln_outfile} --chi2_prune f#{p} > #{site_pruned_chi_outfile}`
  end
end


