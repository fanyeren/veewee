module Veewee
  module Provider
    module Core
      module Helper
        require 'webrick'

        include WEBrick

        module Web
          def wait_for_http_request(filename, urlname, options) # thread with timeout
            thread  = allow_for_http_request(filename, urlname, options)
            timeout = options[:timeout] || 60
            thread.join(timeout) or begin
              thread.kill
              raise "File #{filename.inspect} was not requested in #{timeout} seconds, are you using firewall blocking connections to port: #{options[:port]}?"
            end
          end

          def allow_for_http_request(filename, urlname, options) # start in new thread
            thread = Thread.new do
              server_for_http_request(filename, urlname, options.merge({:threaded => false}))
            end
            thread.abort_on_exception = true
            trap("INT") { thread.kill }
            thread
          end

        private

          def server_for_http_request(filename, urlname, options, &block)
            read_content(filename)
            initialize_server(options[:port])
            mount_file(urlname, !options[:threaded])
            @server.start
          ensure
            server_shutdown
          end

          def read_content(filename)
            ui.info "Reading content #{filename}"
            @content = File.open(filename, "r").read
            if File.extname(filename) == ".erb"
              ui.info "Evaluating template #{filename}"
              @content = ::ERB.new(@content).result(binding)
            end
          end

          def initialize_server(port)
            # Calculate the OS equivalent of /dev/null , on windows this is NUL:
            # http://www.ruby-forum.com/topic/115472
            fn = test(?e, '/dev/null') ? '/dev/null' : 'NUL:'
            webrick_logger = WEBrick::Log.new(fn, WEBrick::Log::INFO)

            @server =
            ::WEBrick::HTTPServer.new(
              :Port => port,
              :Logger => webrick_logger,
              :AccessLog => webrick_logger,
            )
          end

          def mount_file(urlname, one_file_only = true)
            urlname = urlname[0..-5] if File.extname(urlname)  == ".erb"

            @server.mount_proc(urlname) do |request, response|
              ui.info "Serving content for #{urlname}"
              response['Content-Type']='text/plain'
              response.status = 200
              response.body   = @content
              server_shutdown if one_file_only
            end
          end

          def server_shutdown
            if @server
              ui.info "Stopping webserver"
              yield @server if block_given?
              @server.shutdown
              @server = nil
            end
          end

        end #Class
      end #Module
    end #Module
  end #Module
end #Module
