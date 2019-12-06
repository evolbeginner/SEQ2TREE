#! /bin/env ruby


def getCorename(infile)
  b = File.basename(infile)
  b =~ /(.+)\..+$/
  c = $1
  return(c)
end


