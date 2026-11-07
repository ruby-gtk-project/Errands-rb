# frozen_string_literal: true

require_relative 'caldav_provider'
require_relative 'data'
require_relative 'logging'
require_relative 'nextcloud_provider'
require_relative 'settings'
require_relative 'state'
require_relative 'utils'

module Errands
  # Sync is the facade the window and the preferences dialog call: pick the
  # configured provider, run it off the UI thread, and keep the syncing page
  # and the sidebar's spinner in step with it.
  #
  # Ported from upstream's Sync class in errands/lib/sync/sync.py.
  #
  module Sync
    class << self
      attr_accessor :provider
      attr_reader :syncing

      def init(testing: false)
        Log.info('Sync: Initialize sync provider')
        case Settings.get('sync-provider')
        when 0
          Log.info('Sync: Sync disabled')
          UserData.clean_deleted
        when 1
          self.provider = NextcloudProvider.new(testing: testing)
        when 2
          self.provider = CaldavProvider.new(testing: testing)
        end
      end

      # Runs the sync off the UI thread. Anything it touches on a widget
      # comes back through Utils.idle_add, the same rule every other
      # background call in this port follows.
      def sync
        Utils.threaded { run_sync }
      end

      def test_connection
        init(testing: true)
        [provider&.can_sync, provider&.err]
      end

      private

        def run_sync
          if Settings.get('sync-provider').zero?
            UserData.clean_deleted
          else
            sync_with_provider
          end
        end

        def sync_with_provider
          if provider.nil?
            toggle_indicator(true)
            init
            toggle_indicator(false)
          end
          if provider && provider.can_sync
            perform_sync
          end
        end

        def perform_sync
          if syncing
            @sync_again = true
          else
            run_provider_sync
          end
        end

        def run_provider_sync
          @syncing = true
          show_syncing_page
          toggle_indicator(true)
          provider.sync
          UserData.clean_deleted
          if @sync_again
            @sync_again = false
            run_provider_sync
          end
          toggle_indicator(false)
          @syncing = false
          hide_syncing_page
        end

        def show_syncing_page
          if State.view_stack&.visible_child_name == 'errands_status_page'
            Utils.idle_add { State.view_stack.visible_child_name = 'errands_syncing_page' }
          end
        end

        def hide_syncing_page
          if State.view_stack&.visible_child_name == 'errands_syncing_page' && !UserData.task_lists.empty?
            Utils.idle_add { State.view_stack.visible_child_name = 'errands_today_page' }
          end
        end

        def toggle_indicator(on)
          Utils.idle_add { State.sidebar&.toggle_sync_indicator(on) }
        end
    end
  end
end
