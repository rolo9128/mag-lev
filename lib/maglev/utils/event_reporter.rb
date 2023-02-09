module MagLev
  # integrates 3rd party error/event reporting libraries into a unified service
  class EventReporter
    def self.info(*args, **kwargs)
      log(:info, *args, **kwargs)
    end

    def self.warn(*args, **kwargs)
      log(:warn, *args, **kwargs)
    end

    def self.error(*args, **kwargs)
      log(:error, *args, **kwargs)
    end

    def self.fatal(*args, **kwargs)
      log(:fatal, *args, **kwargs)
    end

    def self.log(level, *args, **kwargs)
      if Rails.respond_to?(:env) and not Rails.env.test?
        ::Rollbar.send(level == :fatal ? :critical : level, *args, **kwargs) if defined?(::Rollbar)
        log_raven(level, *args, **kwargs) if defined?(Raven)
      end
    end

    def self.context
      MagLev.request_store[:event_reporter_context] ||= {}
    end

    # sets contextual information for the duration of the block. Deprecated. Use breadcrumb instead
    def self.with_context(key, data)
      existing = context[key]
      yield
      context[key] = existing
    end

    def self.breadcrumb(message, data = nil, level: :info, category: :application, clear: false)
      if defined? Raven
        Raven::BreadcrumbBuffer.clear! if clear
        Raven.breadcrumbs.record do |crumb|
          crumb.message = message
          crumb.data = data
          crumb.level = level
          crumb.category = category
          yield
        end
      else
        with_context(message, data) do
          yield
        end
      end
    end

    def self.log_raven(level, *args, **kwargs)
      str = args.find {|a| a.is_a?(String) }
      ex = args.find {|a| a.is_a?(Exception) }
      hash = args.find {|a| a.is_a?(Hash) } || {}

      hash[:message] = str if str and ex

      method = ex ? :capture_exception : :capture_message

      options = {level: level}

      if hash
        options[:extra] = hash
        options[:fingerprint] = hash.delete(:fingerprint) if hash[:fingerprint]
        options[:tags] = hash.delete(:tags) if hash[:tags]
        options[:user] = hash.delete(:user) if hash[:user]
      end

      # options[:fingerprint] ||= [str] if str

      Raven.send(method, ex || str, options)
    end
  end


end
