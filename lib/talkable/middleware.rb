require 'cgi'
require 'rack/request'

module Talkable
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      uuid = talkable_visitor_uuid(env)

      result = Talkable.with_uuid(uuid) do
        @app.call(env)
      end

      inject_uuid_in_cookie(uuid, result)
      modify_response_content(result) do |content|
        content = inject_uuid_in_body(uuid, content)
        inject_integration_js_in_head(content)
      end

    end

    protected

    def talkable_visitor_uuid(env)
      req = Rack::Request.new(env)
      req.params[UUID] || req.cookies[UUID] || Talkable.find_or_generate_uuid
    end

    def inject_uuid_in_cookie(uuid, result)
      Rack::Utils.set_cookie_header!(result[1], UUID, {value: uuid, path: '/', expires: cookies_expiration})
    end

    def modify_response_content(result)
      return result unless modifiable?(result)

      chunks = result[2]
      response_content = collect_content(chunks)
      chunks.close if chunks.respond_to?(:close)

      response_content = yield(response_content) if block_given?

      if response_content
        response = Rack::Response.new(response_content, result[0], result[1])
        response.finish
      else
        result
      end
    end

    def inject_uuid_in_body(uuid, content)
      if injection_index = body_injection_position(content)
        content = inject_in_content(content, sync_uuid_content(uuid), injection_index)
      end
      content
    end

    def inject_integration_js_in_head(content)
      if injection_index = head_injection_position(content)
        content = inject_in_content(content, integration_content, injection_index)
      end
      content
    end

    def inject_in_content(content, injection, position)
      content[0...position] << injection << content[position..-1]
    end

    def cookies_expiration
      Time.now + (20 * 365 * 24 * 60 * 60) # 20 years
    end

    def sync_uuid_url(uuid)
      Furi.update("https://www.talkable.com/public/1x1.gif", query: {current_visitor_uuid: uuid})
    end

    def sync_uuid_content(uuid)
      src = CGI::escapeHTML(sync_uuid_url(uuid))
      %Q{
<img src="#{src}" style="position:absolute; left:-9999px;" alt="" />
      }
    end

    def integration_content
      integration_script_content + integration_init_content
    end

    def integration_script_content
      %Q{
<script>
  window._talkableq = window._talkableq || [];
  _talkableq.push(['init', {
    site_id: '#{CGI::escape(Talkable.configuration.site_slug)}'
  }]);
</script>
      }
    end

    def integration_init_content
      src = CGI::escapeHTML(Talkable.configuration.js_integration_library)
      %Q{
<script src="#{src}" type="text/javascript"></script>
      }
    end

    def modifiable?(result)
      status, headers = result
      status == 200 && html?(headers) && !attachment?(headers)
    end

    def collect_content(chunks)
      content = nil
      if chunks.respond_to?(:each)
        chunks.each do |chunk|
          content ? (content << chunk.to_s) : (content = chunk.to_s)
        end
      else
        content = chunks
      end
      content
    end

    def body_injection_position(content)
      pattern = /<\s*body[^>]*>/im
      match = pattern.match(content)
      match.end(0) if match
    end

    def head_injection_position(content)
      pattern = /<\s*\/\s*head[^>]*>/im
      match = pattern.match(content)
      match.begin(0) if match
    end

    def html?(headers)
      content_type = headers['Content-Type']
      content_type && content_type.include?('text/html')
    end

    def attachment?(headers)
      content_disposition = headers['Content-Disposition']
      content_disposition && content_disposition.include?('attachment')
    end

  end
end
