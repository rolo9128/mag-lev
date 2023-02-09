module MagLev
  module ClassLogger
    def logger
      @logger ||= ClassLogger::Logger.new(self)
    end

    def logger_name
      if respond_to? :name
        name
      else
        ''
      end
    end

    protected

    # easy way to log the return value of code
    def log_info(result = nil)
      result ||= yield
      logger.debug "#{caller_locations(1,1)[0].label}: #{result.inspect}"
      result
    end

    # easy way to log the return value of code
    def log_info(result = nil)
      result ||= yield
      logger.info "#{caller_locations(1,1)[0].label}: #{result.inspect}"
      result
    end

    class Logger
      def initialize(instance)
        @instance = instance
      end

      [:debug, :info, :warn, :error, :fatal].each do |level|
        define_method level do |*args, **kwargs, &block|
          log(level, *args, **kwargs, &block)
        end
      end

      if defined?(Rails) and Rails.respond_to?(:logger)
        def log(level, *args, **kwargs, &block)
          if block_given?
            Rails.logger.send level do
              format(block.call)
            end
          else
            Rails.logger.send level, format(*args, **kwargs)
          end
        end
      else
        def log(method, *args, **kwargs, &block)
          if block_given?
            puts format(block.call)
          else
            puts format(*args, **kwargs)
          end
        end
      end

      def id
        if @instance.respond_to? :id
          "[#{@instance.id}] - "
        end
      end

      def format(msg, *args, **kwargs)
        msg = "#{@instance.class.name} #{id}#{@instance.logger_name}: #{msg}"
        [msg, *args, **kwargs].map(&:to_s).join(' | ')
      end

      def report(type, *args, **kwargs)
        begin
          args = args.compact
          if respond_to?(type)
            send(type, *args, **kwargs)
          end

          hash = args.find {|a| a.is_a? Hash}
          args << hash = {} unless hash
          hash[:logger_name] = @instance.logger_name
          # hash[@instance.to_s] = @instance # causes stack too deep errors in some cases
          EventReporter.send(type, *args, **kwargs)
        rescue => ex
          MagLev.logger.warn("Failed to report error:")
          MagLev.logger.error(ex)
        end
      end
    end
  end
end