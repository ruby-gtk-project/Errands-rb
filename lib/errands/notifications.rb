# frozen_string_literal: true

require 'adwaita'
require 'date'

require_relative 'data'
require_relative 'logging'
require_relative 'settings'
require_relative 'state'

module Errands
  # Notifications is the notifications daemon: every 20 seconds it checks
  # for tasks whose due date has passed and sends a desktop notification for
  # each, once.
  #
  # Ported from the ErrandsNotificationsDaemon class in upstream's
  # errands/lib/notifications.py.
  #
  class Notifications
    CHECK_INTERVAL_SEC = 20

    def start
      State.notifications = self
      GLib::Timeout.add_seconds(CHECK_INTERVAL_SEC) { check_data }
      self
    end

    # ------ PROPERTIES ------ #

    # Due tasks that have not been notified yet.
    def due_tasks
      now = DateTime.now
      UserData.tasks.select do |task|
        !task.due_date.to_s.empty? && !task.deleted && !task.completed && !task.trash && !task.notified &&
          DateTime.parse(task.due_date) < now
      end
    end

    # ------ PUBLIC METHODS ------ #

    def send(id, notification)
      State.application.send_notification(id, notification)
    end

    private

      def check_data
        if Settings.get('notifications-enabled')
          Log.debug('Notifications: Check')
          due_tasks.each do |task|
            send_due_notification(task)
            UserData.update_props(
              task.list_uid,
              task.uid,
              [:notified],
              [true],
            )
          end
        end
        true
      end

      def send_due_notification(task)
        Log.debug("Notifications: Send: #{task.uid}")
        Gio::Notification.new('Task is Due').tap do |notification|
          notification.body = task.text
          send(task.uid, notification)
        end
      end
  end
end
