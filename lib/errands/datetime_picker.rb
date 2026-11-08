# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'
require_relative 'utils'

module Errands
  # DatetimePicker picks a date and a time.
  #
  # Ported from upstream's errands/widgets/shared/datetime_picker.py: the big
  # human-readable label, two spin buttons for the time, the four time presets
  # and the four day presets, and a calendar underneath.
  #
  # Upstream moves the calendar with Gtk.Calendar.select_day and a
  # GLib.DateTime; the Ruby bindings have no GLib::DateTime constructor that
  # takes a date, so the calendar's year / month / day properties are set
  # instead (month is zero-based, as GTK defines it).
  #
  class DatetimePicker
    SPACING = 12
    TIME_PRESETS = [
      ['09:00', 'errands-daytime-morning-symbolic'],
      ['13:00', 'errands-theme-light-symbolic'],
      ['17:00', 'errands-daytime-sunset-symbolic'],
      ['20:00', 'errands-theme-dark-symbolic'],
    ].freeze

    def initialize(margins: 0)
      @margins = margins
      @datetime = ''
      @lock_signals = true
    end

    attr_reader :datetime

    def build
      box.tap do |container|
        container.append(label)
        container.append(top_separator)
        container.append(controls_box)
        container.append(bottom_separator)
        container.append(calendar)

        controls_box.tap do |controls|
          controls.append(time_box)
          controls.append(presets_box)

          time_box.tap do |times|
            times.append(hours)
            times.append(colon_label)
            times.append(minutes)

            hours.signal_connect('value-changed') { on_date_time_changed }
            minutes.signal_connect('value-changed') { on_date_time_changed }
          end

          presets_box.tap do |presets|
            presets.append(time_presets_box)
            presets.append(presets_separator)
            presets.append(day_presets_box)

            time_presets_box.tap do |rows|
              rows.append(first_time_presets_row)
              rows.append(second_time_presets_row)

              first_time_presets_row.tap do |row|
                row.append(time_preset_buttons['09:00'])
                row.append(time_preset_buttons['13:00'])
              end

              second_time_presets_row.tap do |row|
                row.append(time_preset_buttons['17:00'])
                row.append(time_preset_buttons['20:00'])
              end

              time_preset_buttons.each do |preset, button|
                button.signal_connect('clicked') { apply_time_preset(preset) }
              end
            end

            day_presets_box.tap do |rows|
              rows.append(first_day_presets_row)
              rows.append(second_day_presets_row)

              first_day_presets_row.tap do |row|
                row.append(today_button)
                row.append(tomorrow_button)

                today_button.signal_connect('clicked') { self.datetime = Time.now.strftime('%Y%m%d') }
                tomorrow_button.signal_connect('clicked') do
                  self.datetime = (Time.now + (60 * 60 * 24)).strftime('%Y%m%d')
                end
              end

              second_day_presets_row.tap do |row|
                row.append(now_button)
                row.append(clear_button)

                now_button.signal_connect('clicked') { self.datetime = Time.now.strftime('%Y%m%dT%H%M00') }
                clear_button.signal_connect('clicked') { self.datetime = '' }
              end
            end
          end
        end

        calendar.signal_connect('day-selected') { on_date_time_changed }

        container.margin_start = @margins
        container.margin_end = @margins
        container.margin_top = @margins
        container.margin_bottom = @margins
      end
    end

    # Moves the whole widget to the given timestamp, or to today when the
    # timestamp is empty.
    def datetime=(value)
      @lock_signals = true
      @datetime = value.to_s
      if @datetime.empty?
        clear_fields
      else
        apply_fields(@datetime)
      end
      @lock_signals = false
      if @datetime.empty?
        label.label = Translations.gettext('Set Date')
      else
        label.label = human_datetime
      end
    end

    def human_datetime = Utils.human_datetime(datetime)

    # Memoized widget methods

    def box
      @box ||= Gtk::Box.new(:vertical, SPACING)
    end

    def label
      @label ||= Gtk::Label.new.tap do |text|
        text.halign = :center
        text.add_css_class('title-2')
      end
    end

    def top_separator = @top_separator ||= dim_separator

    def bottom_separator = @bottom_separator ||= dim_separator

    def presets_separator = @presets_separator ||= dim_separator

    def controls_box
      @controls_box ||= Gtk::Box.new(:horizontal, 6).tap do |container|
        container.halign = :center
      end
    end

    def time_box
      @time_box ||= Gtk::Box.new(:horizontal, 6).tap do |container|
        container.halign = :center
      end
    end

    def colon_label
      @colon_label ||= Gtk::Label.new(':').tap do |text|
        text.add_css_class('heading')
      end
    end

    def hours = @hours ||= time_spin_button(23)

    def minutes = @minutes ||= time_spin_button(59)

    def presets_box = @presets_box ||= Gtk::Box.new(:vertical, 6)

    def time_presets_box = @time_presets_box ||= Gtk::Box.new(:vertical, 6)

    def day_presets_box = @day_presets_box ||= Gtk::Box.new(:vertical, 6)

    def first_time_presets_row = @first_time_presets_row ||= homogeneous_row

    def second_time_presets_row = @second_time_presets_row ||= homogeneous_row

    def first_day_presets_row = @first_day_presets_row ||= homogeneous_row

    def second_day_presets_row = @second_day_presets_row ||= homogeneous_row

    def time_preset_buttons
      @time_preset_buttons ||= TIME_PRESETS.to_h do |preset, icon_name|
        [preset, content_button(preset, icon_name)]
      end
    end

    def today_button = @today_button ||= flat_button(Translations.gettext('Today'))

    def tomorrow_button = @tomorrow_button ||= flat_button(Translations.gettext('Tomorrow'))

    def now_button = @now_button ||= flat_button(Translations.gettext('Now'))

    def clear_button
      @clear_button ||= content_button(Translations.gettext('Clear'), 'errands-delete-all-symbolic')
    end

    def calendar = @calendar ||= Gtk::Calendar.new

    private

      def dim_separator
        Gtk::Separator.new(:horizontal).tap do |line|
          line.margin_start = 6
          line.margin_end = 6
          line.add_css_class('dim-label')
        end
      end

      def homogeneous_row
        Gtk::Box.new(:horizontal, 6).tap do |row|
          row.homogeneous = true
        end
      end

      def time_spin_button(upper)
        Gtk::SpinButton.new(
          Gtk::Adjustment.new(
            0,
            0,
            upper,
            1,
            1,
            0,
          ),
          1,
          0,
        ).tap do |spin|
          spin.orientation = :vertical
          spin.numeric = true
        end
      end

      def flat_button(text)
        Gtk::Button.new(label: text).tap do |button|
          button.add_css_class('flat')
        end
      end

      def content_button(text, icon_name)
        Gtk::Button.new.tap do |button|
          button.add_css_class('flat')
          button.child = Adwaita::ButtonContent.new.tap do |content|
            content.label = text
            content.icon_name = icon_name
          end
        end
      end

      # Upstream reads the hour and minute back off the preset button's label;
      # here the preset string is the key the button was built from.
      def apply_time_preset(preset)
        hour, minute = preset.split(':')
        hours.value = hour.to_i
        minutes.value = minute.to_i
      end

      def clear_fields
        hours.value = 0
        minutes.value = 0
        select_date(Time.now)
      end

      def apply_fields(value)
        if value.include?('T')
          digits = Utils.parse_datetime(value).strftime('%Y%m%dT%H%M%S')
          hours.value = digits[9, 2].to_i
          minutes.value = digits[11, 2].to_i
        else
          hours.value = 0
          minutes.value = 0
        end
        select_date(Utils.parse_datetime(value))
      end

      def select_date(time)
        calendar.year = time.year
        calendar.month = time.month - 1
        calendar.day = time.day
      end

      def on_date_time_changed
        unless @lock_signals
          self.datetime = format(
            '%<date>sT%<hour>02d%<minute>02d00',
            date:   calendar.date.format('%Y%m%d'),
            hour:   hours.value_as_int,
            minute: minutes.value_as_int,
          )
        end
      end
  end
end
