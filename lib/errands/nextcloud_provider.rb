# frozen_string_literal: true

require_relative 'caldav_provider'
require_relative 'settings'

module Errands
  # NextcloudProvider is CaldavProvider with Nextcloud's URL conventions
  # filled in: a bare hostname becomes https://, and the CalDAV entry point
  # is appended when the user's URL doesn't already carry one.
  #
  # Ported from upstream's SyncProviderNextcloud in
  # errands/lib/sync/providers/nextcloud.py, which is exactly this: a
  # SyncProviderCalDAV subclass that only overrides `_check_url`.
  #
  class NextcloudProvider < CaldavProvider
    def initialize(testing: false)
      super(testing: testing, name: 'Nextcloud')
    end

    protected

      def check_url
        Log.debug('Sync: Checking URL')
        @url = Settings.get('sync-url')
        add_protocol
        add_dav_suffix
        Log.debug("Sync: URL is set to #{@url}")
      end

    private

      def add_protocol
        unless @url.to_s.start_with?('http')
          @url = "https://#{@url}"
          Settings.set('sync-url', @url)
        end
      end

      def add_dav_suffix
        if Settings.get('sync-url').to_s.include?('remote.php')
          @url = Settings.get('sync-url')
        else
          @url = "#{@url}/remote.php/dav/"
          Settings.set('sync-url', @url)
        end
      end
  end
end
