require 'selenium-webdriver'
require 'pincers/core/base_backend'
require 'pincers/webdriver/http_document'
require 'pincers/http/client'
require 'pincers/http/cookie'

module Pincers::Webdriver
  class Backend < Pincers::Core::BaseBackend

    DOM_PROPERTIES = [:selected, :disabled, :checked, :value, :required]

    attr_reader :driver

    alias :document :driver

    def initialize(_driver)
      @driver = _driver
    end

    def javascript_enabled?
      true
    end

    def document_root
      [driver]
    end

    def document_url
      driver.current_url
    end

    def document_title
      driver.title
    end

    def fetch_cookies
      driver.manage.all_cookies
    end

    def navigate_to(_url)
      driver.get _url
    end

    def navigate_forward(_steps)
      _steps.times { driver.navigate.forward }
    end

    def navigate_back(_steps)
      _steps.times { driver.navigate.back }
    end

    def refresh_document
      driver.navigate.refresh
    end

    def close_document
      driver.quit rescue nil
    end

    def search_by_css(_element, _selector, _limit)
      search _element, { css: _selector }, _limit
    end

    def search_by_xpath(_element, _selector, _limit)
      search _element, { xpath: _selector }, _limit
    end

    def extract_element_tag(_element)
      _element = ensure_element _element
      _element.tag_name
    end

    def extract_element_text(_element)
      _element = ensure_element _element
      _element.text
    end

    def extract_element_html(_element)
      return driver.page_source if _element == driver
      _element.attribute 'outerHTML'
    end

    def extract_element_attribute(_element, _name)
      _element = ensure_element _element
      if DOM_PROPERTIES.include? _name.to_sym
        driver.execute_script("return arguments[0]['#{_name}'];", _element)
      else
        _element[_name]
      end
    end

    def set_element_attribute(_element, _name, _value)
      _element = ensure_element _element
      if DOM_PROPERTIES.include? _name.to_sym
        driver.execute_script("arguments[0]['#{_name}'] = #{_value.to_json};", _element)
      elsif _value == ''
        driver.execute_script("arguments[0].removeAttribute('#{_name}')", _element)
      else
        driver.execute_script("arguments[0].setAttribute('#{_name}', #{_value.to_json})", _element)
      end
    end

    def element_is_actionable?(_element)
      # this is the base requisite in webdriver for actionable elements:
      # non displayed items will always error on action
      _element.displayed?
    end

    def set_element_text(_element, _value)
      _element = ensure_ready_for_input _element
      _element.clear
      _element.send_keys _value
    end

    def click_on_element(_element, _modifiers)
      _element = ensure_ready_for_input _element
      if _modifiers.length == 0
        _element.click
      else
        click_with_modifiers(_element, _modifiers)
      end
    end

    def right_click_on_element(_element)
      _element = ensure_ready_for_input _element
      actions.context_click(_element).perform
    end

    def double_click_on_element(_element)
      _element = ensure_ready_for_input _element
      actions.double_click(_element).perform
    end

    def hover_over_element(_element)
      _element = ensure_ready_for_input _element
      actions.move_to(_element).perform
    end

    def drag_and_drop(_element, _on)
      _element = ensure_input_element _element
      actions.drag_and_drop(_element, _on).perform
    end

    def submit_form(_element)
      _element = ensure_element _element
      _element.submit
    end

    def switch_to_frame(_element)
      driver.switch_to.frame _element
    end

    def switch_to_top_frame
      driver.switch_to.default_content
    end

    def as_http_client
      session = Pincers::Http::Session.new
      session.headers['User-Agent'] = user_agent
      session.proxy = proxy_address
      load_cookies_in_session session

      Pincers::Http::Client.new session, HttpDocument.new(self)
    end

  private

    def search(_element, _query, _limit)
      if _limit == 1
        begin
          [_element.find_element(_query)]
        rescue Selenium::WebDriver::Error::NoSuchElementError
          []
        end
      else
        _element.find_elements _query
      end
    end

    def actions
      driver.action
    end

    def click_with_modifiers(_element, _modifiers)
      _modifiers.each { |m| actions.key_down m }
      actions.click _element
      _modifiers.each { |m| actions.key_up m }
      actions.perform
    end

    def ensure_element(_element)
      return driver.find_element tag_name: 'html' if _element == driver
      _element
    end

    def ensure_ready_for_input(_element)
      _element = ensure_element _element
      Selenium::WebDriver::Wait.new.until { _element.displayed? }
      _element
    end

    def user_agent
      driver.execute_script("return navigator.userAgent;")
    end

    def proxy_address
      proxy = driver.capabilities.proxy
      proxy.nil? ? nil : (proxy.http || proxy.ssl)
    end

    def load_cookies_in_session(_session)
      driver.manage.all_cookies.each do |wd_cookie|
        if wd_cookie[:domain] and wd_cookie[:name] and wd_cookie[:value]
          _session.cookie_jar.set Pincers::Http::Cookie.new(
            wd_cookie[:name],
            wd_cookie[:value],
            wd_cookie[:domain],
            wd_cookie[:path],
            wd_cookie[:expires],
            wd_cookie[:secure]
          )
        end
      end
    end
  end
end