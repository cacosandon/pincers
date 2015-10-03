require "pincers/core/window"
require "pincers/core/cookies"
require "pincers/core/download"
require "pincers/core/search_context"

module Pincers::Core
  class RootContext < SearchContext

    attr_reader :config

    def initialize(_backend, _config={})
      super nil, nil, nil
      @backend = _backend
      @config = Pincers.config.values.merge _config
    end

    def root
      self
    end

    def root?
      true
    end

    def elements
      @backend.document_root
    end

    def element
      @backend.document_root.first
    end

    def document
      @backend.document
    end

    def backend
      @backend
    end

    def url(_partial=nil)
      wrap_errors {
        current_url = backend.document_url
        if _partial
          current_url ? URI.join(current_url, _partial).to_s : _partial
        else
          current_url
        end
      }
    end

    def uri(_partial=nil)
      URI.parse url(_partial)
    end

    def title
      wrap_errors { backend.document_title }
    end

    def cookies
      @cookies ||= Cookies.new backend
    end

    def goto(_urlOrOptions)
      wrap_errors do
        if _urlOrOptions.is_a? String
          _urlOrOptions = { url: _urlOrOptions }
        end

        if _urlOrOptions.key? :url
          goto_url _urlOrOptions[:url]
        elsif _urlOrOptions.key? :frame
          goto_frame _urlOrOptions[:frame]
        else
          raise ArgumentError.new "Must provide a valid target when calling 'goto'"
        end
      end
      self
    end

    def forward(_steps=1)
      wrap_errors { backend.navigate_forward _steps }
      self
    end

    def back(_steps=1)
      wrap_errors { backend.navigate_back _steps }
      self
    end

    def refresh
      wrap_errors { backend.refresh_document }
      self
    end

    def close
      wrap_errors { backend.close_document }
      self
    end

    def windows
      wrap_errors do
        backend.list_window_handlers.map { |id| Window.new(self, id) }
      end
    end

    def window(_window=:self)
      wrap_errors do
        current_hnd = backend.current_window_handler

        handler = case _window
        when :self
          current_hnd
        when :next, :previous
          all_hnd = backend.list_window_handlers
          hnd_idx = all_hnd.index current_handler
          hnd_idx += _window == :next ? 1 : -1
          all_hnd[hnd_idx]
        else
          raise ArgumentError.new "Invalid :frame option #{_frame.inspect}"
        end

        Window.new self, handler
      end
    end

    def default_timeout
      @config[:wait_timeout]
    end

    def default_interval
      @config[:wait_interval]
    end

    def advanced_mode?
      @config[:advanced_mode]
    end

    def http_client
      wrap_errors { backend.as_http_client }
    end

    def download(_url)
      Pincers::Core::Download.from_http_response http_client.get url(_url)
    end

  private

    def wrap_siblings(_elements)
      # root node siblings behave like childs
      SearchContext.new _elements, self, nil
    end

    def goto_url(_url)
      _url = "http://#{_url}" unless /^(https?|file|ftp):\/\// === _url
      backend.navigate_to _url
    end

    def goto_frame(_frame)
      case _frame
      when :top
        backend.switch_to_top_frame
      when :parent
        backend.switch_to_parent_frame
      when String
        search(_frame, limit: 1).goto
      else
        raise ArgumentError.new "Invalid :frame option #{_frame.inspect}"
      end
    end

    def goto_window(_window)
      target = case _window
      when :first
        windows.first
      when :last
        windows.last
      when :next, :previous
        window _window
      else
        raise ArgumentError.new "Invalid :window option #{_window.inspect}"
      end

      target.goto if target
    end

  end
end
