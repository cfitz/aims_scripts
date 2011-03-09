#!/usr/bin/env ruby
require 'rubygems'
require 'tempfile'
require 'fastercsv'
require 'pp'
$:.unshift File.join(File.dirname(__FILE__), "..")

require  File.join(File.dirname(__FILE__), '../config/environment.rb')

RAILS_DEFAULT_LOGGER.auto_flushing = 1



# This script is used to ingest the converted objects into fedora.
# This script assumes that it is running in the script directory of a Hydra rails project and assumes
# the rails project has a AimsDocument model defined. 

# Step 4.
#  ./ingestor.rb Gouldoutput.csv /tmp/objects


class Ingestor

  def initialize(file=nil, directory=nil)

     Module.const_set("AimsDocument", AimsDocument)
     ###### The directory to be processed ######
     @file = file
     @directory = directory
     
     ###### Configuration Stuff Here #######
     @fedora_user = 'fedoraAdmin'
     @fedora_pass = 'fedoraAdmin'
     @fedora_uri = "http://#{@fedora_user}:#{@fedora_pass}@localhost:8983/fedora" #make sure there's no trailing slash.
     @fedora_ns = "druid"
     @solr_uri =  "http://localhost:8983/solr/test" #no trailing slash.

     ###### Register the Repos #######
     # => http://projects.mediashelf.us/wiki/active-fedora/ActiveFedora_Console_Tour

     ActiveFedora::SolrService.register(@solr_uri, :verify_mode=>:none)
     Fedora::Repository.register(@fedora_uri)

     ###### You can keep a list of file extension to be ingested here, with a specification of their control group #####
     ###### Typically, most files are ingested with a control group "M" (managed). XML is often stored as "X" (inline XML), but
     ###### can also be stored as "M". Yeah.
     # => http://www.fedora-commons.org/documentation/3.0b1/userdocs/digitalobjects/objectModel.html

     ### To configure this, there are two hashes, which you can define file extensions to match a DS label/id.
     ### The syntax is {".pdf" => { "id" => "pdf", "label" => "A PDF of the Document"}}
     ### If there is no label or id, the base file name (minus extension) is used.
     ### Since IDs must be unique, If there are multiple datastreams with the same extension,
     ### the first file will be given the ID, with the following files using their filenames as their IDs.
     ### NOT USING THESE FOR AIMS INGESTOR
     #@managed = {".pdf" => { "id" => "PDF", "label" =>"Document PDF"} , ".tiff" => "", ".jpg" => { "label" => "Thumbnail"}, ".xml" => ""}
     #@inline = {".dc" => {'id' => 'dublin_core', "label" => "Metadata"}}
  end #initialize

  
  
  

     def process()
       @row = nil
       if @file.nil?
          puts "Fedora Ingestor: This file ingests subdirectories into Fedora as objects. Each of the files are assigned as their own managed datastreams."
          puts "To run the script, you must include a base directory with you objects."
          puts "like so=>    $:  ./ingestor.rb Gouldoutput.csv /tmp/objects"
       elsif File.exists?(@file)
         FasterCSV.open("#{@file}", :headers => true).each do |row|
            ingest_object(row)
            @row = row
            sleep(10)
          end #do
       else
         puts "Error: #{@file} does not exists."
        end #if @directory.nil?
     end #process

     #
     #  This method creates a "Managed" datastream object.
     #  Just realized spaces in file names cause problems in the ID/Label, so there's hokey quick fix for that.
     def create_file_ds(f, id= nil, label=nil)
       puts "creating file ds for #{f} "
       if id.nil? || id.empty?
         id = File.basename(f, File.extname(f)).gsub(" ", "-")
       end
       if label.nil? || label.empty?
         label = File.basename(f, File.extname(f)).gsub(" ", "-")
       end

       ActiveFedora::Datastream.new(:dsID=>id, :controlGroup=>"M" , :blob=>File.open(f), :dsLabel=>label)

     end  #create_file_ds

     #
     # This method creates an "Inline" datastream object
     #
     def create_inline_ds(f, id= nil, label=nil)
       puts "creating inline ds for #{f} "
       if id.nil?
         id = File.basename(f, File.extname(f)).gsub(" ", "-")
       end
       if label.nil?
         label = File.basename(f, File.extname(f)).gsub(" ", "-")
       end
       #this helps format the XML a bit
       xml = Nokogiri::XML(open(f))
       ds = ActiveFedora::Datastream.new(:dsID=>id, :controlGroup=>"X", :dsLabel=>label)
       ds.content = xml.to_xml
       return ds
     end  #create_inline_ds


     # This method is passed a directory, makes a new fedora object, then makes datastreams of each of the files in the directory. 

     def ingest_object(row)

      @touch = File.join("/tmp", row["exportedAs"])
      
      unless File.exists?(@touch)
      obj = File.join(@directory, File.basename(row["exportedAs"].gsub('\\', '/')))
      sourceFile = File.join(obj,File.basename(row["exportedAs"].gsub('\\', '/')))
       
      if File.exists?(obj)
       # Gets a new PID
       pid = Nokogiri::XML(open(@fedora_uri + "/management/getNextPID?xml=true&namespace=#{@fedora_ns}", {:http_basic_authentication=>[@fedora_user, @fedora_pass]})).xpath("//pid").text
       
       #testing stuff
       #pid = "druid:1"
   
       fedora_obj = AimsDocument.new(:pid => pid)
       fedora_obj.label = File.basename(obj)
       fedora_obj.save
       print obj + " ===> "
       # now glob the object directory and makes datastreams for each of the files and add them as datastream to the fedora object.
       # fedora_obj.save
       
        dsid = 'rightsMetadata'
        xml_content = fedora_obj.datastreams_in_memory[dsid].content
        ds = Hydra::RightsMetadata.from_xml(xml_content)
        pid = fedora_obj.pid
        ds.pid = pid
        ds.dsid = dsid
        fedora_obj.datastreams_in_memory[dsid] = ds
        permissions = {"group"=>{"public"=>"read", "archivist" => "edit", "researcher" => "read", "patron" => 'read', "donor" => 'edit' }, "person" => {"archivist1" => "edit"}}
        ds.update_permissions(permissions)
        permissions = {"group" => {"public"=>"read"}}
        ds.update_permissions(permissions)
        
        fedora_obj.save
       
       Dir["#{obj}/**/**"].each do |f|
         
         #damn OS X spotlight. 
         unless f.include?('DS_Store')
          
          # text files and jp2000s get added as datastreams in the object. the wordperfect files get added as their own objects
          if f =~ /(.*)\.(txt)/
             fedora_obj.add_datastream(create_file_ds(f, File.basename(f), File.basename(f)))
           
          elsif f =~ /(.*)\.(pdf)/
             fedora_obj.add_datastream(create_file_ds(f, 'pdf', "#{File.basename(f)}.pdf"))
          elsif f =~  /(.*)\.(jp2)/
               # Below is if you want to not have the jp2 imported into fedora. it will just move them to a directory.
             #jp2_dir = File.join('/tmp', fedora_obj.pid.gsub("druid:", "druid_"))
             #FileUtils.mkdir_p(jp2_dir) unless File.directory?(jp2_dir)
             #FileUtils.cp(f, jp2_dir, :verbose => true)
             # Below this adds the jp2000s into fedora.
             fedora_obj.add_datastream(create_file_ds(f, File.basename(f), File.basename(f)))
		   elsif f == sourceFile #source file gets its own fedora object.   
             cpid = Nokogiri::XML(open(@fedora_uri + "/management/getNextPID?xml=true&namespace=#{@fedora_ns}", {:http_basic_authentication=>[@fedora_user, @fedora_pass]})).xpath("//pid").text
                        
             child_obj = FileAsset.new(:pid => cpid)
             child_obj.label = File.basename(f)
             dc = child_obj.datastreams['descMetadata']
             dc.extent_values << File.size(f)
           
           
             fedora_obj.add_relationship(:has_part, child_obj )
             fedora_obj.add_relationship(:has_collection_member, child_obj)
             puts "processing:#{f} for objectID #{cpid}"
             ext = File.extname(f)
             id = "DS1"
             label = File.basename(f)
             child_obj.add_datastream(create_file_ds(f, id, label ))
             child_obj.save
             print f + "\n"
          else
            puts "not a file to ingest ==> #{f}"
          end #if
         end #unless
       end #dir
        
         dm = fedora_obj.datastreams["descMetadata"]
         prop = fedora_obj.datastreams["properties"]
         
         labels = row["labels"].split(',')
         
         loutput = {"subjects" => [], "access" => []}
         doc_values = { "D" => "Document", "S" => "Spreadsheet", "E" => "Email", "IM" => "Image", "V" => "Video", "SO" => "Sound"} 
         comp_values = {"CM:5.25" => "5.25 inch. floppy diskettes", "CM:3.5" => "3.5 inch. floppy diskettes", "CM:P" => "Punch cards", "CM:T" => "Tape" }
         access_values = {"O" => "owner", "A" => "Archivists", "I" => "Invited", "P" =>"Public", "M"=>"Reading"}
        
      
         labels.each do |l|
           if doc_values.has_key?(l)
             loutput["doctype"] = doc_values[l]
           elsif comp_values.has_key?(l)
             loutput["mediatype"] = comp_values[l]
           elsif access_values.has_key?(l)
             loutput["access"] << access_values[l]
           elsif l.include?("S:")
             loutput["subjects"] << l.gsub("S:", '') 
          end #if
         end #do
         
         pp(loutput)
         prop.collection_values << "Steven J. Gould"
         prop.pages_values << number_of_pages(fedora_obj)
         prop.path_values << row['path']
         prop.file_size_values << row['size']
         prop.md5_values << row['md5']
         prop.sha1_values << row['sha1']
         prop.file_type_values << row['type']
         prop.filename_values << File.basename(obj)
         
         dm.isPartOf_values = row["subseries"].gsub(/[0-9]|Bookmark:|\./,"").strip
         dm.source_values << row['filename']
         dm.type_values << loutput['doctype']
         dm.format_values <<  loutput["mediatype"]
       
         
         
        loutput['subjects'].each { |s| dm.subject_values << s.gsub("S:", "") }
        
        dm.save
        prop.save
        fedora_obj.save

        solr_doc = fedora_obj.to_solr
        solr_doc <<  Solr::Field.new( :discover_access_group_t => "public" )
        ActiveFedora::SolrService.instance.conn.update(solr_doc)
        FileUtils.mkdir_p(@touch)
        end #unless
      end #if exists?    
         rescue  Exception => e  
        puts e.backtrace
	puts "erroring...."
        sleep(300)
        return nil
      rescue Timeout::Error => e
         puts "timeout error ...." 
         sleep(350)

     
     end #ingest_object


     # this makes the json for the nytimes book reader app
    

    #this method gets the number of pages for a document
    def number_of_pages(fedora_obj)
      len = []
      fedora_obj.datastreams.keys.each do |x|
        len << x if x.include?('.txt')
      end
      len.length
    end #number_of_pages

end #class

#========== This is the equivalent of a java main method ==========#
if __FILE__ == $0
 ingestor = Ingestor.new(ARGV[0], ARGV[1])
 ingestor.process
end
