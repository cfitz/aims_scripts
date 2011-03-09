#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'

# => This is script converts html files into postscript files, which are needed for the 
#    This requires: perl 
#    html2ps perl script and the sample profile  ( http://user.it.uu.se/~jan/html2ps.html )
#    ps2pdf to convert Postscripts to PDF (http://www.ps2pdf.com/)
#    imagicemagik with jasper/jp2000 libraries installed (http://www.imagemagick.org)


# Step 3
#   ./convert_ojects.rb /tmp/testout

class ConvertObjects

  attr_accessor :source

  def initialize(source=nil)
    if !source.nil? and File.exists?(source)
      @source = source
    else
      raise "You must provide either a html file or a directory of html files"
    end
  end
  
  def process()
      if File.directory?(source)
        processDirectory(source)
      else
        processFile(source)
      end
  end #process
  
  # this method takes a string pointing to a directory and processes it to the ps conversion. 
  def processDirectory(directory)
    Dir["#{directory}/**/*.htm", "#{directory}/**/*.html"].each do |f|
      processFile(f)  
    end
  end #processDirectory
  
  
  # this method processes the file taking a string pointing to its path
  def processFile(file)
     if file.include?(".html")
       base = File.basename(file, ".html")
     else
       base = File.basename(file, ".htm")
     end
     
     psFile = File.join(File.dirname(file), base) + ".ps"
     removeGif(file) #remove the watermark gif
     
     system( "perl ./html2ps/html2ps -f ./html2ps/sample -o  #{psFile.dump} #{file.dump}") #convert to .ps
     system("convert #{psFile.dump} #{File.join(File.dirname(psFile), "XXZZYY.jp2")}") #convert to jpeg2000
     
     fixJp2PageNumbers(File.dirname(psFile)) #ImageMagik page numbers are off by one. this correct that. 
     convertPsToPdf(File.dirname(psFile)) #Converts Postscript files into a PDF file.
     convertPsToText(File.dirname(psFile)) #convert Postscript files into a text file
  
  rescue Exception => e  
      puts e
  end #processFile
  
  
  
  # This is a method to remove a gif that the forensic toolkit adds to the HTML for watermarking. We don't want this. 
  def removeGif(file)
    
    doc = Nokogiri::HTML(open(file))
    doc.search("//a[@href='http://www.avantstar.com']").each {|g| g.remove }
    
    doc.search("//img").each {|j| puts j }
    
    
    output = File.open(file,'w')
    output << doc.to_xml
    output.close
  
  end #removeGif
  
  # Correct ImageMagik's page numbering 
  def fixJp2PageNumbers(directory)
    Dir["#{directory}/**/*.jp2"].each do |f|
        
       if f.include?('.jp2')
        #if there is no dash, its a one page documnet. we still need the -1. 
        if f.include?('-')
          fbase = File.basename(f, '.jp2')
          fparts = fbase.split('-')
          num = fparts[1].to_i + 1
          newname = fparts[0] + '-' + num.to_s + '.jp2'
        else
          newname =  File.basename(f, '.jp2') + '-1.jp2'
        end
        
        newname.gsub!("XXZZYY", "page")
        FileUtils.mv f, File.join(File.dirname(f), newname),  :verbose => true   
       
      end #if f.include?('.jp2')
     
    end #Dir["#{directory}/**/*.jp2"].each 
  end #fixJp2PageNumbers
  
  
  #Take the object directory, finds the postscripts,  and convert them to PDF files
  def convertPsToPdf(directory)
    Dir["#{directory}/**/*.ps"].each do |f| 
      if f.include?('.ps')
          fname = File.basename(f, '.ps') + ".pdf"
          fout = File.join(File.dirname(f), fname)
          system("ps2pdf #{f.dump} #{fout.dump}")
      end #f.include?
    end #DIR
  end  #convertPsToPdf
  
  
  
  # Takes the object directory, finds the postscripts, and convert thems to Text files.
  def convertPsToText(directory)
    
    # pdf to text. Find each jp2, then find the pdf related to it, and export out the page. 
    Dir["#{directory}/**/*.jp2"].each do |f| 
     jp2name = File.basename(f, '.jp2')
     jp2part = jp2name.split("-")
     num = jp2part[1]

     Dir["#{File.dirname(f)}/*.pdf"].each do |pdf|
          out = File.join()    
          pdf = system("pdftotext -f #{num} -l #{num} -layout  #{pdf.dump} #{File.dirname(f).dump}/page-#{num}.txt")
     end #Dir["#{File.dirname(f)}/*.pdf"]
    end #Dir["#{directory}/**/*.jp2"]
  end #convertPsToText

 
end #class

# #========== This is the equivalent of a java main method ==========#  
if __FILE__ == $0  
   convert = ConvertObjects.new(ARGV[0])
   convert.process  
end            
