# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/writer'

describe JSON::LD::Writer do
  before :each do
    @writer = JSON::LD::Writer.new(StringIO.new(""))
  end

  include RDF_Writer

  describe ".for" do
    formats = [
      :jsonld,
      "etc/doap.jsonld",
      {:file_name      => 'etc/doap.jsonld'},
      {:file_extension => 'jsonld'},
      {:content_type   => 'application/ld+json'},
      {:content_type   => 'application/x-ld+json'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        RDF::Reader.for(arg).should == JSON::LD::Reader
      end
    end
  end

  context "simple tests" do
    it "should use full URIs without base" do
      input = %(<http://a/b> <http://a/c> <http://a/d> .)
      serialize(input).should produce([{
        '@id'         => "http://a/b",
        "http://a/c"  => [{"@id" => "http://a/d"}]
      }], @debug)
    end

    it "should use qname URIs with standard prefix" do
      input = %(<http://xmlns.com/foaf/0.1/b> <http://xmlns.com/foaf/0.1/c> <http://xmlns.com/foaf/0.1/d> .)
      serialize(input, :standard_prefixes => true).
      should produce({
        '@context' => {
          "foaf"  => "http://xmlns.com/foaf/0.1/",
        },
        '@id'     => "foaf:b",
        "foaf:c"  => {"@id" => "foaf:d"}
      }, @debug)
    end

    it "should use qname URIs with parsed prefix" do
      input = %(
        <https://senet.org/gm> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://vocab.org/frbr/core#Work> .
        <https://senet.org/gm> <http://purl.org/dc/terms/title> "Rhythm Paradise"@en .
        <https://senet.org/gm> <https://senet.org/ns#unofficialTitle> "Rhythm Tengoku"@en .
        <https://senet.org/gm> <https://senet.org/ns#urlkey> "rhythm-tengoku" .
      )
      serialize(input, :prefixes => {
        :dc    => "http://purl.org/dc/terms/",
        :frbr  => "http://vocab.org/frbr/core#",
        :senet => "https://senet.org/ns#",
      }).
      should produce({
        '@context' => {
          "dc" => "http://purl.org/dc/terms/",
          "frbr" => "http://vocab.org/frbr/core#",
          "senet" => "https://senet.org/ns#"
        },
        '@id'     => "https://senet.org/gm",
        "@type"   => "frbr:Work",
        "dc:title" => {"@value" => "Rhythm Paradise","@language" => "en"},
        "senet:unofficialTitle" => {"@value" => "Rhythm Tengoku","@language" => "en"},
        "senet:urlkey" => "rhythm-tengoku"
      }, @debug)
    end

    it "should use CURIEs with empty prefix" do
      input = %(<http://xmlns.com/foaf/0.1/b> <http://xmlns.com/foaf/0.1/c> <http://xmlns.com/foaf/0.1/d> .)
      begin
        serialize(input, :prefixes => { "" => RDF::FOAF}).
        should produce({
          "@context" => {
            "" => "http://xmlns.com/foaf/0.1/"
          },
          '@id' => ":b",
          ":c"    => {"@id" => ":d"}
        }, @debug)
      rescue JSON::LD::JsonLdError, JSON::LD::JsonLdError, TypeError => e
        fail("#{e.class}: #{e.message}\n" +
          "#{@debug.join("\n")}\n" +
          "Backtrace:\n#{e.backtrace.join("\n")}")
      end
    end
    
    it "should not use terms if no suffix" do
      input = %(<http://xmlns.com/foaf/0.1/> <http://xmlns.com/foaf/0.1/> <http://xmlns.com/foaf/0.1/> .)
      serialize(input, :standard_prefixes => true).
      should_not produce({
        "@context" => {"foaf" => "http://xmlns.com/foaf/0.1/"},
        '@id'   => "foaf",
        "foaf"   => {"@id" => "foaf"}
      }, @debug)
    end
    
    it "should not use CURIE with illegal local part" do
      input = %(
        @prefix db: <http://dbpedia.org/resource/> .
        @prefix dbo: <http://dbpedia.org/ontology/> .
        db:Michael_Jackson dbo:artistOf <http://dbpedia.org/resource/%28I_Can%27t_Make_It%29_Another_Day> .
      )

      serialize(input, :prefixes => {
          "db" => RDF::URI("http://dbpedia.org/resource/"),
          "dbo" => RDF::URI("http://dbpedia.org/ontology/")}).
      should produce({
        "@context" => {
          "db"    => "http://dbpedia.org/resource/",
          "dbo"   => "http://dbpedia.org/ontology/"
        },
        '@id'   => "db:Michael_Jackson",
        "dbo:artistOf" => {"@id" => "db:%28I_Can%27t_Make_It%29_Another_Day"}
      }, @debug)
    end

    it "serializes multiple subjects" do
      input = %q(
        @prefix : <http://www.w3.org/2006/03/test-description#> .
        @prefix dc: <http://purl.org/dc/terms/> .
        <http://example.com/test-cases/0001> a :TestCase .
        <http://example.com/test-cases/0002> a :TestCase .
      )
      serialize(input, :prefixes => {"" => "http://www.w3.org/2006/03/test-description#"}).
      should produce({
        '@context'     => {
          "" => "http://www.w3.org/2006/03/test-description#",
          "dc" => RDF::DC.to_s 
        },
        '@graph'     => [
          {'@id'  => "http://example.com/test-cases/0001", '@type' => ":TestCase"},
          {'@id'  => "http://example.com/test-cases/0002", '@type' => ":TestCase"}
        ]
      }, @debug)
    end

    it "serializes Wikia OWL example" do
      input = %q(
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

        <http://data.wikia.com/terms#Character> a owl:Class;
           rdfs:subClassOf _:a .
        _:a a owl:Restriction;
           owl:minQualifiedCardinality "1"^^xsd:nonNegativeInteger;
           owl:onClass <http://data.wikia.com/terms#Element>;
           owl:onProperty <http://data.wikia.com/terms#characterIn> .
      )
      serialize(input, :rename_bnodes => false, :prefixes => {
        :owl  => "http://www.w3.org/2002/07/owl#",
        :rdfs => "http://www.w3.org/2000/01/rdf-schema#",
        :xsd  => "http://www.w3.org/2001/XMLSchema#"
      }).
      should produce({
        '@context'     => {
          "owl"  => "http://www.w3.org/2002/07/owl#",
          "rdf"  => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
          "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
          "xsd"  => "http://www.w3.org/2001/XMLSchema#"
        },
        '@graph'     => [
          {
            "@id" => "_:a",
            "@type" => "owl:Restriction",
            "owl:minQualifiedCardinality" => {"@value" => "1","@type" => "xsd:nonNegativeInteger"},
            "owl:onClass" => {"@id" => "http://data.wikia.com/terms#Element"},
            "owl:onProperty" => {"@id" => "http://data.wikia.com/terms#characterIn"}
          },
          {
            "@id" => "http://data.wikia.com/terms#Character",
            "@type" => "owl:Class",
            "rdfs:subClassOf" => {"@id" => "_:a"}
          }
        ]
      }, @debug)
    end
  end
  
  def parse(input, options = {})
    RDF::Graph.new << RDF::Turtle::Reader.new(input, options)
  end

  # Serialize ntstr to a string and compare against regexps
  def serialize(ntstr, options = {})
    g = ntstr.is_a?(String) ? parse(ntstr, options) : ntstr
    @debug = [] << g.dump(:ttl)
    result = JSON::LD::Writer.buffer(options.merge(:debug => @debug)) do |writer|
      writer << g
    end
    if $verbose
      #puts hash.to_json
    end
    
    JSON.parse(result)
  end
end
