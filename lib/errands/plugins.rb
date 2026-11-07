# frozen_string_literal: true

require 'adwaita'
require 'fileutils'

require_relative 'logging'

module Errands
  # PluginBase describes what a plugin instance is expected to provide:
  # metadata (author, description, icon, name, url) and a main widget the
  # app can place into its view stack.
  #
  # Ported from upstream's PluginBase in errands/lib/plugins.py, an ABC with
  # the same attributes declared as class-level type annotations.
  #
  class PluginBase
    attr_accessor :author, :description, :icon_name, :main_view, :name, :url
  end

  # PluginsLoader scans the user's plugins directory and loads each plugin
  # it finds there.
  #
  # Ported from upstream's PluginsLoader in errands/lib/plugins.py. Upstream
  # discovers a `plugin.py` per plugin subdirectory, installs that plugin's
  # own `requirements.txt` into a local `dependencies` directory with pip,
  # `importlib.import_module`s the file, and instantiates its `Plugin`
  # class. This port keeps that same shape over Ruby's own mechanisms: a
  # `plugin.rb` file instead of `plugin.py`, a plugin-local `Gemfile`
  # instead of `requirements.txt` (installed with `bundle install
  # --gemfile=... --path=...` instead of `pip install -t ...`), and
  # `require` instead of `importlib.import_module`.
  #
  class PluginsLoader
    def initialize(app)
      @app = app
      @plugins = []
      load_plugins
    end

    attr_reader :app, :plugins

    private

      # Ported from upstream's _add_resources_path: registers a plugin's own
      # "resources/icons" directory on the icon theme's search path, if the
      # plugin ships one.
      def add_resources_path(dir)
        resources_dir = File.join(dir, 'resources')
        return unless File.directory?(resources_dir)

        icon_theme = Gtk::IconTheme.get_for_display(Gdk::Display.default)
        icon_theme.add_search_path(File.join(resources_dir, 'icons'))
      end

      # Ported from upstream's _get_user_plugins_dir: the directory plugins
      # live in, created if it does not exist yet, and put on the load path
      # so a plugin's own `require 'plugin'` style references resolve.
      def user_plugins_dir
        dir = File.join(GLib.user_data_dir, 'errands', 'plugins')
        FileUtils.mkdir_p(dir)
        $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)
        dir
      end

      # Ported from upstream's _get_plugins_dirs: every immediate
      # subdirectory of the plugins directory that contains a `plugin.rb`
      # file, each one added to the load path.
      def plugin_dirs(root)
        Dir.children(root).sort.filter_map do |name|
          dir = File.join(root, name)
          next unless File.file?(File.join(dir, 'plugin.rb'))

          $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)
          {name: name, dir: dir}
        end
      end

      # Ported from upstream's _install_plugin_deps: if the plugin ships a
      # dependency manifest, install it into a plugin-local directory and
      # put that directory on the load path, rather than touching the app's
      # own bundle.
      def install_plugin_deps(dir)
        gemfile = File.join(dir, 'Gemfile')
        return unless File.file?(gemfile)

        dependencies_dir = File.join(dir, 'dependencies')
        if File.directory?(dependencies_dir)
          $LOAD_PATH.unshift(dependencies_dir) unless $LOAD_PATH.include?(dependencies_dir)
          return
        end

        FileUtils.mkdir_p(dependencies_dir)
        $LOAD_PATH.unshift(dependencies_dir)
        system(
          'bundle', 'install',
          '--gemfile', gemfile,
          '--path', dependencies_dir,
          exception: true,
        )
      end

      # Ported from upstream's _load_plugin: installs the plugin's own
      # dependencies, requires its entry file, and instantiates the `Plugin`
      # class it defines.
      def load_plugin(name, dir)
        Log.info("Plugins: Loading #{name}")
        install_plugin_deps(dir)
        require File.join(dir, 'plugin.rb')
        @plugins << Object.const_get(:Plugin).new
      end

      # Ported from upstream's _load_plugins: the loader's main loop over
      # every discovered plugin directory.
      def load_plugins
        plugin_dirs(user_plugins_dir).each do |entry|
          add_resources_path(entry[:dir])
          load_plugin(entry[:name], entry[:dir])
        end
      end
  end
end
