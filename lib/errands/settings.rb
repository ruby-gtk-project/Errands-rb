# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'fileutils'

module Errands
  # Settings holds the keys of upstream's GSettings schema.
  #
  # Ported from upstream's data/io.github.mrvladus.List.gschema.xml.in and
  # errands/lib/gsettings.py: the same keys, types and defaults, the same
  # get/set/bind entry points.
  #
  # Upstream reads them through Gio::Settings, which needs a compiled schema
  # installed into the system's glib-2.0/schemas directory. Requiring an
  # install step before the app can run from a checkout is worse than the
  # alternative, so the keys are backed by a JSON file under the user's config
  # directory instead.
  #
  module Settings
    DEFAULTS = {
      'width'                           => 1000,
      'height'                          => 700,
      'maximized'                       => false,
      'theme'                           => 0,
      'last-open-list'                  => '',
      'sync-provider'                   => 0,
      'sync-url'                        => '',
      'sync-username'                   => '',
      'task-list-new-task-position-top' => true,
      'launch-on-startup'               => true,
      'run-in-background'               => true,
      'notifications-enabled'           => true,
    }.freeze

    class << self
      def init
        Log.debug('Settings: Initialize')
        values
      end

      def get(key) = values.fetch(key.to_s, DEFAULTS[key.to_s])

      def set(key, value)
        values[key.to_s] = value
        write
        value
      end

      # Mirrors GSettings.bind: the widget property takes the stored value now,
      # and every later change of that property is written back.
      def bind(key, widget, prop, invert: false)
        widget.set_property(prop.to_s.tr('_', '-'), bound_value(key, invert))
        widget.signal_connect("notify::#{prop.to_s.tr('_', '-')}") do
          current = widget.get_property(prop.to_s.tr('_', '-'))
          if invert
            set(key, !current)
          else
            set(key, current)
          end
        end
      end

      def location = @location ||= File.join(config_dir, 'settings.json')

      private

        def bound_value(key, invert)
          if invert
            !get(key)
          else
            get(key)
          end
        end

        def values = @values ||= DEFAULTS.merge(read)

        def config_dir
          File.join(ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')), 'errands')
        end

        def read
          if File.exist?(location)
            JSON.parse(File.read(location))
          else
            {}
          end
        rescue StandardError => e
          Log.error("Settings: Can't read settings. #{e.message}")
          {}
        end

        def write
          FileUtils.mkdir_p(config_dir)
          File.write(location, JSON.pretty_generate(values))
        rescue StandardError => e
          Log.error("Settings: Can't write settings. #{e.message}")
        end
    end
  end
end
