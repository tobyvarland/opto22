require 'json'
require 'net/https'
require 'uri'
require 'date'

module Opto22

  ##
  # This class is designed as an API client for the Opto 22 REST API for SNAP
  # PAC controllers. It is designed to provide a simple interface for retrieving
  # and setting variable values on PAC controllers.
  #
  # Author :: Toby Varland (mailto:toby@tobyvarland.com)
  # License :: MIT
  #
  class PACController

    ##
    # Stores URLs defined by the Opto 22 REST API indexed by variable type.
    #
    URLS = {
      :device_info    =>  '/api/v1/device',
      :stratgey_info  =>  '/api/v1/device/strategy',
      :down_timer     =>  '/api/v1/device/strategy/vars/downTimers',
      :up_timer       =>  '/api/v1/device/strategy/vars/upTimers',
      :analog_input   =>  '/api/v1/device/strategy/ios/analogInputs',
      :analog_output  =>  '/api/v1/device/strategy/ios/analogOutputs',
      :digital_input  =>  '/api/v1/device/strategy/ios/digitalInputs',
      :digital_output =>  '/api/v1/device/strategy/ios/digitalOutputs',
      :integer        =>  '/api/v1/device/strategy/vars/int32s',
      :float          =>  '/api/v1/device/strategy/vars/floats',
      :string         =>  '/api/v1/device/strategy/vars/strings',
      :integer_table  =>  '/api/v1/device/strategy/tables/int32s',
      :float_table    =>  '/api/v1/device/strategy/tables/floats',
      :string_table   =>  '/api/v1/device/strategy/tables/strings'
    }

    ##
    # Stores variable types indexed by type-indicator prefix.
    #
    PREFIXES = {
      :ai =>  :analog_input,
      :ao =>  :analog_output,
      :b  =>  :integer,
      :bt =>  :integer_table,
      :di =>  :digital_input,
      :do =>  :digital_output,
      :dt =>  :down_timer,
      :f  =>  :float,
      :ft =>  :float_table,
      :i  =>  :integer,
      :it =>  :integer_table,
      :s  =>  :string,
      :st =>  :string_table,
      :ut =>  :up_timer
    }

    ##
    # Regular expression used for extracting prefix from variable name. Prefix
    # is defined as all lowercase characters at the beginning of the variable
    # name.
    #
    PREFIX_EXTRACTION_REGEX = "^([a-z]+)"

    ##
    # Defines prefixes used for integer variables and tables that only function
    # as boolean values within the PAC controller. The values will be cast to
    # native boolean values.
    #
    BOOLEAN_PREFIXES = [:b, :bt]
 
    ##
    # Array of request URLs made by object during its lifetime.
    #
    attr_reader :request_urls

    ##
    # Total number of HTTP requests made by object.
    #
    attr_reader :request_count

    ##
    # PAC Controller type (retrieved if +load_device+ flag passed to
    # constructor).
    #
    attr_reader :controller_type
    
    ##
    # PAC Controller firmware version (retrieved if +load_device+ flag passed to
    # constructor).
    #
    attr_reader :firmware_version
    
    ##
    # PAC Controller firmware timestamp (retrieved if +load_device+ flag passed
    # to constructor).
    #
    attr_reader :firmware_timestamp
    
    ##
    # PAC Controller MAC address #1 (retrieved if +load_device+ flag passed to
    # constructor).
    #
    attr_reader :mac_1
    
    ##
    # PAC Controller MAC address #2 (retrieved if +load_device+ flag passed to
    # constructor).
    #
    attr_reader :mac_2
    
    ##
    # PAC Controller up time (retrieved if +load_device+ flag passed to
    # constructor).
    #
    attr_reader :up_time_seconds
    
    ##
    # Name of strategy running on PAC controller (retrieved if +load_device+
    # flag passed to constructor).
    #
    attr_reader :strategy_name
    
    ##
    # Timestamp of strategy running on PAC controller (retrieved if
    # +load_device+ flag passed to constructor).
    #
    attr_reader :strategy_timestamp
    
    ##
    # CRC code of strategy running on PAC controller (retrieved if +load_device+
    # flag passed to constructor).
    #
    attr_reader :crc
    
    ##
    # Number of charts running in strategy running on PAC controller (retrieved
    # if +load_device+ flag passed to constructor).
    #
    attr_reader :running_charts

    ##
    # The +new+ class method initializes the class. It requires the user to
    # pass in the connection information for the controller (IP address &
    # credentials). The user may also include optional parameters to change the
    # behavior of the object.
    #
    # ==== Parameters
    # [ip_address]  IP address of the controller.
    # [username]    Username used to connect to the controller.
    # [password]    Password used to connect to the controller.
    #
    # ====== Options
    # [load_device] Whether or not to lookup device & strategy properties
    #               (default: +false+).
    #
    # ==== Return Value
    # This function does not return a value.
    #
    # ==== Errors/Exceptions
    # If any connection parameters are empty, this function raises an
    # Opto22::OptoError.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    # ==== Examples
    # Example of how to create an object and look up device & strategy
    # information:
    #  controller = Opto22::PACController.new '1.2.3.4',
    #                                         'user',
    #                                         'pass',
    #                                         load_device: true
    #
    def initialize(ip_address, username, password, options = {})

      # Store connection properties.
      raise OptoError.new(:blank_ip) if ip_address.to_s.empty?
      raise OptoError.new(:blank_username) if username.to_s.empty?
      raise OptoError.new(:blank_password) if password.to_s.empty?
      @ip = ip_address
      @username = username
      @password = password
      
      # Initialize hash for caching data from the controller.
      @variables = {}
  
      # Initialize request tracking properties.
      @request_count = 0
      @request_urls = []

      # Retrieve device & strategy info if flag set.
      load_device = options.fetch :load_device, false
      if load_device
        retrieve_device_info
        retrieve_strategy_info
      end

    end

    ##
    # This function clears the object's internal cache.
    #
    # ===== Parameters
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
    # ==== Examples
    #  controller = Opto22::PACController.new '1.2.3.4',
    #                                         'user',
    #                                         'pass'
    #
    #  # GETs and caches values.
    #  puts controller.itValues
    #
    #  # Read values from cache – no HTTP request needed.
    #  puts controller.itValues
    #
    #  # Clears controller cache.
    #  controller.clear_cache
    #
    #  # Accessing values requires new GET request.
    #  puts controller.itValues
    #
    def clear_cache
      @variables = {}
      @request_urls << '==>  Cache cleared'
    end
    
    ##
    # This function extracts the type-indicator prefix from a variable name. It
    # uses the +PREFIX_EXTRACTION_REGEX+ constant to extract the prefix.
    #
    # ===== Parameters
    # [variable_name] The name of the variable from which to extract the prefix.
    #
    # ==== Return Value
    # The symbol representation of the prefix.
    #
    # ==== Errors/Exceptions
    # This function raises an Opto22::OptoError if no prefix is found or if the
    # prefix is invalid.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def extract_prefix(variable_name)
      regex = Regexp.new self.class::PREFIX_EXTRACTION_REGEX
      match = regex.match variable_name
      raise OptoError.new(:no_prefix, name: variable_name) if match.nil?
      prefix = match.to_s.to_sym
      if !self.class::PREFIXES.key? prefix
        raise OptoError.new(:prefix_error, prefix: prefix)
      end
      return prefix
    end
    
    ##
    # This function is used to POST JSON content to the PAC controller.
    #
    # ===== Parameters
    # [url]   URL to POST to.
    # [data]  Data to be encoded into JSON and sent to the controller.
    #
    # ==== Return Value
    # This function does not return a value.
    #
    # ==== Errors/Exceptions
    # If the HTTP status of the response is anything other than 200, an
    # Opto22::OptoRESTError is raised.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def post_json(url, data)
      
      # Configure JSON, POST, and return boolean to indicate status.
      uri = URI.parse "http://#{@ip}#{url}"
      @request_count += 1
      @request_urls << "POST #{uri}"
      http = Net::HTTP.new uri.host, uri.port
      request = Net::HTTP::Post.new uri.request_uri
      request.content_type = 'application/json'
      request.body = data.to_json
      request.basic_auth @username, @password
      response = http.request request
      raise OptoRESTError.new(request, response) unless response.code == '200'

    end
    
    ##
    # This function is used to GET JSON content from the PAC controller.
    #
    # ===== Parameters
    # [url]   URL to GET.
    #
    # ==== Return Value
    # This function decodes the JSON returned from the PAC controller and
    # returns the result.
    #
    # ==== Errors/Exceptions
    # If the HTTP status of the response is anything other than 200, an
    # Opto22::OptoRESTError is raised.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def get_json(url)
      
      # Retrieve return JSON data.
      uri = URI.parse "http://#{@ip}#{url}"
      @request_count += 1
      @request_urls << "GET  #{uri}"
      http = Net::HTTP.new uri.host, uri.port
      request = Net::HTTP::Get.new uri.request_uri
      request.basic_auth @username, @password
      response = http.request request
      case response.code
      when '200'
        return JSON.parse response.body
      else
        raise OptoRESTError.new request, response
      end

    end
    
    ##
    # Validates the given value to make sure it's a valid integer.
    #
    # ===== Parameters
    # [name]  The variable name.
    # [value] The value to validate.
    #
    # ==== Return Value
    # This function returns the passed value cast to an integer.
    #
    # ==== Errors/Exceptions
    # This function raises an Opto22::OptoError if validation fails.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def validate_integer(name, value)
      return value if [TrueClass, FalseClass].include? value.class
      invalid = false
      begin
        validated = Integer value
        invalid = true if validated != Float(value)
      rescue
        invalid = true
      end
      if invalid
        raise OptoError.new(:invalid_value, name: name, value: value)
      end
      return validated
    end

    ##
    # Validates the given value to make sure it's a valid float.
    #
    # ===== Parameters
    # [name]  The variable name.
    # [value] The value to validate.
    #
    # ==== Return Value
    # This function returns the passed value cast to a float.
    #
    # ==== Errors/Exceptions
    # This function raises an Opto22::OptoError if validation fails.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def validate_float(name, value)
      begin
        validated = Float value
      rescue
        raise OptoError.new(:invalid_value, name: name, value: value)
      end
      return validated
    end
    
    ##
    # Validates the given value to make sure it's a valid boolean.
    #
    # ===== Parameters
    # [name]  The variable name.
    # [value] The value to validate.
    #
    # ==== Return Value
    # This function returns the passed value.
    #
    # ==== Errors/Exceptions
    # This function raises an Opto22::OptoError if validation fails.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def validate_boolean(name, value)
      unless [TrueClass, FalseClass].include? value.class
        raise OptoError.new(:invalid_value, name: name, value: value)
      end
      return value
    end
    
    ##
    # Validates the given value to make sure it's a valid string.
    #
    # ===== Parameters
    # [name]  The variable name.
    # [value] The value to validate.
    #
    # ==== Return Value
    # This function returns the passed value cast to a string.
    #
    # ==== Errors/Exceptions
    # This function raises an Opto22::OptoError if validation fails.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def validate_string(name, value)
      begin
        validated = value.to_s
      rescue
        raise OptoError.new(:invalid_value, name: name, value: value)
      end
      return validated
    end
    
    protected
    
    ##
    # +method_missing+ is the special Ruby function called when a non-existent
    # function is called on an object. In this case, it is used to allow
    # retrieving and setting values on the controller directly using the simple
    # object.variable syntax.
    #
    # ===== Parameters
    # [name]      The name of the _function_ being called. For this class, this
    #             will either be the name of the variable to retrieve or a
    #             variable name followed by an "=".
    # [arguments] +arguments+ stores an array of any arguments passed to the
    #             function. For this class, there will be no arguments if
    #             retrieving a variable value and a single argument when
    #             setting a variable value.
    #
    # ==== Return Value
    # If retrieving a variable (any function name that does not end with "="),
    # the variable value is returned. If no valid prefix is found, or an invalid
    # variable name is passed, +nil+ is returned. If setting a variable, nothing
    # is returned.
    #
    # ==== Errors/Exceptions
    # This function does not explicitly raise any exceptions.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    # ==== Examples
    #  controller = Opto22::PACController.new '1.2.3.4',
    #                                         'user',
    #                                         'pass'
    #
    #  # Calls method_missing('itValues', []).
    #  puts controller.itValues
    #
    #  # Calls method_missing('itValues', [1, 2, 3, 4, 5]).
    #  controller.itValues = [1, 2, 3, 4, 5]
    #
    def method_missing(name, *arguments)
  
      # Get/set variable depending on whether method name ends with =
      regex = Regexp.new(/=$/)
      if regex.match(name).nil?
        return get_variable name.to_sym
      else
        set_variable name.to_s.chop.to_sym, arguments[0]
      end
  
    end
    
    ##
    # Validates given value before POSTing to the controller.
    #
    # ===== Parameters
    # [type]  The variable type.
    # [name]  The variable name.
    # [value] The value to set the variable to.
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
    def validate_value(type, name, value)
      
      # Validate passed data to make sure it's valid for the given type. Also
      # handles casting value to proper data type.
      case type
      when :analog_output, :float
        value = validate_float name, value
      when :digital_output
        value = validate_boolean name, value
      when :integer
        value = validate_integer name, value
      when :string
        value = validate_string name, value
      when :integer_table
        validate_array name, value
        value.each_with_index do |v, i|
          value[i] = validate_integer "#{name}[#{i}]", v
        end
      when :float_table
        validate_array name, value
        value.each_with_index do |v, i|
          value[i] = validate_float "#{name}[#{i}]", v
        end
      when :string_table
        validate_array name, value
        value.each_with_index do |v, i|
          value[i] = validate_string "#{name}[#{i}]", v
        end
      end

      # Return validated and type-casted value.
      return value

    end

    ##
    # Validates the given value to make sure it's a valid array.
    #
    # ===== Parameters
    # [name]  The variable name.
    # [value] The value to validate.
    #
    # ==== Return Value
    # This function returns the passed value.
    #
    # ==== Errors/Exceptions
    # This function raises an Opto22::OptoError if validation fails.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def validate_array(name, value)
      unless value.class == Array
        raise OptoError.new(:invalid_value, name: name, value: value)
      end
      return value
    end
    
    ##
    # This function is used to POST a variable to the controller.
    #
    # ===== Parameters
    # [name]  The name of the variable to set.
    # [value] The value to set the variable to.
    #
    # ==== Return Value
    # This function does not return a value.
    #
    # ==== Errors/Exceptions
    # This method raises an Opto22::OptoError in the following situations:
    #
    # * Tried to set a read only variable type (timer, input, etc.)
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def set_variable(name, value)

      # Find variable type based on prefix.
      prefix = extract_prefix name
      type = self.class::PREFIXES[prefix]

      # Raise an error if trying to set read-only type.
      if [:up_timer, :down_timer, :analog_input, :digital_input].include? type
        raise OptoError.new(:read_only, type: type, name: name)
      end

      # Validate passed data to make sure it's valid for the given type.
      value = validate_value type, name, value

      # Return value based on prefix-indicated type.
      case type
      when :analog_output
        data = { value: value.to_f }
        post_json "#{URLS[type]}/#{name}/eu", data
      when :digital_output
        data = { value: value }
        post_json "#{URLS[type]}/#{name}/state", data
      when :float_table, :string_table, :integer_table
        if @variables[type].nil? || @variables[type][name].nil?
          if @variables[type].nil?
            @variables[type] = {}
          end
          @variables[type][name] = OptoTable.new self, name, value
        else
          @variables[type][name].replace value
        end
      else
        case value.class
        when TrueClass
          data = { value: 1 }
        when FalseClass
          data = { value: 0 }
        else
          data = { value: value }
        end
        post_json "#{URLS[type]}/#{name}", data
      end
      unless [:integer_table, :float_table, :string_table].include? type
        unless @variables[type].nil? || @variables[type][name].nil?
          @variables[type][name] = value
        end
      end

    end

    ##
    # This function retrieves the value of a variable from the controller. If
    # the variable is a non-table type, a generic request is sent to retrieve
    # all variables of the given type to reduce the number of requests sent to
    # the PAC controller.
    #
    # ===== Parameters
    # [name]  The name of the variable to retrieve.
    #
    # ==== Return Value
    # The value of the variable, or +nil+ if something goes wrong.
    #
    # ==== Errors/Exceptions
    # This method raises an Opto22::OptoError in the following situations:
    #
    # * Tried to retrieve variable that does not exist on controller.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def get_variable(name)

      # Find variable type based on prefix.
      prefix = extract_prefix name
      type = self.class::PREFIXES[prefix]

      # Return value based on prefix-indicated type.
      case type
      when :integer_table, :float_table, :string_table
        if @variables[type].nil?
          @variables[type] = {}
        end
        if @variables[type][name].nil?
          @variables[type][name] = OptoTable.new self, name
        end
        return @variables[type][name]
      else
        if @variables[type].nil?
          json = get_json URLS[type]
          @variables[type] = Hash[json.collect {|obj| [obj['name'].to_sym,
                                                       obj['value']]}]
          format_booleans if type == :integer
        end
        if !@variables[type].key? name
          raise OptoError.new :invalid_variable, type: type, name: name
        end
        return @variables[type][name]
      end

    end

    ##
    # This function iterates through all :integer variables and casts any
    # variable whose name contains a boolean prefix as a boolean instead of as
    # an integer.
    #
    # ===== Parameters
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
    def format_booleans
      @variables[:integer].each do |name, value|
        if self.class::BOOLEAN_PREFIXES.include? extract_prefix(name)
          @variables[:integer][name] = (value != 0)
        end
      end
    end

    ##
    # This function is used to retrieve information about the PAC controller. It
    # is called if the +load_device+ option is set when the
    # +Opto22::PACController+ object is created.
    #
    # ===== Parameters
    # This function does not require any parameters.
    #
    # ==== Return Value
    # This function does not return a value. It does set a number of class
    # properties.
    #
    # ==== Errors/Exceptions
    # This function does not explicitly raise any exceptions.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def retrieve_device_info
      
      # Retrieve and store device information.
      device_info = get_json URLS[:device_info]
      @controller_type = device_info['controllerType']
      @firmware_version = device_info['firmwareVersion']
      date = device_info['firmwareDate']
      time = device_info['firmwareTime']
      @firmware_timestamp = DateTime.strptime "#{date} #{time}",
                                              '%m/%d/%Y %H:%M:%S'
      @mac_1 = device_info['mac1']
      @mac_2 = device_info['mac2']
      @up_time_seconds = device_info['upTimeSeconds']

    end

    ##
    # This function is used to retrieve information about the currently running
    # strategy from the controller. It is called if the +load_device+ option is
    # set when the +Opto22::PACController+ object is created.
    #
    # ===== Parameters
    # This function does not require any parameters.
    #
    # ==== Return Value
    # This function does not return a value. It does set a number of class
    # properties.
    #
    # ==== Errors/Exceptions
    # This function does not explicitly raise any exceptions.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def retrieve_strategy_info
      
      # Retrieve and store strategy information.
      strategy_info = get_json URLS[:stratgey_info]
      @strategy_name = strategy_info['strategyName']
      date = strategy_info['date']
      time = strategy_info['time']
      @strategy_timestamp = DateTime.strptime "#{date} #{time}",
                                              '%m/%d/%y %H:%M:%S'
      @crc = strategy_info['crc']
      @running_charts = strategy_info['runningCharts']

    end

  end

end