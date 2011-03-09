#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'fastercsv'
#
# This script is used to convert output files from the forensic toolkit into a directory that is easier to ingest into 
# fedora. 
# Point the @convert_directory to the directory of 'convert' files, which contain images and html exports of the source documents 
# It assumes that you'll be recieving a csv file being output from the html_to_csv. 
#

# Step 2
#  ./reorg_directory.rb /tmp/testout /tmp/Chris_08_27/Gould_08_27_xml/ /tmp/Chris_08_27/Gould_Convert_08_27/ Gouldoutput.csv 

class ReorgDirectory

  attr_accessor :output_directory
  attr_accessor :source_directory
  attr_accessor :convert_directory
  attr_accessor :csv
  
  def initialize(output_directory=nil, source_directory=nil, convert_directory=nil, csv=nil)
    
       if output_directory.nil? or csv.nil? or convert_directory.nil? or source_directory.nil?
          raise "You must pass a output directory, output directory, convert directory, and csv object." 
       elsif File.exists?(csv) && File.exists?(convert_directory) && File.exists?(source_directory)
         @output_directory = output_directory # this is the directory you want to build fedora objects
         @convert_directory = convert_directory # this directory has the converted jpgs,htmls,ect
         @source_directory = source_directory # this directory has the source files from the collection
         @csv = csv # this is the cvs file created by the html_to_csv script
       else
         raise " #{convert_directory}, #{source_directory}, or #{csv} do not exist."
       end

  end #intialize
  
  
  # This is the primary method to process the CSV file.   
  def process()
    FasterCSV.foreach(@csv, :headers => true ) do |row|
      file = row["exportedAs"].gsub('\\', '/') #this is the name of the file we need to make into an object
      file_base = File.basename(file, File.extname(file)) #this is the source file without its extension
      source_file = File.join(@source_directory, file ) #this is the full path location of the source file
      if File.exists?(source_file)
        directory = createDirectory(file) #make the directory
        copyFile(source_file, directory)  #put the source file in the directory
        
        unless source_file.include?("JPG") #some of the files are jpegs, which have html files that only contain links to the JPEG and not any fulltext. These are useless and we don't want them. 
          copyFiles(file_base, directory)   #move the converted files into the directory
        end #unless
        
      end #if File.exists
    end #FasterCSV     
  end #process
 

  # Make a directory for each file for all files. It takes a string to build the propert structure.
  def createDirectory(file)
      directory = File.join(@output_directory, File.basename(file))  
      FileUtils.mkdir_p(directory)
      directory      
  end #createDirectory
  
  # Moves the  file to a directory. Takes a string of the source file and the output directory
  def copyFile(file, directory)
    if File.exists?(file) and File.exists?(directory)
      FileUtils.cp(file, directory, :verbose => true)
      true
    else
      false
    end
  end #copySource
  
  # Copy all the pertainent files from the source directory into the new output directory. It takes a string of the base file and the directory to move the files into.  
  def copyFiles(file_base, directory)
    exts = [".html", ".htm"] # these are currently the file formats needing to be moved. 
    
    exts.each do |ext|
      file = File.join(@convert_directory, "#{file_base}#{ext}") 
      copyFile(file, directory)
    end #exts.each
    
  end
  
    
end #class ReorgDirectory

# #========== This is the equivalent of a java main method ==========#  
if __FILE__ == $0  
   reorg = ReorgDirectory.new(ARGV[0], ARGV[1], ARGV[2], ARGV[3])  
   reorg.process  
end            


