# frozen_string_literal: true

require 'adwaita'
require 'fileutils'

module Errands
  # Log is the application's logger.
  #
  # Ported from upstream's errands/lib/logging.py: the same four levels, the
  # same ANSI-coloured prefixes on stdout, and the same append-only log.txt in
  # the user's data directory.
  #
  module Log
    class << self
      def data_dir = @data_dir ||= File.join(GLib.user_data_dir, 'errands')

      def log_file = File.join(data_dir, 'log.txt')

      # Creates the data directory and starts a new log with the banner
      # upstream writes at every start.
      def init
        FileUtils.mkdir_p(data_dir)
        empty(<<~BANNER)

          -------------------------------------------------
          Starting Errands #{State.version} at "#{Time.now.strftime('%Y %d %B %H:%M:%S')}"
          -------------------------------------------------
        BANNER
      end

      def debug(msg)
        puts "\e[33;1m[DEBUG]\e[0m #{msg}"
        append("[DEBUG] #{msg}")
      end

      def error(msg)
        puts "\e[31;1m[ERROR]\e[0m #{msg}"
        append("[ERROR] #{msg}")
      end

      def info(msg)
        puts "\e[32;1m[INFO]\e[0m #{msg}"
        append("[INFO] #{msg}")
      end

      def empty(msg)
        puts msg
        append(msg)
      end

      private

        def append(msg)
          File.open(log_file, 'a') { |file| file.puts(msg) }
        rescue SystemCallError
          puts "\e[31;1m[ERROR]\e[0m Can't write to the log file"
        end
    end
  end
end
