# frozen_string_literal: true

require 'adwaita'

require_relative 'goa'
require_relative 'settings'
require_relative 'sync'
require_relative 'translations'

module Errands
  # PreferencesDialog is the app's preferences: theme, task list behaviour,
  # notifications/background, and the sync provider's credentials.
  #
  # Ported from upstream's PreferencesWindow in errands/widgets/preferences.py
  # (an Adw.PreferencesDialog with a General page and a Sync page).
  #
  # Upstream's "Launch on Startup" switch calls back into
  # State.application.run_in_background (upstream's ErrandsApplication is
  # the Adw.Application itself); the Ruby port's `Application` is a
  # separate wrapper object, not what `State.application` holds, so this
  # calls `Application.run_in_background` directly. See application.rb for
  # what that call does given ashpd's current, Background-portal-less
  # release.
  #
  class PreferencesDialog < Adwaita::PreferencesDialog
    PROVIDER_NAMES = [Translations.gettext('Disabled'), 'Nextcloud', 'CalDAV'].freeze

    def build
      tap do |dialog|
        dialog.add(general_page)
        dialog.add(sync_page)

        general_page.tap do |page|
          page.add(theme_group)
          page.add(task_list_group)
          page.add(notifications_and_background_group)

          theme_group.tap do |group|
            group.add(theme_system_row)
            group.add(theme_light_row)
            group.add(theme_dark_row)

            theme_system_row.add_suffix(theme_system_check)
            theme_system_row.activatable_widget = theme_system_check
            theme_light_row.add_suffix(theme_light_check)
            theme_light_row.activatable_widget = theme_light_check
            theme_dark_row.add_suffix(theme_dark_check)
            theme_dark_row.activatable_widget = theme_dark_check
          end

          task_list_group.add(new_task_position_row)

          notifications_and_background_group.tap do |group|
            group.add(notifications_row)
            group.add(background_row)
            group.add(launch_on_startup_row)
          end
        end

        sync_page.tap do |page|
          page.add(sync_group)

          sync_group.tap do |group|
            group.add(sync_provider_row)
            group.add(sync_url_row)
            group.add(sync_username_row)
            group.add(sync_password_row)
            group.add(test_connection_row)

            test_connection_row.add_suffix(test_connection_button)
            test_connection_row.activatable_widget = test_connection_button
          end
        end

        update_sync_visibility
      end
    end

    # Memoized widget methods — General page

    def general_page
      @general_page ||= Adwaita::PreferencesPage.new.tap do |page|
        page.title = Translations.gettext('General')
        page.icon_name = 'errands-settings-symbolic'
      end
    end

    def theme_group = @theme_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = Translations.gettext('Application Theme') }

    def theme_system_check
      @theme_system_check ||= Gtk::CheckButton.new.tap do |check|
        check.active = Settings.get('theme') == 0
        check.signal_connect('toggled') { on_theme_toggled(check, 0) }
      end
    end

    def theme_light_check
      @theme_light_check ||= Gtk::CheckButton.new.tap do |check|
        check.group = theme_system_check
        check.active = Settings.get('theme') == 1
        check.signal_connect('toggled') { on_theme_toggled(check, 1) }
      end
    end

    def theme_dark_check
      @theme_dark_check ||= Gtk::CheckButton.new.tap do |check|
        check.group = theme_system_check
        check.active = Settings.get('theme') == 4
        check.signal_connect('toggled') { on_theme_toggled(check, 4) }
      end
    end

    def theme_system_row
      @theme_system_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = Translations.gettext('System')
        row.icon_name = 'errands-theme-system-symbolic'
      end
    end

    def theme_light_row
      @theme_light_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = Translations.gettext('Light')
        row.icon_name = 'errands-theme-light-symbolic'
      end
    end

    def theme_dark_row
      @theme_dark_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = Translations.gettext('Dark')
        row.icon_name = 'errands-theme-dark-symbolic'
      end
    end

    def task_list_group = @task_list_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = Translations.gettext('Task Lists') }

    def new_task_position_row
      @new_task_position_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = Translations.gettext('Add new Tasks')
        row.icon_name = 'errands-add-symbolic'
        row.model = Gtk::StringList.new([Translations.gettext('At the Bottom'), Translations.gettext('At the Top')])
        if Settings.get('task-list-new-task-position-top')
          row.selected = 1
        else
          row.selected = 0
        end
        row.signal_connect('notify::selected') do
          Settings.set('task-list-new-task-position-top', row.selected == 1)
        end
      end
    end

    def notifications_and_background_group
      @notifications_and_background_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = Translations.gettext('Notifications and Background')
      end
    end

    def notifications_row
      @notifications_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = Translations.gettext('Show Notifications')
        row.icon_name = 'errands-notification-symbolic'
        Settings.bind('notifications-enabled', row, 'active')
      end
    end

    def background_row
      @background_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = Translations.gettext('Run in Background')
        row.subtitle = Translations.gettext('Hide the application window instead of closing it')
        row.icon_name = 'errands-progressbar-symbolic'
        Settings.bind('run-in-background', row, 'active')
      end
    end

    def launch_on_startup_row
      @launch_on_startup_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = Translations.gettext('Launch on Startup')
        row.subtitle = Translations.gettext('Launch application when user logs in')
        row.icon_name = 'errands-progressbar-symbolic'
        Settings.bind('launch-on-startup', row, 'active')
        row.signal_connect('notify::active') { Application.run_in_background }
      end
    end

    # Memoized widget methods — Sync page

    def sync_page
      @sync_page ||= Adwaita::PreferencesPage.new.tap do |page|
        page.title = Translations.gettext('Sync')
        page.icon_name = 'errands-sync-symbolic'
      end
    end

    def sync_group = @sync_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = Translations.gettext('Sync') }

    def sync_provider_row
      @sync_provider_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = Translations.gettext('Sync Provider')
        row.icon_name = 'errands-sync-symbolic'
        row.model = Gtk::StringList.new(PROVIDER_NAMES)
        row.selected = Settings.get('sync-provider')
        row.signal_connect('notify::selected') do
          Settings.set('sync-provider', row.selected)
          update_sync_visibility
        end
      end
    end

    def sync_url_row
      @sync_url_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = Translations.gettext('Server URL')
        Settings.bind('sync-url', row, 'text')
      end
    end

    def sync_username_row
      @sync_username_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = Translations.gettext('Username')
        Settings.bind('sync-username', row, 'text')
      end
    end

    def sync_password_row
      @sync_password_row ||= Adwaita::PasswordEntryRow.new.tap do |row|
        row.title = Translations.gettext('Password')
        row.signal_connect('changed') { on_password_changed(row) }
      end
    end

    def test_connection_row = @test_connection_row ||= Adwaita::ActionRow.new.tap { |row| row.title = Translations.gettext('Test Connection') }

    def test_connection_button
      @test_connection_button ||= Gtk::Button.new(label: Translations.gettext('Test')).tap do |button|
        button.valign = :center
        button.signal_connect('clicked') { on_test_connection_clicked }
      end
    end

    private

      def on_theme_toggled(check, theme)
        if check.active?
          Adwaita::StyleManager.default.color_scheme = theme
          Settings.set('theme', theme)
        end
      end

      def selected_provider_name = PROVIDER_NAMES[sync_provider_row.selected]

      def update_sync_visibility
        selected = sync_provider_row.selected
        shows_credentials = selected.positive? && selected < PROVIDER_NAMES.length
        sync_url_row.visible = shows_credentials
        sync_username_row.visible = shows_credentials
        sync_password_row.visible = shows_credentials
        test_connection_row.visible = selected.positive?
        if shows_credentials
          sync_password_row.text = Settings.get_secret(selected_provider_name).to_s
          fill_from_goa
        end
      end

      def fill_from_goa
        Goa.get_goa_credentials(selected_provider_name).then do |credentials|
          if credentials
            if Settings.get('sync-url').to_s.empty?
              sync_url_row.text = credentials.url
            end
            if Settings.get('sync-username').to_s.empty?
              sync_username_row.text = credentials.username
            end
            if Settings.get_secret(selected_provider_name).to_s.empty?
              sync_password_row.text = credentials.password.to_s
            end
          end
        end
      end

      def on_password_changed(row)
        selected = sync_provider_row.selected
        if selected.positive? && selected < PROVIDER_NAMES.length
          Settings.set_secret(selected_provider_name, row.text)
        end
      end

      def on_test_connection_clicked
        can_sync, error = Sync.test_connection
        add_toast(Adwaita::Toast.new(test_connection_message(can_sync, error)))
      end

      def test_connection_message(can_sync, error)
        if can_sync
          Translations.gettext('Connected')
        else
          error_message(error)
        end
      end

      def error_message(error)
        case error
        when Caldav::AuthorizationError then Translations.gettext('Authorization failed')
        when Caldav::ConnectionError then Translations.gettext('Could not locate server. Check network and url.')
        when Caldav::PropfindError then Translations.gettext("Can't connect")
        else Translations.gettext("Can't connect. Check credentials")
        end
      end
  end
end
