module Puppet::Parser::Functions
      newfunction(:last_element, :type => :rvalue) do |args|
	return args[0].last
      end
end
