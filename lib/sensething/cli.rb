require 'optparse'
require 'set'
require 'io/console'

module SenseThing
  VERSION = Gem.loaded_specs['sensething']&.version

  module Cli # rubocop:disable Metrics/ModuleLength
    class Command < OptionParser
      attr_accessor :name, :short, :description
      attr_reader :cmd

      def initialize(name, &blk)
        super(&blk)
        @name = name
        @flag_vals = {}
        on('-h', '--help', 'Show help message and exit') do
          full_help_message
        end
      end

      def command(name, &block)
        @commands ||= {}
        opt = Command.new(name, &block)
        banner_lead = banner.split(' - ', 2)[0]
        opt.banner = "#{banner_lead} #{opt.name}"
        opt.banner << " - #{opt.description}" if opt.description
        @commands[opt.name.to_s] = opt
        @commands[opt.short.to_s] = opt if opt.short
      end

      def order!(argv = ARGV, into: nil, &nonopt)
        @cmd = match_cmd(argv)
        if @cmd
          argv.shift
          @cmd.order!(argv, into: into, &nonopt)
        else
          super(argv, into: into, &nonopt)
        end
      end

      def full_help_message
        puts banner
        if @commands
          puts "\nCommands:"
          cmds = Array(Set.new(@commands.values)).sort_by(&:name)
          cmds.each do |c|
            puts c.cmd_help
          end
        end
        puts "\nOptions:"
        puts summarize
        exit 0
      end

      def [](k)
        @flag_vals[k]
      end

      def []=(k, v)
        @flag_vals[k] = v
      end

      def self.term_width
        sz = IO.console&.winsize
        return 80 unless sz

        sz[1]
      end

      def self.word_wrap(text, width)
        text.scan(/\S.{0,#{width}}\S(?=\s|$)|\S+/)
      end

      protected

      def cmd_help
        result = "  #{name.ljust(16)} "
        result << "#{short} " if short
        result = result.ljust(26)
        indent = result.length
        desc = self.class.word_wrap(description, self.class.term_width - indent)
        result << desc.shift
        desc.each do |line|
          result << "\n"
          result << ' ' * indent
          result << line
        end
        result
      end

      private

      def match_cmd(argv)
        return unless @commands

        @commands[argv[0]]
      end
    end

    @option_parser = Command.new('sensething') do |parser| # rubocop:disable Metrics/BlockLength
      parser.banner = 'sensething'

      parser.on '-v', '--version', 'Show version info and exit' do
        puts "Sensething #{VERSION}"
        exit 0
      end

      parser.on '--license', 'Show license info and exit' do
        puts <<~GNU
          SenseThing  Copyright (C) 2024  Evan Perry Grove

          This program is free software: you can redistribute it and/or modify it under
          the terms of version 3 the GNU General Public License, as published by the
          Free Software Foundation.

          This program is distributed in the hope that it will be useful, but WITHOUT ANY
          WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
          PARTICULAR PURPOSE. See version 3 of the GNU General Public License for more
          details.
        GNU
        exit 0
      end

      parser.command 'list-sensors' do |ls|
        ls.description = 'List all available sensors'
        ls.short = 'ls'
      end

      parser.command 'info' do |si|
        si.description = 'Show detailed information about sensors'
        si.short = 'i'
        si.on '-s NAME', '--sensor NAME', 'Name of a sensor to show information about' do |n|
          si[:name] = [] unless si[:name]
          si[:name] << n
        end
      end

      parser.command 'read' do |r|
        r.description = 'Read sensor values'
        r.short = 'r'
        r.on '-s NAME', '--sensor NAME', 'Name of a sensor to read' do |n|
          r[:name] = [] unless r[:name]
          r[:name] << n
        end
      end

      parser.command 'serve' do |s|
        s.description = 'Run web UI'
        s.short = 's'
        s.on '-a ADDRESS', 'Address for the server to use' do |a|
          s[:address] = a
        end
        s.on '-p PORT', 'Port for the server to use' do |a|
          s[:port] = Integer(a)
        end
      end

      parser.command 'log' do |l| # rubocop:disable Metrics/BlockLength
        l.description = 'Log sensor values continuously'
        l.short = 'l'
        l.on '-s NAME', '--sensor NAME', 'Name of a sensor to include in the logs' do |n|
          l[:name] = [] unless l[:name]
          l[:name] << n
        end
        l.on '-i SECONDS', '--interval SECONDS', 'Data logging interval in seconds (default: 5)' do |i|
          if l[:interval].nil?
            l[:interval] = Float(i)
          else
            warn "-i/--interval specified twice. The first one (#{l[:interval]}) will be used."
          end
        end
        l.on '-u', '--units', 'Include units in output data' do |_|
          if l[:units].nil?
            l[:units] = true
          else
            warn '-u/--units specified twice. This has no adverse effect right now, but it might in the future.'
          end
        end

        desc = <<~DESC
          Include timestamps in the output data. TYPE may be any of the following:
                                                      seconds (default)
                                                      millis
                                                      iso8601-millis
                                                      iso8601
        DESC
        l.on '-t', '--timestamp [TYPE]', desc do |t|
          if l[:timestamp].nil?
            l[:timestamp] = t || 'seconds'
          else
            warn "-t/--timestamp specified twice. The first one (#{l[:timestamp]}) will be used."
          end
        end

        desc = <<~DESC
          Output data format, which can be any of the following:
                                                      csv (default)
                                                      json
        DESC
        l.on '-f FORMAT', '--format FORMAT', desc do |f|
          if l[:format].nil?
            l[:format] = f
          else
            warn "-f/--format specified twice. The first one (#{l[:format]}) will be used."
          end
        end
      end
    end

    def self.parse_command_line(argv = ARGV)
      @option_parser.order!(argv)
      @option_parser
    end

    def self.show_help
      @option_parser.full_help_message
    end
  end
end
