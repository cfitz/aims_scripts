#!/usr/bin/env ruby  

require 'rubygems'
require 'nokogiri'
require 'fastercsv'

#
# => This script parse the XML files from the forensics html output
# => and creates a csv file for importing into fedora
# => Point the script toward a directory with the html bookmark files
#


# Step 1. 
#  ./html_to_csv.rb /tmp/Chris_08_27/Gould_08_27_html/ Gouldoutput.csv

class HtmlToCsv

  attr_accessor :csv
  attr_accessor :directory
  attr_accessor :output

  def initialize(directory=nil, output=nil)
      if directory.nil? or output.nil?
          raise "You must pass a directory and output file for processing"    
      elsif File.exists?(directory) 
        
         @directory = directory
         @output = output
         @csv = FasterCSV.open(@output, 'w', :headers=> true)
         header = ["subseries", "filename", "path", "size", "created", "modified", "accessed", "md5", "sha1", 
              "flagged", "labels", "comment", "type", "exportedAs"]
         @csv <<  header
            
      else
          raise "#{@directory} does not exist."
      end

  end #intialize
  
  def process()
     puts "Searching #{@directory}"
     Dir["#{@directory}/*.html"].each do |f|  
         puts  "Processing #{f} .... "
         rows = parseHTML(f)
         if rows.nil?
           next
         else
           rows.each {|row| @csv << row}
         end
     end #dir each
      
     @csv.close
  end #process
  
  # this method takes a filename globbed from the directory and returns an array with the data.
  def parseHTML(f)
        puts  "Processing #{f} .... "
        xml = Nokogiri::HTML(open(f))
      
        #first get the series name for this file. Each file has one series name
        subseriesXML = xml.search('//th[@class = "columnHead"]').first
        unless subseriesXML.nil?
            subseries = subseriesXML.content
        end
        #now iterate thru the divs, which are each a file

        spans = xml.search('//span[@class = "bkmkColRight bkmkValue"]')

        #all files should have 13 attributes (not including the subseries). 
        #If the html file has less, then there are no files described in this html file.
        print spans.length
        
        if spans.length < 13
           print "No files described in #{f} \n"
           return nil
        else
          a = spans.to_a
          rows = []
          while a.length > 12
              row = [subseries]    
              ss = a.slice!(0..12)
              ss.each {|s| row << s.content}
              rows << row
          end #while
          return rows
        end #if
  end #parseHTML
  
  
end #class
   
   
# #========== This is the equivalent of a java main method ==========#  
if __FILE__ == $0  
   html_to_csv = HtmlToCsv.new(ARGV[0], ARGV[1])  
   html_to_csv.process  
end            
      
      
      
    