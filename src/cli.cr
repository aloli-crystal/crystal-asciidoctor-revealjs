#!/usr/bin/env crystal
require "./asciicrystal_revealjs"
require "option_parser"

input_file = ""
output_file = ""

OptionParser.parse do |parser|
  parser.banner = "Usage: asciicrystal-revealjs [options] file.adoc"
  parser.on("-o FILE", "--out-file FILE", "Output HTML file (default: <input>.html)") { |f| output_file = f }
  parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
  parser.on("-v", "--version", "Show version") { puts "asciicrystal-revealjs #{AsciicrystalRevealjs::VERSION}"; exit 0 }
  parser.unknown_args { |args| input_file = args.first? || "" }
end

if input_file.empty?
  STDERR.puts "Error: no input file specified."
  STDERR.puts "Usage: asciicrystal-revealjs [options] file.adoc"
  exit 1
end

unless File.exists?(input_file)
  STDERR.puts "Error: file '#{input_file}' does not exist."
  exit 1
end

if output_file.empty?
  output_file = File.join(
    File.dirname(input_file),
    File.basename(input_file, File.extname(input_file)) + ".html"
  )
end

# Load the document and attach the revealjs converter
doc = Asciicrystal.load_file(input_file, {"safe" => "safe"})
converter = AsciicrystalRevealjs::Converter.new
doc.converter = converter

# Convert as standalone document (full HTML)
output = converter.convert(doc, "document")

if output && !output.empty?
  File.write(output_file, output)
  puts "Presentation generated: #{output_file}"
else
  STDERR.puts "Error: conversion produced no output."
  exit 1
end
