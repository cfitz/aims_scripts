#!/usr/bin/env ruby

require 'html_to_csv'
require 'reorg_directory'
require 'convert_objects'

#
# This is a set of scripts used to ingest items into the AIMS hydra application. It uses metadata exported from
# Forensic Toolkit as well as items converted using Avantstar transit. 
# 
#


# Step 1. Process FTK metadata into CSV file
# HtmlToCsv.new("path_to_ftk_bookmark_html_files", "csv_output_file")

step1 = HtmlToCsv.new("/tmp/Chris_08_27/Gould_08_27_html/", "Gouldoutput.csv")
step1.process

# Step 2. Make a new directories for each of the Fedora object
#  ReorgDirectory.new("path_to_output_directory", "path_to_ftk_source_objects", "path_to_transit_output", "csv_metadata_file")

step2 =  ReorgDirectory.new("/tmp/testout", "/tmp/Chris_08_27/Gould_08_27_xml/",  "/tmp/Chris_08_27/Gould_Convert_08_27/", "Gouldoutput.csv") 
step2.process

# Step 3. Convert the objects into pdf, jpg2000s, and text files
# ConvertObjects.new("new_path_to_fedora_objects_directories")

step3 = ConvertObjects.new("/tmp/testout")
step3.process

# Step 4. Ingest the object into Fedora
# This script actually has to be run in the rails root, since requires AimDocument model defined.
# Ingestor.new("csv_metadata_file.csv", "path_to_fedora_objects") 

# step4 = Ingestor.new("Gouldoutput.csv", "/tmp/objects")
# step4.process