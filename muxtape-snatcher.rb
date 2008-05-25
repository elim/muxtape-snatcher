#!/usr/bin/env ruby
# -*- mode: ruby; coding: utf-8-unix; indent-tabs-mode: nil -*-
#
# Author::    Takeru Naito (mailto:takeru.naito@gmail.com)
# Copyright:: Copyright (c) 2008 Takeru Naito
# License::   Distributes under the same terms as Ruby
#
#
#= muxtape から mp3 を抜いてきます。
#
# 内容が内容だけに表に出せなげ。
#
#
#==依存ライブラリ
#
#*mechanize
#
#
#==使用方法
#% ./muxtape-snatcher --target=<id>
#

require 'rubygems'
require 'mechanize'
require 'logger'

class MuxTapeSnatcher
  def initialize(opts = {})
    @target = opts[:target]
    @agent  = WWW::Mechanize.new do |a|
      a.max_history      = 1
      a.user_agent_alias = 'Mac FireFox'
      a.log              = Logger.new(opts[:log_output])
      a.log.level        = opts[:log_level]
    end
  end

  def run
    if @target
      get_song(analyzing_tape_page)
    else 
      STDERR.puts('Oops. Please. ID.')
    end
  end

  private
  def fetch(uri)
    begin
      sleep 2 #wait
      @agent.get(uri)
    rescue Timeout::Error
      @agent.log.warn "  caught Timeout::Error !"
      retry
    rescue WWW::Mechanize::ResponseCodeError => e
      case e.response_code
      when "502"
        @agent.log.warn "  caught Net::HTTPBadGateway !"
        retry
      when "404"
        @agent.log.warn "  caught Net::HTTPNotFound !"
      else
        @agent.log.warn "  caught Excepcion !" + e.response_code
      end
    end
  end

  def analyzing_tape_page 
    page = fetch("http://#{@target}.muxtape.com/")
    songs, signatures =
      page.search("script[text()*='Kettle']").inner_text.
      match(/(\[.+?\]).+(\[.+?\])/)[1, 2]

    songs      = eval(songs)
    signatures = eval(signatures)

    (1..songs.length).zip(songs, signatures)
  end

  def get_song(table)
    table.each do |record|
      idx       = record[0]
      song_id   = record[1]
      signature = record[2]

      puts "fetching #{idx} of #{table.length}..."
      
      Object::File::open(sprintf("%02d_%s.mp3", idx, @target), 'w') do |f|
        f.binmode
        f.write fetch(song_url(song_id, signature)).body
      end
    end
  end

  def song_url(song_id, signature)
    "http://muxtape.s3.amazonaws.com/songs/#{song_id}" +
      "?PLEASE=DO_NOT_STEAL_MUSIC&#{signature}"
  end
end


if $0 == __FILE__
  require 'optparse'

  opts = {
    :target     => nil,
    :log_output => STDERR,
    :log_level  => Logger::WARN
  }

  OptionParser.new do |parser|
    parser.instance_eval do
      on('-t target', '--target=target', 'target user') do |arg|
        opts[:target] = arg
      end

      on('-v', '--verbose', 'verbose mode') do |arg|
        opts[:log_level] = Logger::INFO
      end

      on('-d', '--debug', 'debug mode') do |arg|
        opts[:log_level]  = Logger::DEBUG
      end
      parse!
    end
  end
  
  MuxTapeSnatcher.new(opts).run
end
