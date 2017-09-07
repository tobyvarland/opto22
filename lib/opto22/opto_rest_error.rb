require 'net/https'
require 'uri'
require 'csv'

module Opto22

  ##
  # This class is used for errors returned by the Opto 22 PAC controller in
  # response to an HTTP request.
  #
  # This class does provide error message logging if desired. Logging is
  # controlled by two environment variables: +OPTO22_GEM_ERROR_LOG_PATH+ and
  # +OPTO22_GEM_ERROR_LOG_FORMAT+. If the +OPTO22_GEM_ERROR_LOG_FORMAT+ is set
  # to "csv", the log will be written in comma separated variable format.
  # Otherwise the log will be written as text.
  #
  # Author :: Toby Varland (mailto:toby@tobyvarland.com)
  # License :: MIT
  #
  class OptoRESTError < StandardError

    ##
    # Full URL of request.
    #
    attr_reader :full_url
    
    ##
    # Request host name.
    #
    attr_reader :host
    
    ##
    # Message timestamp.
    #
    attr_reader :timestamp
    
    ##
    # Request path (does not include host name or http(s) prefix).
    #
    attr_reader :path
    
    ##
    # HTTP response code.
    #
    attr_reader :response_code
    
    ##
    # HTTP request method (GET or POST).
    #
    attr_reader :request_method
    
    ##
    # Text description of error type (determined by HTTP status code).
    #
    attr_reader :error_type
    
    ##
    # Message text.
    #
    attr_reader :text
    
    ##
    # Log file path (read from +OPTO22_GEM_ERROR_LOG_PATH+ environment
    # variable).
    #
    attr_reader :log_path
    
    ##
    # Log file format (read from +OPTO22_GEM_ERROR_LOG_FORMAT+ environment
    # variable).
    #
    attr_reader :log_format

    ##
    # The +new+ class method initializes the exception.
    #
    # ==== Parameters
    # [request]   The HTTP request object (see Net::HTTPGenericRequest).
    # [response]  The HTTP response object (see Net::HTTPResponse).
    #
    # ==== Return Value
    # This function does not return a value.
    #
    # ==== Errors/Exceptions
    # This function does not explicitly raise any exceptions.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def initialize(request, response)

      # Store error properties.
      @timestamp = DateTime.now
      @host = request.get_fields('host').first
      @path = request.path
      @full_url = "http://#{@host}#{@path}"
      @response_code = response.code
      @request_method = request.method
      @log_path = ENV.fetch 'OPTO22_GEM_ERROR_LOG_PATH', nil
      @log_format = (ENV.fetch 'OPTO22_GEM_ERROR_LOG_FORMAT', 'txt').to_sym

      # Build message string & pass to parent constructor.
      case response.code
      when '400'
        @error_type = 'Bad Request'
      when '401'
        @error_type = 'Authentication Error'
      when '404'
        @error_type = 'Not Found'
      else
        @error_type = 'Unknown Error'
      end
      message_parts = [@timestamp.strftime('%m/%d/%y %H:%M:%S'),
                       '=>',
                       @response_code,
                       "#{@error_type}:",
                       @request_method,
                       @full_url]
      @text = message_parts.join ' '
      super @text

      # Log error (only written if environment variable set).
      log_error

    end

    protected

    ##
    # Logs the exception if specific environment variables are set.
    #
    # ==== Parameters
    # This function does not require any parameters.
    #
    # ==== Return Value
    # This function does not return a value.
    #
    # ==== Errors/Exceptions
    # This function does not explicitly raise any exceptions.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def log_error

      # Do nothing if environment variable for path not set.
      return if @log_path.nil?

      # Write message to log.
      case @log_format
      when :csv
        already_exists = File.file? @log_path
        CSV.open(@log_path, 'a') do |csv|
          csv << ['Date',
                  'Time',
                  'Code',
                  'Type',
                  'Method',
                  'URL'] unless already_exists
          csv << [@timestamp.strftime('%m/%d/%y'),
                  @timestamp.strftime('%H:%M:%S'),
                  @response_code,
                  @error_type,
                  @request_method,
                  @full_url]
        end
      else
        File.write @log_path, "#{@text}\n", mode: 'a'
      end

    end

  end

end