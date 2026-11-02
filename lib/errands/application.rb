# frozen_string_literal: true

require 'adwaita'

require_relative 'attachments_dialog'
require_relative 'data'
require_relative 'datetime_dialog'
require_relative 'icons'
require_relative 'logging'
require_relative 'notes_dialog'
require_relative 'settings'
require_relative 'state'
require_relative 'style'
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
  # through the XDG portal (libportal has no Ruby binding) and its
  # notifications daemon is a component of its own; both arrive with the
  # components behind them rather than being faked here.
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
        app.add_window(window.build)
      end

      def activate
        Log.debug('Application: Activate')
        window.present
      end
  end
end
