# frozen_string_literal: true

require 'nokogiri'
require 'net/http/server'
require 'json'

module SenseThing
  module Server # rubocop:disable Metrics/ModuleLength
    def self.serve(db, port: 4567, host: '127.0.0.1')
      DaemonWrapper.new(db, port, host).run
    end

    class SensorDb
      def initialize
        @groups = []
        @sensors = {}
      end

      def feed(sensor)
        group_name, subname = sensor.name.split '/', 2
        @groups << group_name unless @groups.include? group_name
        # use array instead of hash to keep consistent ordering
        @sensors[group_name] = [] unless @sensors[group_name]
        @sensors[group_name] << [subname, sensor]
      end

      def each_in_group(group_name)
        @sensors[group_name]&.each do |s|
          yield s[0], s[1]
        end
      end

      def each_group(&block)
        @groups.each(&block)
      end
    end

    class DaemonWrapper
      attr_reader :port, :host

      def initialize(db, port, host)
        @db = db
        @port = port
        @host = host
      end

      def handle(request, _stream)
        case request[:uri][:path]
        when '/'
          Server.index(@db, request)
        else
          Server.not_found
        end
      rescue StandardError => e
        Server.exception(e)
      end

      def run
        Net::HTTP::Server.run(port: port, host: host) do |request, stream|
          handle(request, stream).convert
        end
      end
    end

    class Response
      attr_reader :status, :headers, :body

      def initialize(status: 200, headers: {})
        @status = Integer(status)
        @headers = Hash(headers)
        @body = []
        yield self if block_given?
      end

      def status=(val)
        @status = Integer(val)
      end

      def <<(data)
        @body << data.to_s
      end

      def convert
        [status, headers, body]
      end
    end

    def self.exception(exception)
      Response.new(status: 500) do |resp|
        resp.headers['Content-Type'] = 'text/plain'

        resp << "500: Exception: #{exception}\r\n\r\n"
        resp << "Backtrace:\r\n"
        exception.backtrace.each do |b|
          resp << "  #{b}\r\n"
        end
      end
    end

    def self.not_found
      Response.new(status: 404) do |resp|
        resp.headers['Content-Type'] = 'text/plain'

        resp << '404: Not Found'
      end
    end

    def self.index(db, request)
      demands_html = request[:headers]['Accept']&.include? 'text/html'
      demands_json = ['text/json', 'application/json'].any? do |h|
        request[:headers]['Accept']&.include? h
      end

      render_html = demands_html || !demands_json

      Response.new(status: 200) do |resp|
        if render_html
          resp.headers['Content-Type'] = 'text/html; charset=utf-8'
          resp << index_html(db)
        else
          resp.headers['Content-Type'] = 'text/json; charset=utf-8'
          resp << index_json(db)
        end
      end
    end

    def self.index_html(db) # rubocop:disable Metrics/MethodLength
      builder = Nokogiri::HTML4::Builder.new do |doc| # rubocop:disable Metrics/BlockLength
        doc.html do # rubocop:disable Metrics/BlockLength
          doc.head do # rubocop:disable Metrics/BlockLength
            doc.meta(name: 'viewport', content: 'width=device-width,initial-scale=1')
            doc.meta(content: 'text/html;charset=utf-8', 'http-equiv': 'Content-Type')
            doc.style do # rubocop:disable Metrics/BlockLength
              doc << <<~CSS
                body {
                  font-family: sans-serif;
                  background-color: #ddd;
                  margin: 0;
                }
                h2 {
                  word-wrap: break-word;
                }
                main {
                  padding: 1rem;
                  max-width: 1000px;
                  margin: 0 auto 0 auto;
                  background-color: #fff;
                }
                ul {
                  list-style-type: none;
                  padding-left: 2rem;
                }
                li {
                  display: grid;
                  grid-template-columns: 1fr 1fr 2fr;
                  grid-template-rows: auto;
                }
                @media screen and (max-width: 800px) {
                  li { grid-template-columns: 1fr 1fr 1fr }
                }
                @media screen and (max-width: 600px) {
                  li { grid-template-columns: 1fr 1fr 0 }
                }
              CSS
            end
          end
          doc.body do # rubocop:disable Metrics/BlockLength
            doc.main do
              doc.h1 'SenseThing Web UI'
              doc.hr
              db.each_group do |group|
                doc.h2 group
                doc.ul do
                  db.each_in_group(group) do |sensor_name, sensor|
                    doc.li do
                      doc.strong(style: style_grid(1, 1)) do
                        doc << sensor_name.to_s
                      end

                      doc.span(style: style_grid(1, 2)) do
                        doc << "#{sensor.fetch} #{sensor.unit}"
                      end

                      if (max = sensor.maximum)
                        min = sensor.minimum || 0
                        doc.progress(style: style_grid(1, 3), value: sensor.value - min, max: max - min)
                      end
                    end
                  end
                end
              end
              doc.hr
              doc.p "SenseThing #{SenseThing::VERSION}"
              doc.p 'Copyright (c) 2024 Evan Perry Grove'
            end
          end
        end
      end

      builder.to_html.encode('ISO-8859-1')
    end

    def self.index_json(db)
      data = {}
      db.each_group do |group|
        gdata = {}
        db.each_in_group(group) do |sensor_name, sensor|
          sdata = {}
          sdata['value'] = sensor.fetch
          sdata['unit'] = sensor.unit if sensor.unit
          sdata['min'] = sensor.minimum if sensor.minimum
          sdata['max'] = sensor.maximum if sensor.maximum
          gdata[sensor_name] = sdata
        end
        data[group] = gdata
      end

      JSON.generate(data).encode('utf-8')
    end

    def self.style_grid(row, col)
      "grid-column:#{col};grid-row:#{row};"
    end
  end
end
