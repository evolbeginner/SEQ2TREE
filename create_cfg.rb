#! env ruby


############################################################################
dir = File.dirname($0)
lib_path = File.join(dir, 'lib')
$LOAD_PATH.unshift(lib_path)



############################################################################
require 'getoptlong'

require 'bio'

require 'SSW_bio'
require 'Dir'
require 'basics'


############################################################################
@CATALN = File.join(File.dirname($0), "catAln.rb")

ADDITIONAL_SCRIPTS_PATH = File.join(dir, 'additional_scripts')
@MFAtoPHY = File.join(ADDITIONAL_SCRIPTS_PATH, 'MFAtoPHY.pl')


############################################################################
infiles = Array.new
indir = nil
suffix = nil
num = 1
cfg_outfile = nil
aln_outfile = nil
model_selections = %W[aicc]
search = 'rcluster'
isMFAtoPHY = false


############################################################################
def convertMFAtoPHY(aln_outfile)
  `#{@MFAtoPHY} #{aln_outfile}`
  phy_outfile = aln_outfile + '.phy'
  c = getCorename(aln_outfile)
  d = File.dirname(aln_outfile)
  new_phy_outfile = File.join(d, c+'.phy')
  `mv #{phy_outfile} #{new_phy_outfile}`
  return (new_phy_outfile)
end


############################################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--suffix', GetoptLong::REQUIRED_ARGUMENT],
  ['-n', GetoptLong::REQUIRED_ARGUMENT],
  ['--cfg', '--cfg_out', '--cfg_outfile', GetoptLong::REQUIRED_ARGUMENT],
  ['--aln', '--aln_out', '--aln_outfile', GetoptLong::REQUIRED_ARGUMENT],
  ['--model_selection', GetoptLong::REQUIRED_ARGUMENT],
  ['--search', GetoptLong::REQUIRED_ARGUMENT],
  ['--mfa2phy', '--MFA2PHY', '--MFAtoPHY', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^-i$/
      value.split(',').map{|i|infiles << i}
    when /^--indir$/
      indir = value
    when /^--suffix$/
      suffix = value
    when '-n'
      num = value.to_i
    when /^--(cfg|cfg_out|cfg_outfile)$/
      cfg_outfile = value
    when /^--(aln|aln_out|aln_outfile)$/
      aln_outfile = value
    when /^--model_selection$/
      value.split(',').map{|i|model_selections << i}
    when /^--(mfa2phy|MFA2PHY|MFAtoPHY)$/
      isMFAtoPHY = true
  end
end


if aln_outfile.nil?
  STDERR.puts "aln_outfile has to be given. Exiting ......"
  exit 1
end


############################################################################
if not indir.nil?
  infiles = read_infiles(indir, suffix)
end

infiles.flatten!

if infiles.empty?
  puts "Error! Infiles have to be given! Exiting ......"
  exit 1
end


############################################################################
i_argu = infiles.map{|i|['-i', i].join(' ')}.join(' ')
system("ruby #{@CATALN} #{i_argu} -n #{num} > #{aln_outfile}")

if isMFAtoPHY
  aln_outfile = convertMFAtoPHY(aln_outfile) # from fasta to phy
end

if ! cfg_outfile.nil?
  out_fh = File.open(cfg_outfile, 'w')
else
  out_fh = STDOUT
end


############################################################################
out_fh.puts "## ALIGNMENT FILE ##"
out_fh.puts "alignment = " + File.basename(aln_outfile) + ';'

out_fh.puts "## BRANCHLENGTHS: linked | unlinked ##"
out_fh.puts "branchlengths = linked;"

out_fh.puts "## MODELS OF EVOLUTION: all | allx | mrbayes | beast | gamma | gammai | <list> ##"
out_fh.puts "models = LG+G, LG+I+G, WAG+G, WAG+I+G;"

out_fh.puts "# MODEL SELECCTION: AIC | AICc | BIC #"
out_fh.puts "model_selection = " + model_selections.join(',') + ';';

out_fh.puts "## DATA BLOCKS: see manual for how to define ##"
out_fh.puts "[data_blocks]"
start = 0
infiles.each do |infile|
  c = getCorename(infile)
  c.gsub!('-', '') # IF-2 changes to IF-2 to avoid bugs in -p best_scheme.nex --joint-model NONREV
  aln_length = get_aln_length(infile)
  start += 1
  stop = start + aln_length - 1
  range = [start, stop].join('-')
  out_fh.puts [c, range].join(' = ')
  start = stop
#  COI     =   1-407
#  COII    =   408-624
end

out_fh.puts "## SCHEMES, search: all | user | greedy | hcluster | rcluster | kmeans ##"
out_fh.puts "[schemes]"
out_fh.puts "search = " + search + ';'


