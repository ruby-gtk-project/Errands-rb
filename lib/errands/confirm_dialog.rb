# frozen_string_literal: true

require 'adwaita'

require_relative 'state'
require_relative 'translations'

module Errands
  # ConfirmDialog asks before something destructive happens.
  #
  # Ported from the ConfirmDialog class in upstream's
  # errands/widgets/shared/components/dialogs.py. Upstream subclasses the
  # deprecated Adw.MessageDialog; Adwaita::AlertDialog is its replacement and
  # takes the same heading, body and responses.
  #
  class ConfirmDialog < Adwaita::AlertDialog
    def initialize(text, confirm_text, style, &on_confirm)
      super()
      @text = text
      @confirm_text = confirm_text
      @style = style
      @on_confirm = on_confirm
    end

    def build
      tap do |dialog|
        dialog.heading = Translations.gettext('Are you sure?')
        dialog.body = @text
        dialog.add_response('cancel', Translations.gettext('Cancel'))
        dialog.add_response('confirm', @confirm_text)
        dialog.set_response_appearance('confirm', @style)
        dialog.default_response = 'confirm'
        dialog.close_response = 'cancel'

        dialog.signal_connect('response') { |_, response| @on_confirm.call(response) }
      end
    end

    # Upstream presents itself from its constructor; here the call site builds
    # and shows it in one expression.
    def self.show(text, confirm_text, style, &on_confirm)
      new(
        text,
        confirm_text,
        style,
        &on_confirm
      ).build.present(State.main_window.root)
    end
  end
end
