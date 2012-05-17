#!/usr/bin/ruby
# -*- coding:utf-8 -*-

require 'gepub'
require 'nokogiri'
require 'json'

module EPUBPARSER
  class Book
    attr_accessor :toc, :info, :chapters

    def self.parse(file_path)
      #file_path = "/Users/wusonglin/Downloads/安徒生童话.epub"
      #file_path = "/Users/wusonglin/Desktop/epubs/given_a_chick_at_18.epub"
      file_path = "/Users/wusonglin/Desktop/epubs/the_earth/the_earth.epub"

      f = File.open(file_path)
      ebook = GEPUB::Book.parse(f)
      
=begin
      ebook.items.each do |id,item|
        if item.guess_mediatype == 'application/xhtml+xml'
          html = item.content
          doc = Nokogiri::HTML(html)
          bd = doc.css('body')[0]
          bd.content = bd.content.gsub(/<\/?[^>]*>/, "")
          item.content = doc.to_s
        end
      end

      new = File.join(File.dirname(__FILE__), 'new_chick.epub')
      ebook.generate_epub(new)

      item_array = ebook.manifest.items.find do |id, item|
        item.properties.include?"cover-image"
      end

      cover_data = item_array[1].content

      img_name = book.split('.')[0] + '.jpg'
      img_dir = "#{::Rails.root.join('public', 'upload', 'cover')}"

      unless File.exist?img_dir
        Dir.mkdir(img_dir)
      end

      img_path = img_dir + '/' + img_name

      image = MiniMagick::Image.read(cover_data)
      image_copy = image.clone
      image_copy.write(img_path)

      puts ebook.title.to_s
=end

      book = Book.new(ebook)
    end

    def initialize(ebook, attributes = {})
      items_arr = ebook.items.values
      is_ncx = false

      nav = items_arr.find do |i|
        i.properties.include?'nav'
      end

      if nav.nil?
        nav = items_arr.find do |i|
          i.mediatype == 'application/x-dtbncx+xml'
        end

        is_ncx = true
      end

      chapters = items_arr.select do |i|
        i.mediatype == 'application/xhtml+xml' and (i.properties.empty? or i.properties.nil?)
      end

      @chapters = Chapter.new(chapters).
      @toc = Toc.new(nav, is_ncx)
      @info = Info.new(ebook)
      yield book if block_given?
    end
  end

  class Info
    def initialize(book)
      title = book.title
      author = book.creator
      chapters = []

      book.spine.itemref_list.each do |item|
        chapters.push({
          id: item.idref,
          content: "#{ item.idref }.json"
        })
      end
      
      @info = {
        title: title,
        author: author,
        chapters: chapters
      }

      yield info if block_given?
    end

    def get_json
      @info.dup.to_json
    end
  end

  class Toc
    attr_accessor :type

    def initialize(nav, is_ncx=false)
      if is_ncx
        doc = Nokogiri::XML(nav.content)
        points = doc.css('navMap > navPoint')
        @map = parse_ncx(points)
        @type = 'ncx'
      else
        doc = Nokogiri::HTML(nav.content)
        ol = doc.css('nav > ol')
        @map = parse_nav(ol)
        @type = 'nav'
      end
    end

    def get_json
      @map.dup.to_json
    end

    def parse_ncx(points)
      arr = []

      points.each do |point|
        item = {
          title: point.css('navLabel > text')[0].content,
          content: point.css('content')[0].attr('src')
        }

        children = point.css('navPoint')

        unless children.empty?
          item[:map] = parse_ncx(children)
        end

        arr.push(item)
      end

      arr
    end

    def parse_nav(ol)
      arr = []

      ol[0].css('li').each do |li|
        item = {
          title: li.css('span, a')[0].content
        }

        child = li.css('ol')

        unless child.empty?
          item[:map] = parse_nav(child)
        end

        arr.push(item)
      end

      arr
      #.content = bd.content.gsub(/<\/?[^>]*>/, "")
      #item.content = doc.to_s
    end
  end

  class Chapter
    attr_reader :chapter

    def initialize(chapters)
      @chapter = []
      chapters.each do |item|
        @chapter.push(gen_chapter(item))
      end
      yield chapter if block_given?
    end

    def gen_chapter(chapter)
      doc = Nokogiri::HTML(chapter.content)
      id = chapter.id
      title = doc.css('title')[0].content
      content, index = [], 0

      doc.css('body h1, body h3')[0].parent.children.each do |tag|
        text = tag.content
        text.strip!
        next if text.empty?

        type = tag.node_name
        range = [index, text.length-1]

        content.push({
          type: type,
          text: text,
          range: range
        })

        index += text.length
      end

      {
        id: id,
        title: title,
        content: content
      }
    end

    def get_json
      @chapter.dup.to_json
    end
  end
end

EPUBPARSER::Book.parse('')
