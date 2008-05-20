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
#
#==依存ライブラリ
#
#*mechanize
#*ruby-mp3info
#
#
#==使用方法
#% ./muxtape-snatcher --target <id>
#

%w[
  rubygems
  mechanize

  logger
  optparse
].each{|lib|require lib}


class MuxTapeSnatcher < WWW::Mechanize
  attr_accessor :agent
  attr_accessor :log

  AGENT_ALIASES_POPULAR_KEYS = WWW::Mechanize::AGENT_ALIASES.keys.map do |k|
    k if k =~ /(?:Mac|Win|Linux).+/
  end.compact

  def set_random_user_agent
    self.user_agent_alias =
      AGENT_ALIASES_POPULAR_KEYS[rand(AGENT_ALIASES_POPULAR_KEYS.length)]
  end

  def get(uri)
    begin
      sleep 3 #wait
      set_random_user_agent
      super(uri)
    rescue Timeout::Error
      log.warn "  caught Timeout::Error !"
      retry
    rescue WWW::Mechanize::ResponseCodeError => e
      case e.response_code
      when "502"
        log.warn "  caught Net::HTTPBadGateway !"
        retry
      when "404"
        log.warn "  caught Net::HTTPNotFound !"
      else
        log.warn "  caught Excepcion !" + e.response_code
      end
    end
  end

  def initialize
    super
    self.max_history = 1
    options[:log_output]  = STDERR
    options[:log_level]   = Logger::WARN

    OptionParser.new do |opt|
      opt.on('-t target', '--target=target', 'target user') do |arg|
        options[:target] = arg
      end
      opt.on('-v', '--verbose', 'verbose mode') do |arg|
        options[:log_level] = Logger::INFO
      end
      opt.on('-d', '--debug', 'debug mode') do |arg|
        options[:log_level]  = Logger::DEBUG
      end
      opt.parse!
    end

    self.log = Logger.new(options[:log_output])
    self.log.level = options[:log_level]

    tape_page(options[:target]) if options[:target]
  end

  def tape_page(id)
    page = get("http://#{id}.muxtape.com/")
    songs, signatures =
      page.search("script[text()*='Kettle']").inner_text.
      match(/(\[.+?\]).+(\[.+?\])/)[1, 2]

    songs_and_signatures = eval(songs).zip(eval(signatures))

    songs_and_signatures.each_with_index do |pair, idx|
      get_song(song_url(pair[0], pair[1]), id, idx + 1)
    end

  end

  def song_url(song_id, signature)
    "http://muxtape.s3.amazonaws.com/songs/#{song_id}" +
      "?PLEASE=DO_NOT_STEAL_MUSIC&#{signature}"
  end

  def get_song(uri, id, idx)
    Object::File::open(sprintf("%02d_%s.mp3", idx, id), 'w') do |f|
      f.binmode
      f.write get(uri).body
    end
  end

end

MuxTapeSnatcher.new if $0 == __FILE__
