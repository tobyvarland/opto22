require 'net/https'
require 'uri'
require 'csv'

module Opto22

  ##
  # This class is used for generic errors thrown by the Opto22::PACController
  # class.
  #
  # Author :: Toby Varland (mailto:toby@tobyvarland.com)
  # License :: MIT
  #
  class OptoError < StandardError

    ##
    # Message timestamp.
    #
    attr_reader :timestamp
    
    ##
    # Message text.
    #
    attr_reader :text
    
    ##
    # Message type.
    #
    attr_reader :error_type
    
    ##
    # Variable prefix (only applicable to certain messages).
    #
    attr_reader :prefix
    
    ##
    # Variable name (only applicable to certain messages).
    #
    attr_reader :name

    ##
    # Variable type (only applicable to certain messages).
    #
    attr_reader :type

    ##
    # Variable value (only applicable to certain messages).
    #
    attr_reader :value

    ##
    # The +new+ class method initializes the exception. It requires the user to
    # pass in one of a number of predefined exception symbols. Some errors may
    # also have supporting information included in the options hash.
    #
    # ==== Parameters
    # [type]  The type of error encountered. If not given, a generic "unknown
    #         error" message will be shown.
    #
    # ====== Options
    # [type]    Used to pass in the variable type for symbols that require the
    #           type as supporting information.
    # [name]    Used to pass in the variable name for symbols that require the
    #           name as supporting information.
    # [prefix]  Used to pass in the variable prefix for symbols that require the
    #           prefix as supporting information.
    # [value]   Used to pass in the variable value for symbols that require the
    #           value as supporting information.
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
    def initialize(type=nil, options = {})

      # Store error properties.
      @timestamp = DateTime.now

      # Determine message based on type.
      @name = options.fetch(:name, '').to_s
      @prefix = options.fetch(:prefix, '').to_s
      @type = options.fetch :type, nil
      @value = options.fetch(:value, '').to_s
      @error_type = type
      case @error_type
      when :blank_ip
        @text = 'IP address cannot be blank.'
      when :blank_username
        @text = 'Username cannot be blank.'
      when :blank_password
        @text = 'Password cannot be blank.'
      when :no_prefix
        @text = "Tried accessing variable with no prefix: #{@name}"
      when :prefix_error
        @text = "Tried accessing variable with an undefined prefix: #{@prefix}."
      when :read_only
        @text = "Tried to set read-only variable: #{@type}/#{@name}."
      when :invalid_variable
        @text = "Variable not found on controller: #{@type}/#{@name}."
      when :invalid_value
        @text = "Tried to set variable to invalid value: #{@name} = #{@value}."
      when :invalid_table
        @text = "Tried to commit non-table variable: #{@name}"
      when :invalid_parent
        @text = "Specified an invalid object as a parent for an OptoTable."
      else
        @error_type = :unknown
        @text = 'An unknown error has occurred.'
      end

      # Pass message to parent constructor.
      super @text

    end

  end

end