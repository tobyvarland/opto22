module Opto22
  
  ##
  # This class extends the native Ruby Array class so that values are POSTED to
  # the PAC controller in real-time (whenever an individual array element is
  # changed).
  #
  # Author :: Toby Varland (mailto:toby@tobyvarland.com)
  # License :: MIT
  #
  class OptoTable < Array

    ##
    # The +new+ class method initializes the class. If initial values are
    # included, those values are immediately POSTed to the controller. If no
    # initial values are included, a GET request is sent to the controller to
    # load the values.
    #
    # ==== Parameters
    # [parent]  The parent controller object where this table is stored.
    # [name]    The name of the table.
    # [values]  Values to be posted to the controller when the object is
    #           created.
    #
    # ==== Return Value
    # This function does not return a value.
    #
    # ==== Errors/Exceptions
    # Creating an object requires a valid PACController parent object. If no
    # valid parent object is given, an Opto22::OptoError is raised.
    #
    # ==== Changelog
    # [0.0.1] Initial version.
    #
    def initialize(parent, name, values=nil)

      # Raise exception if invalid parent object specified.
      unless parent.class.ancestors.include? Opto22::PACController
        raise OptoError.new :invalid_parent
      end

      # Store object properties.
      @parent = parent
      @name = name
      
      # Find variable type based on prefix.
      @prefix = @parent.extract_prefix @name
      @type = @parent.class::PREFIXES[@prefix]

      # If initial values passed in, POST to controller and then store in
      # internal array. If values not passed in, GET values from controller
      # and store in internal array.
      if values.nil?
        values = retrieve_values_from_controller
        super values
      else
        replace values
      end

    end

    ##
    # This function retrieves the table values from the PAC controller.
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
    def retrieve_values_from_controller

      # Get values from controller.
      values = @parent.get_json "#{@parent.class::URLS[@type]}/#{@name}"

      # If retrieving a boolean table, cast values as boolean.
      if @parent.class::BOOLEAN_PREFIXES.include? @prefix
        return values.map {|val| val != 0 }
      else
        return values
      end

    end

    ##
    # This function overloads the built-in +replace+ method for arrays. It calls
    # the built-in method but then also POSTs the new values to the PAC
    # controller.
    #
    # ==== Parameters
    # [new_array] The new values.
    #
    # ====== Options
    # [skip_post] If set to +true+, does not POST values to the PAC controller.
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
    def replace(new_array, options={})

      # Store replacement values in internal array.
      super(new_array)

      # Unless flag set, POST values to controller.
      skip_post = options.fetch :skip_post, false
      unless skip_post

        # Format boolean values for posting if necessary.
        if @parent.class::BOOLEAN_PREFIXES.include? @prefix
          values = new_array.map {|val| val ? 1 : 0}
        else
          values = new_array.clone
        end

        # POST to controller.
        @parent.post_json "#{@parent.class::URLS[@type]}/#{@name}", values

      end
    end

    ##
    # This function overloads the built-in index assignment method for arrays.
    # When storing a value in an individual index, the value is first validated
    # and then POSTed to the PAC controller.
    #
    # ==== Parameters
    # [index] The index in which to store the value.
    # [value] New value to store in the table.
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
    def []=(index, value)

      # Validate value.
      index_name = "#{@name}[#{index}]"
      case @type
      when :integer_table
        if @parent.class::BOOLEAN_PREFIXES.include? @prefix
          @parent.validate_boolean index_name, value
        else
          @parent.validate_integer index_name, value
        end
      when :float_table
        @parent.validate_float index_name, value
      when :string_table
        @parent.validate_string index_name, value
      end

      # Store new value in internal array (without POSTing entire table).
      copy = self.to_a
      copy[index] = value
      self.replace copy, skip_post: true

      # POST single element to controller.
      if @parent.class::BOOLEAN_PREFIXES.include? @prefix
        data = { value: value ? 1 : 0 }
      else
        data = { value: value }
      end

      # POST to controller.
      @parent.post_json "#{@parent.class::URLS[@type]}/#{@name}/#{index}", data

    end

  end

end