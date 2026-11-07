# frozen_string_literal: true

require 'adwaita'
require 'ashpd'

require_relative 'attachments_dialog'
require_relative 'data'
require_relative 'datetime_dialog'
require_relative 'icons'
require_relative 'logging'
require_relative 'notes_dialog'
require_relative 'notifications'
require_relative 'plugins'
require_relative 'settings'
require_relative 'state'
require_relative 'style'
require_relative 'sync'
require_relative 'translations'
require_relative 'window'

module Errands
  # Application starts Errands: the data layer, the settings, the icons and the
  # stylesheet, then the main window.
  #
  # Ported from upstream's errands/application.py and errands/errands.py.
  #
  # Adwaita::Application is unusable from the Ruby bindings, so the application
  # object is a Gtk::Application; Adwaita is initialised explicitly, which
  # Adw.Application would otherwise do. Upstream's autostart request goes
  # through the XDG background portal (`Xdp::Portal#request_background` from
  # libportal). `ashpd` is this app's one portal-binding gem, so it is queried
  # for that portal at runtime rather than assuming either way from a comment:
  # `Ashpd.const_defined?(:Background)` is false on the 0.1.1 release this app
  # locks (`Ashpd.constants` is `[Account, Camera, OpenUri, Screenshot,
  # Settings, Trash, VERSION]`; calling `Ashpd::Background` raises `NameError:
  # uninitialized constant Ashpd::Background`). `run_in_background` below logs
  # that and skips the request rather than faking it; if a future ashpd
  # release adds the Background portal this check starts using it with no
  # other change needed.
  #
  class Application
    def build
      app.tap do |application|
        application.signal_connect('startup') { startup }
        application.signal_connect('activate') { activate }
      end
    end

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the widgets are Adwaita.
    def app = @app ||= Gtk::Application.new(State::APP_ID, :default_flags)

    def window = @window ||= Window.new(app)

    # Ported from upstream's `run_in_background` (errands/application.py):
    # requests the background portal so the app can keep running (and,
    # when "Launch on Startup" is enabled, autostart) after its window
    # closes. Called at startup and again whenever the preferences dialog's
    # autostart switch changes.
    #
    # A class method, not an instance method: `State.application` (which
    # the preferences dialog's switch reaches for) holds the raw
    # `Gtk::Application` from `app` above, not this `Errands::Application`
    # wrapper — and this call needs no instance state, only Settings/Log/
    # Ashpd, all already module-level.
    class << self
      def run_in_background
        Log.debug('Application: Checking autostart')
        if Ashpd.const_defined?(:Background)
          Ashpd::Background.request(Settings.get('launch-on-startup'))
        else
          Log.info(
            'Application: ashpd has no Background portal ' \
            "(Ashpd.constants is #{Ashpd.constants.sort}); " \
            'autostart request skipped',
          )
        end
      end
    end

    private

      def startup
        Adwaita.init
        Log.init
        Log.debug('Application: Startup')
        UserData.init
        Settings.init
        Icons.install
        Style.install
        State.application = app
        State.init
        Application.run_in_background
        Notifications.new.start
        # Upstream imports PluginsLoader commented-out at this call site
        # (`# from errands.lib.plugins import PluginsLoader`), but the class
        # itself is live, uncommented code, so the port wires it in rather
        # than leaving it dead.
        @plugins_loader = PluginsLoader.new(app)
        app.add_window(window.build)
      end

      def activate
        Log.debug('Application: Activate')
        window.present
      end
  end
end
