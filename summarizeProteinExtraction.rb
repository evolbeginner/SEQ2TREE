#! /usr/bin/env ruby


##########################################################
require 'getoptlong'

require 'Dir'
require 'SSW_bio'


##########################################################
indir = nil


##########################################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when /^--indir$/
      indir = value      
  end
end


##########################################################
infiles = read_infiles(indir)

infiles.each do |infile|
  
end




