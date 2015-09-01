#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
  # Nokogiri::HTML(open(url).read, nil, 'utf-8')
end

def date_from(text)
  return if text.to_s.empty?
  return Date.parse(text).to_s rescue nil
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('table.contentpane tr a/@href').each do |href|
    mp_url = URI.join url, href.text
    scrape_person(mp_url)
  end
end

def area_id(area)
  return if area.to_s.empty?
  return 'ocd-division/country:gm/constituency:%s' % area.tidy.downcase.tr(' ','-')
end
  

def scrape_person(url)
  noko = noko_for(url)
  box = noko.css('div#content_column')
  text = box.xpath('.//text()').map(&:text).map(&:tidy).reject(&:empty?).join(':') + ":"

  area = text[/Member for\s*:?\s*(.*?):/i, 1]
  party = text[/Political Party\s*:?\s*(.*?):/i, 1]
  dob = date_from(text[/Date of Birth\s*:?\s*(.*?):/i, 1])
  type = text[/Nominated M[ae]mber/] ? "nominated" : "elected"


  data = { 
    id: url.to_s[/id=(\d+)/, 1],
    name: box.css('td.contentheading').text.tidy.sub(/^Hon\.?\s+/, ''),
    area: area.to_s.tidy.sub(/\s+Consti[ty]uency.*/i,''),
    party: party.to_s.tidy,
    birth_date: dob,
    image: box.css('img[src*="/members/"]/@src').text,
    type: type,
    term: 2012,
    source: url.to_s,
  }
  data[:area_id] = area_id(data[:area])
  data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?
  ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_list('http://www.assembly.gov.gm/index.php?option=com_content&view=category&id=53%3Amembers-of-parliament&Itemid=90&limit=80')
