# Opto22 Gem

**This gem has not been published to RubyGems. The only way to use it currently
is to download the .gem for local installation or to build it from source.**

This gem contains the definition of class `Opto22::PACController`, which is
designed to be a lightweight wrapper for the
[Opto 22 REST API](https://goo.gl/h6uTmW) for SNAP PAC Controllers.

One of the primary assumptions of this class is that variable names adhere to a
consistent naming convention using lowercase type-indicator prefixes and at
least one capital letter after the prefix. Essentially, all lowercase letters at
the beginning of a variable name are treated as the prefix. This behavior can be
changed to some extent by extending and overloading the `PACController` class.

The default prefixes are as follows:

| Prefix | Variable Type         |
|:------:|-----------------------|
| `ai`   | Analog Input          |
| `ao`   | Analog Output         |
| `b`    | Boolean Integer       |
| `bt`   | Boolean Integer Table |
| `di`   | Digital Input         |
| `do`   | Digital Output        |
| `dt`   | Down Timer            |
| `f`    | Float                 |
| `ft`   | Float Table           |
| `i`    | Integer               |
| `it`   | Integer Table         |
| `s`    | String                |
| `st`   | String Table          |
| `ut`   | Up Timer              |

## Usage

```ruby
# Require gem.
require "opto22"

# Creates a controller object.
my_pac = Opto22::PACController.new '1.2.3.4', 'username', 'password'

# Displays the value of an integer variable named "iValue".
puts my_pac.iValue
# => 0

# Sets the value of integer iValue.
my_pac.iValue = 5

# Displays each value from a string table named "stNames" (10 elements).
my_pac.stNames.each_with_index do |name, index|
  puts "[#{index}]: #{name}"
end
# => [0]: Bob
# => [1]: Tom
# => [2]: Susie
# => [3]: Joe
# => ...

# Store new names in string table stNames.
my_pac.stNames = ["Bill", "Fred", "Kevin", "Andrea", ...]

# Change a single name in string table stNames.
my_pac.stNames[6] = "Mark"
```

## Programming Notes

To reduce strain on the controller, non-table variables are retrieved in bulk
the first time a variable of each type is requested. For example, the first time
an integer variable is retrieved, `PACController` uses the REST API to retrieve
and cache the values of all integers in the stratgey. After that first integer
is retrieved, no further HTTP requests are required for other integer variables.

It is possible to extend the `PACController` class to avoid having to initialize
the object with an IP address, username, and password every time:

```ruby
class MachineController < Opto22::PACController
  def initialize
    super '1.2.3.4', 'user', 'pass'
  end
end

pac = MachineController.new
```

The `PACController` class currently does not support setting or retrieving
partial tables.

The `PACController` class currently does not support 64 bit integer variables or
tables.

The `PACController` class has not been tested over HTTPS.

Finally, although there is no discrete boolean data type within Opto 22
strategies, the `PACController` class includes specific prefixes for integer
variables and integer tables designated as boolean only (`b` and `bt`
respectively by default).

## Prerequisites

The PAC Controller must be configured to enable the REST API. Configuration
details are available on [Opto 22's website](https://goo.gl/7VdM6s).