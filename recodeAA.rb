#! /usr/bin/env ruby


###################################################################
DIR = File.dirname(__FILE__)


###################################################################
require 'getoptlong'
require 'bio'

require 'SSW_bio'


###################################################################
$AAs = %w[A R N D C Q E G H I L K M F P S T W Y V]

infile = nil
method = nil
template = nil
template2 = nil
template_file = nil
is_output_model = false


###################################################################
COMBO = Hash.new
COMBO[:SR4] = {'[AGNPST]'=>'A', '[CHWY]'=>'C', '[DEKQR]'=>'G', '[FILMV]'=>'T'}
COMBO[:dayhoff4] = {'[C]'=>'?', '[AGPST]'=>'A', '[DENQ]'=>'C', '[HKR]'=>'G', '[FYWILMV]'=>'T'}


###################################################################
def recodeAA(seq_objs, method, combo)
  seq_objs.each_pair do |title, seq_obj|
    seq_obj.seq.upcase!
    combo.each_pair do |k, v|
      regexp = Regexp.new(k)
      begin
        seq_obj.seq.gsub!(regexp, v).chomp!
      rescue Exception => e
        ;
      end
    end
    seq_objs[title] = seq_obj
  end
  return(seq_objs)
end


def readTemplateFile(infile, nuc2aa)
  names = Array.new
  name2freq = Hash.new{|h,k|h[k]={}}
  new_name2freq = Hash.new{|h,k|h[k]={}}

  in_fh = File.open(infile, 'r')
  in_fh.each_line do |line|
    line.chomp!
#frequency C10pi1 = 0.4082573125 0.0081783015 0.0096285438 0.0069870889 0.0349388179 0.0075279735 0.0097846653 0.1221613215 0.0039151830 0.0125784287 0.0158338663 0.0059670150 0.0081313216 0.0061604332 0.0394155867 0.1682450664 0.0658132542 0.0018751587 0.0041579747 0.0604426865;
    if line =~ /^frequency/
      name, freq_str = line.split(' = ')
      names << name
      freq_str.sub(/;$/, '')
      freqs = freq_str.split(' ').map{|i|i.to_f}
      $AAs.zip(freqs).each do |aa, freq|
        name2freq[name][aa] = freq
      end
    end
  end
  in_fh.close

  names.each do |name|
    nuc2aa.each_pair do |nuc, aas|
      new_name2freq[name][nuc] = aas.map{|aa| name2freq[name][aa] }.sum
    end
    sum_freq = new_name2freq[name].select{|aa,freq|aa=~/\w/}.map{|aa, freq| freq}.sum
    new_name2freq[name].each_pair do |nuc, freq|
      new_name2freq[name][nuc] = freq/sum_freq
    end
  end

  return([name2freq, new_name2freq])
end


def parseCombo(combo)
  nuc2aa = Hash.new
  combo.each_pair do |k, v|
    a = k.gsub(/[\[\]]/, '')
    nuc2aa[v] = a.split('')
  end
  return(nuc2aa)
end


def output_new_name2freq(new_name2freq, template, template2)
  aas = %w[A C G T]

  puts <<EOF
#nexus
begin models;
EOF

  new_name2freq.each_pair do |name, v1|
    puts [name.sub('pi', template2), '=', aas.map{|aa| v1[aa] }].flatten.join(' ') + ';'
  end

  new_template = template + template2
  fmix = '{' + new_name2freq.keys.map{|i|i.sub('frequency ', '').sub('pi', template2)}.join(',') + '}'
  puts ['model ', new_template + '=GTR+G+FMIX' + fmix + '+F' + ';'].join('')
  puts 'end;'
  exit
end


###################################################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['-m', GetoptLong::REQUIRED_ARGUMENT],
  ['-t', GetoptLong::REQUIRED_ARGUMENT],
  ['--name', GetoptLong::REQUIRED_ARGUMENT],
  ['--output_model', GetoptLong::NO_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '-i'
      infile = value
    when '-m'
      method = value.to_sym
    when '-t'
      template = value
    when '--name'
      template2 = value
    when '--output_model'
      is_output_model = true
  end
end


###################################################################
# create template
template2 = method.to_s if template2.nil?

if not template.nil?
  template_file = File.join(DIR, 'template', template)
  nuc2aa = parseCombo(COMBO[method])
  name2freq, new_name2freq = readTemplateFile(template_file, nuc2aa)
  if is_output_model
    output_new_name2freq(new_name2freq, template, template2)
    exit
  else
    ;
  end
end


###################################################################
seq_objs = read_seq_file(infile)

new_seq_objs = recodeAA(seq_objs, method, COMBO[method])


new_seq_objs.each_pair do |title, seq_obj|
  puts '>'+title
  puts seq_obj.seq
end


