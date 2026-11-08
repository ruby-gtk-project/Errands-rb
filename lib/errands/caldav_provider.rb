# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'rexml/document'
require 'uri'

require_relative 'data'
require_relative 'logging'
require_relative 'settings'
require_relative 'state'
require_relative 'translations'

module Errands
  # Caldav holds the WebDAV/CalDAV HTTP primitives the sync providers run
  # over: PROPFIND/REPORT/PUT/DELETE/MKCALENDAR/PROPPATCH requests and the
  # handful of multistatus-XML readers that come back from them.
  #
  # Upstream (errands/lib/sync/providers/caldav.py) gets this for free from
  # the Python `caldav` library. No Ruby gem binds libcurl/WebDAV the way that
  # library does, and `ashpd`/`goa-rb` are the two binding gems this app
  # ships, neither of which speaks CalDAV, so the protocol — PROPFIND-based
  # principal and calendar-home-set discovery (RFC 4791 §5-6), a
  # calendar-query REPORT for VTODOs, and PUT/DELETE for individual tasks —
  # is implemented directly over Net::HTTP and REXML, both standard library.
  #
  module Caldav
    DAV_NS = 'DAV:'
    CALDAV_NS = 'urn:ietf:params:xml:ns:caldav'
    APPLE_NS = 'http://apple.com/ns/ical/'

    # The credentials were rejected (HTTP 401/403).
    class AuthorizationError < StandardError; end

    # The server could not be reached at all (DNS, TCP, TLS).
    class ConnectionError < StandardError; end

    # A WebDAV request the protocol needs came back malformed or with an
    # unexpected status.
    class PropfindError < StandardError; end

    # One discovered calendar collection.
    CalendarInfo = Struct.new(
      :id,
      :url,
      :name,
      :color,
      :supports_vtodo,
    )

    # Client is the thin HTTP layer: it knows the five WebDAV methods this
    # provider needs and turns connection failures into the three error
    # classes above. It does not know what a calendar or a task is.
    class Client
      def initialize(url, username, password)
        @base = URI.parse(url)
        @username = username
        @password = password
      end

      def propfind(href, body, depth: '0') = request(
        'PROPFIND',
        href,
        body,
        'Depth' => depth,
      )

      def report(href, body, depth: '1') = request(
        'REPORT',
        href,
        body,
        'Depth' => depth,
      )

      def mkcalendar(href, body) = request('MKCALENDAR', href, body)

      def proppatch(href, body) = request('PROPPATCH', href, body)

      def put(href, body)
        request(
          'PUT',
          href,
          body,
          'Content-Type' => 'text/calendar; charset=utf-8',
        )
      end

      def delete(href) = request('DELETE', href, nil)

      def resolve(href) = URI.join(@base, href)

      private

        def request(method, href, body, extra_headers = {})
          uri = resolve(href)
          http(uri).request(
            build_request(
              method,
              uri,
              body,
              extra_headers,
            ),
          )
        rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout,
               OpenSSL::SSL::SSLError => e
          raise ConnectionError, e.message
        end

        def http(uri)
          Net::HTTP.new(uri.host, uri.port).tap do |client|
            client.use_ssl = uri.scheme == 'https'
            client.verify_mode = OpenSSL::SSL::VERIFY_NONE
            client.open_timeout = 10
            client.read_timeout = 15
          end
        end

        def build_request(method, uri, body, extra_headers)
          Net::HTTPGenericRequest.new(
            method,
            !body.nil?,
            true,
            uri,
          ).tap do |req|
            req.basic_auth(@username, @password)
            req['Content-Type'] = 'application/xml; charset=utf-8'
            extra_headers.each { |key, value| req[key] = value }
            if body
              req.body = body
            end
          end
        end
    end

    # The handful of XPath-ish lookups the discovery and listing steps need
    # out of a multistatus response. REXML gives no namespace-aware
    # XPath::each helper that is simpler than walking this by hand.
    module Multistatus
      module_function

      def check!(response)
        case response.code.to_i
        when 207 then nil
        when 401, 403 then raise AuthorizationError, "HTTP #{response.code}"
        else raise PropfindError, "unexpected HTTP #{response.code} for #{response.uri}"
        end
      end

      def document(response)
        check!(response)
        REXML::Document.new(response.body.to_s)
      rescue REXML::ParseException => e
        raise PropfindError, "could not parse WebDAV response: #{e.message}"
      end

      def responses(response) = REXML::XPath.match(document(response), '//*[local-name()="response"]')

      def href(element) = text_of(element, 'href')

      def text_of(element, local_name)
        REXML::XPath.first(element, ".//*[local-name()='#{local_name}']")&.text&.strip
      end

      def has_element?(element, local_name)
        !REXML::XPath.first(element, ".//*[local-name()='#{local_name}']").nil?
      end

      def component_names(element)
        REXML::XPath.match(element, ".//*[local-name()='comp']").map { |comp| comp.attributes['name'] }
      end
    end

    # CalendarBuilder turns a PROPFIND(resourcetype, displayname,
    # supported-calendar-component-set, calendar-color) response into the
    # CalendarInfo list, keeping only the collections that support VTODO —
    # the same filter upstream's `"VTODO" in cal.get_supported_components()`
    # applies.
    module CalendarBuilder
      module_function

      def from_response(response, base_href)
        Multistatus.responses(response).filter_map { |node| calendar_from(node, base_href) }
      end

      def calendar_from(node, base_href)
        href = Multistatus.href(node)
        if href.nil? || href == base_href || !Multistatus.has_element?(node, 'calendar')
          nil
        elsif !Multistatus.component_names(node).include?('VTODO')
          nil
        else
          CalendarInfo.new(
            id_from(href),
            href,
            Multistatus.text_of(node, 'displayname'),
            Multistatus.text_of(node, 'calendar-color'),
            true,
          )
        end
      end

      def id_from(href) = href.to_s.delete_suffix('/').split('/').last
    end
  end

  # CaldavProvider is the generic CalDAV sync backend: it discovers the
  # account's calendars, then reconciles upstream's lists and tasks against
  # them in both directions.
  #
  # Ported from upstream's SyncProviderCalDAV in
  # errands/lib/sync/providers/caldav.py; the structure (check credentials,
  # check URL, connect, sync lists, sync tasks, update the UI once at the
  # end) and the per-list/per-task decision tables are the same. What differs
  # is only *how* a calendar is read and written, because there is no
  # `caldav` library here — see `Caldav` above.
  #
  class CaldavProvider
    attr_reader :can_sync, :err, :name

    def initialize(testing: false, name: 'CalDAV')
      Log.info("Sync: Initialize '#{name}' sync provider")
      @name = name
      @testing = testing
      @can_sync = false
      @err = nil
      @calendars = []
      if check_credentials
        check_url
        connect
      end
    end

    def sync
      Log.info('Sync: Sync tasks with remote')
      if refresh_calendars
        @touched_lists = []
        @touched_tasks = []
        @purged_lists = []
        @purged_tasks = []
        @update_trash = false
        @update_tags = false
        sync_lists
        if refresh_calendars
          sync_tasks
        end
        finish_sync
      end
    end

    protected

      # Overridden by NextcloudProvider to normalise the URL before it is
      # ever handed to the client.
      def check_url
        Log.debug('Sync: Checking URL')
        @url = Settings.get('sync-url')
        Log.debug("Sync: URL is set to #{@url}")
      end

    private

      def check_credentials
        Log.debug('Sync: Checking credentials')
        @url = Settings.get('sync-url')
        @username = Settings.get('sync-username')
        @password = Settings.get_secret(@name)
        if @url.to_s.empty? || @username.to_s.empty? || @password.to_s.empty?
          Log.error("Sync: Not all #{@name} credentials provided")
          unless @testing
            State.add_toast(Translations.gettext('Not all sync credentials provided. Please check settings.'))
          end
          false
        else
          true
        end
      end

      def connect
        Log.debug('Sync: Attempting connection')
        @err = nil
        @client = Caldav::Client.new(@url, @username, @password)
        @home_href = discover_home_set
        @calendars = discover_calendars(@home_href)
        @can_sync = true
        Log.info("Sync: Connected to #{@name} server at '#{@url}'")
      rescue Caldav::AuthorizationError, Caldav::ConnectionError, Caldav::PropfindError => e
        connection_failed(e)
      rescue StandardError => e
        connection_failed(e)
      end

      def connection_failed(error)
        @err = error
        @can_sync = false
        Log.error("Sync: Can't connect to #{@name} server at '#{@url}'. #{error.message}")
        unless @testing
          State.add_toast("#{Translations.gettext('Can\'t connect to CalDAV server at:')} #{@url}")
        end
      end

      def refresh_calendars
        @calendars = discover_calendars(@home_href)
        true
      rescue Caldav::AuthorizationError, Caldav::ConnectionError, Caldav::PropfindError => e
        Log.error("Sync: Can't get calendars from remote. #{e.message}")
        false
      end

      # ----- DISCOVERY ----- #

      PRINCIPAL_BODY = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <D:propfind xmlns:D="DAV:">
          <D:prop><D:current-user-principal/></D:prop>
        </D:propfind>
      XML

      HOME_SET_BODY = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
          <D:prop><C:calendar-home-set/></D:prop>
        </D:propfind>
      XML

      CALENDARS_BODY = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:A="http://apple.com/ns/ical/">
          <D:prop>
            <D:resourcetype/>
            <D:displayname/>
            <C:supported-calendar-component-set/>
            <A:calendar-color/>
          </D:prop>
        </D:propfind>
      XML

      TODOS_BODY = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
          <D:prop><D:getetag/><C:calendar-data/></D:prop>
          <C:filter>
            <C:comp-filter name="VCALENDAR"><C:comp-filter name="VTODO"/></C:comp-filter>
          </C:filter>
        </C:calendar-query>
      XML

      # RFC 4791 discovery: current-user-principal, then that principal's
      # calendar-home-set. A server that answers neither (some minimal
      # CalDAV-only endpoints) is treated as if the given URL were already
      # the home set, which is what upstream's own fallback amounts to.
      def discover_home_set
        principal_href = find_href(@client.propfind('', PRINCIPAL_BODY), 'current-user-principal') || ''
        home_href = find_href(@client.propfind(principal_href, HOME_SET_BODY), 'calendar-home-set')
        home_href || principal_href
      rescue Caldav::PropfindError
        ''
      end

      def find_href(response, property_name)
        Caldav::Multistatus.responses(response).filter_map { |node| href_within(node, property_name) }.first
      end

      def href_within(node, property_name)
        REXML::XPath.first(node, ".//*[local-name()='#{property_name}']//*[local-name()='href']")&.text&.strip
      end

      def discover_calendars(home_href)
        Caldav::CalendarBuilder.from_response(@client.propfind(home_href, CALENDARS_BODY, depth: '1'), home_href)
      end

      # ----- TASKS ----- #

      def remote_tasks(calendar)
        Caldav::Multistatus.responses(@client.report(calendar.url, TODOS_BODY, depth: '1'))
          .filter_map { |node| Caldav::Multistatus.text_of(node, 'calendar-data') }
          .map { |ical| TaskData.from_ical(ical, calendar.id) }
      rescue Caldav::AuthorizationError, Caldav::ConnectionError, Caldav::PropfindError => e
        Log.error("Sync: Can't get tasks from remote. #{e.message}")
        []
      end

      def task_href(calendar, task_uid) = "#{calendar.url.to_s.sub(%r{/?\z}, '/')}#{task_uid}.ics"

      # ----- SYNC LISTS ----- #

      def sync_lists
        add_local_lists
        remote_uids = @calendars.map(&:id)
        UserData.lists_as_dicts.each do |list|
          matching = @calendars.find { |cal| cal.id == list.uid }
          if matching
            if list.synced
              update_local_list(matching, list)
            else
              update_remote_list(matching, list)
            end
          end
          classify_list(list, remote_uids)
        end
      end

      def classify_list(list, remote_uids)
        has_remote = remote_uids.include?(list.uid)
        if !has_remote && !list.synced && !list.deleted
          create_remote_list(list)
        elsif !has_remote && list.synced && !list.deleted
          delete_local_list(list)
        elsif has_remote && list.deleted && list.synced
          delete_remote_list(list)
        end
      end

      def add_local_lists
        local_uids = UserData.lists_as_dicts.map(&:uid)
        @calendars.each do |calendar|
          unless local_uids.include?(calendar.id)
            Log.debug("Sync: Copy list from remote '#{calendar.id}'")
            @touched_lists << UserData.add_list(calendar.name.to_s, uuid: calendar.id, synced: true, color: calendar.color.to_s)
          end
        end
      end

      def delete_local_list(list)
        Log.debug("Sync: Delete local list deleted on remote '#{list.uid}'")
        UserData.delete_list(list.uid)
        @purged_lists << list.uid
        @update_trash = true
        @update_tags = true
      end

      def delete_remote_list(list)
        calendar = @calendars.find { |cal| cal.id == list.uid }
        if calendar
          Log.debug("Sync: Delete list on remote '#{calendar.id}'")
          begin
            @client.delete(calendar.url)
            UserData.delete_list(calendar.id)
          rescue Caldav::ConnectionError, Caldav::PropfindError, Caldav::AuthorizationError
            Log.debug("Sync: Can't delete list on remote '#{calendar.id}'")
          end
        end
      end

      def create_remote_list(list)
        Log.debug("Sync: Create remote list #{list.uid}")
        href = "#{@home_href.to_s.sub(%r{/?\z}, '/')}#{list.uid}/"
        @client.mkcalendar(href, mkcalendar_body(list))
        UserData.update_list_prop(list.uid, 'synced', true)
      rescue Caldav::ConnectionError, Caldav::PropfindError, Caldav::AuthorizationError => e
        Log.error("Sync: Can't create remote list '#{list.uid}'. #{e.message}")
      end

      def mkcalendar_body(list)
        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:A="http://apple.com/ns/ical/">
            <D:set><D:prop>
              <D:displayname>#{escape(list.name)}</D:displayname>
              <C:supported-calendar-component-set><C:comp name="VTODO"/></C:supported-calendar-component-set>
              <A:calendar-color>#{escape(list.color)}</A:calendar-color>
            </D:prop></D:set>
          </C:mkcalendar>
        XML
      end

      def update_local_list(calendar, list)
        if calendar.color.to_s.empty?
          color = list.color
        else
          color = calendar.color
        end
        if calendar.name.to_s.empty?
          name = list.name
        else
          name = calendar.name
        end
        if list.color != color || list.name != name
          Log.debug("Sync: Update local list '#{list.uid}'")
          UserData.update_list_props(calendar.id, %w[name color synced], [name, color, true])
          @touched_lists_renamed ||= []
          @touched_lists_renamed << calendar.id
          @update_trash = true
        end
      end

      def update_remote_list(calendar, list)
        if calendar.color.to_s.empty?
          color = list.color
        else
          color = calendar.color
        end
        if list.name != calendar.name || list.color != color
          Log.debug("Sync: Update remote list '#{list.uid}'")
          begin
            @client.proppatch(calendar.url, proppatch_body(list))
            UserData.update_list_prop(list.uid, 'synced', true)
          rescue Caldav::ConnectionError, Caldav::PropfindError, Caldav::AuthorizationError => e
            Log.error("Sync: Can't update remote list '#{list.uid}'. #{e.message}")
          end
        end
      end

      def proppatch_body(list)
        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <D:propertyupdate xmlns:D="DAV:" xmlns:A="http://apple.com/ns/ical/">
            <D:set><D:prop>
              <D:displayname>#{escape(list.name)}</D:displayname>
              <A:calendar-color>#{escape(list.color)}</A:calendar-color>
            </D:prop></D:set>
          </D:propertyupdate>
        XML
      end

      # ----- SYNC TASKS ----- #

      def sync_tasks
        @calendars.each do |calendar|
          sync_tasks_for(calendar)
        end
      end

      def sync_tasks_for(calendar)
        local = UserData.tasks_as_dicts(calendar.id)
        remote = remote_tasks(calendar)
        local_uids = local.map(&:uid)
        remote_uids = remote.map(&:uid)
        deleted_uids = UserData.tasks_as_dicts.select(&:deleted).map(&:uid)

        remote.each do |task|
          if !local_uids.include?(task.uid) && !deleted_uids.include?(task.uid)
            create_local_task(calendar, task)
          end
        end

        local.each do |task|
          decide_local_task(
            calendar,
            task,
            remote,
            remote_uids,
          )
        end
      end

      def decide_local_task(calendar, task, remote, remote_uids)
        if !remote_uids.include?(task.uid) && task.synced
          delete_local_task(task)
        elsif remote_uids.include?(task.uid) && task.deleted
          delete_remote_task(calendar, task)
        elsif !remote_uids.include?(task.uid) && !task.synced
          create_remote_task(calendar, task)
        elsif remote_uids.include?(task.uid) && !task.synced
          update_remote_task(calendar, task)
        elsif remote_uids.include?(task.uid) && task.synced
          update_local_task(task, remote.find { |remote_task| remote_task.uid == task.uid })
        end
      end

      SYNC_EXCLUDED_KEYS = %w[attachments synced trash expanded toolbar_shown deleted notified created_at].freeze

      def update_local_task(task, remote_task)
        updated = task.to_h.keys.reject { |key| SYNC_EXCLUDED_KEYS.include?(key) }
                      .select { |key| remote_task.to_h[key] != task.to_h[key] }
        unless updated.empty? || (updated == %w[changed_at] && remote_task.changed_at.to_s.empty?)
          Log.debug("Sync: Update local task '#{task.uid}'. Updated: #{updated}")
          UserData.update_props(
            task.list_uid,
            task.uid,
            updated,
            updated.map { |key| remote_task.to_h[key] },
          )
          if updated.include?('tags')
            @update_tags = true
          end
          @touched_tasks << task
        end
      end

      def update_remote_task(calendar, task)
        Log.debug("Sync: Update remote task '#{task.uid}'")
        @client.put(task_href(calendar, task.uid), task.to_ical)
        UserData.update_props(
          calendar.id,
          task.uid,
          %w[synced],
          [true],
        )
      rescue Caldav::ConnectionError, Caldav::PropfindError, Caldav::AuthorizationError => e
        Log.error("Sync: Can't update task on remote '#{task.uid}'. #{e.message}")
      end

      def create_remote_task(calendar, task)
        Log.debug("Sync: Create remote task '#{task.uid}'")
        @client.put(task_href(calendar, task.uid), task.to_ical)
        UserData.update_props(
          calendar.id,
          task.uid,
          %w[synced],
          [true],
        )
      rescue Caldav::ConnectionError, Caldav::PropfindError, Caldav::AuthorizationError => e
        Log.error("Sync: Can't create new task on remote: '#{task.uid}'. #{e.message}")
      end

      def delete_local_task(task)
        Log.debug("Sync: Delete local task '#{task.uid}'")
        UserData.delete_task(task.list_uid, task.uid)
        @purged_tasks << task
        @update_trash = true
        @update_tags = true
      end

      def delete_remote_task(calendar, task)
        Log.debug("Sync: Delete remote task '#{task.uid}'")
        @client.delete(task_href(calendar, task.uid))
      rescue Caldav::ConnectionError, Caldav::PropfindError, Caldav::AuthorizationError => e
        Log.error("Sync: Can't delete task from remote: '#{task.uid}'. #{e.message}")
      end

      def create_local_task(calendar, task)
        Log.debug("Sync: Copy new task from remote to list '#{calendar.id}': #{task.uid}")
        UserData.add_task(**task.to_h.transform_keys(&:to_sym))
        @touched_lists << calendar.id
      end

      # ----- FINISH ----- #

      def finish_sync
        Log.debug('Sync: Update UI')
        UserData.clean_orphans
        State.sidebar.update_task_lists
        if @update_tags
          UserData.update_tags
          State.tags_sidebar_row&.update_ui
        end
        if @update_trash
          State.trash_sidebar_row&.update_ui
        end
      end

      def escape(text) = text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end
end
