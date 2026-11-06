# frozen_string_literal: true

require 'goa-rb'

require_relative 'logging'

module Errands
  # Goa looks up GNOME Online Accounts credentials for a password-based
  # account by its provider name (e.g. "Nextcloud"), for the sync providers
  # to use instead of asking the user to type a URL and password by hand.
  #
  # Ported from the get_goa_credentials function in upstream's
  # errands/lib/goa.py, over the goa-rb gem's GObject Introspection binding
  # rather than gi.require_version("Goa", "1.0").
  #
  module Goa
    GoaCredentials = Struct.new(:url, :username, :password)

    class << self
      def get_goa_credentials(account_name)
        matching_object(account_name).then do |object|
          if object
            credentials_for(object, object.account)
          end
        end
      rescue StandardError => e
        Log.error("GOA: Can't get credentials. #{e.message}")
        nil
      end

      private

        def client = @client ||= ::Goa::Client.new

        def matching_object(account_name)
          client.accounts.find { |object| object.account&.provider_name == account_name }
        end

        def credentials_for(object, account)
          Log.debug("GOA: Getting data for #{account.provider_name}")
          identity = account.presentation_identity
          if identity.include?('@')
            username = identity.rpartition('@').first
          else
            username = identity
          end
          domain = identity.split('@').last
          password = object.password_based&.call_get_password_sync(account.id)
          GoaCredentials.new(url_for(object, username, domain), username, password)
        end

        def url_for(object, username, domain)
          object.calendar&.uri&.sub("#{username}@", '') || "https://#{domain}/remote.php/dav/"
        end
    end
  end
end
