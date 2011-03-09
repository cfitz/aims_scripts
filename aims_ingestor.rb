#!/usr/bin/env ruby
require 'FileUtils'

  obj = '/tmp/Full_House'

  Dir["#{obj}/**/**"].each do |f|
    
  
=begin    
    # convert html file into PS file
    if f.include?('.htm')
      fout = File.join(File.dirname(f), File.basename(f, '.htm'))
      s = system("perl /usr/local/bin/html2ps -f /Users/cfitz/Downloads/html2ps-1.0b7/sample -o  #{fout}.ps  #{f}")
      puts s
    end
=end

=begin
   #convert ps file into jp2000
    if f.include?('.ps')
       fout = File.join(File.dirname(f), "page.jp2")
       s = system("convert #{f} #{fout}")
   end
=end

=begin
   # imageMAgick starts with 0 for pages, which we don't want...   
   if f.include?('.jp2')
   
      fbase = File.basename(f, '.jp2')
      fparts = fbase.split('-')
      num = fparts[1].to_i + 1
      newname = fparts[0] + '-' + num.to_s + '.jp2'
      FileUtils.mkdir_p(File.join('/tmp', File.dirname(f)))
      fout = File.join('/tmp', File.dirname(f), newname)
      FileUtils.move f, fout,  :verbose => true   
   end
=end

=begin
    #convert ps to pdf
   if f.include?('.ps')
      fname = File.basename(f, '.ps') + ".pdf"
      fout = File.join(File.dirname(f), fname)
      s = system("ps2pdf #{f} #{fout}")
  end
=end

  if f.include?('.jp2')
    
    jp2name = File.basename(f, '.jp2')
    jp2part = jp2name.split("-")
    num = jp2part[1]
    
    Dir["#{File.dirname(f)}/*.pdf"].each do |f|
       out = File.join()    
       pdf = `pdftotext -f #{num} -l #{num} -layout  #{f} #{File.dirname(f)}/page-#{num}.txt`
       puts pdf
    end
    
    
  end
   
 end
 
 
 # this moves the files back into the director
 
 