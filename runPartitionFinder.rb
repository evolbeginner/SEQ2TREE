#! env ruby


require 'getoptlong'


####################################################################
$partitionFinder = "/home-user/software/partitionFinder/partitionfinder-2.1.1/PartitionFinder.py"
$partitionFinderProtein = "/home-user/software/partitionFinder/partitionfinder-2.1.1/PartitionFinderProtein.py"


####################################################################
type = nil
additional_argu = ''

prog = nil


####################################################################
opts = GetoptLong.new(
  ['--type', GetoptLong::REQUIRED_ARGUMENT],
  ['--argu', '--additional_argu', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^--type$/
      type = value
    when /^--(argu|additional_argu)$/
      additional_argu = value
  end
end


####################################################################
if type == 'protein'
  prog = $partitionFinderProtein
elsif type == 'DNA'
  prog = $partitionFinder
else
  raise "--type Wrong! Exiting ......"
end


####################################################################
`python #{prog} #{additional_argu} 2>/dev/null`


