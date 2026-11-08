# frozen_string_literal: true

require 'adwaita'

require_relative 'state'
require_relative 'translations'

module Errands
  # AboutDialog is the application's About window.
  #
  # Ported from the _about action in upstream's errands/widgets/window.py,
  # which builds an Adw.AboutDialog with these fields.
  #
  class AboutDialog < Adwaita::AboutDialog
    def build
      tap do |dialog|
        dialog.version = State.version
        dialog.application_icon = 'io.github.mrvladus.List-symbolic'
        dialog.application_name = Translations.gettext('Errands')
        dialog.copyright = '© 2023-2024 Vlad Krupinskii'
        dialog.website = 'https://github.com/mrvladus/Errands'
        dialog.issue_url = 'https://github.com/mrvladus/Errands/issues'
        dialog.license_type = Gtk::License::MIT_X11
        dialog.translator_credits = Translations.gettext('translator-credits')
      end
    end
  end
end
