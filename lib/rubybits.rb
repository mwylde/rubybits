module RubyBits
	# You can subclass RubyBits::Strcuture to define new binary formats. This
	# can be used for lots of purposes: reading binary data, communicating in
	# binary formats (like TCP/IP, http, etc).
	class Structure < Object
		class << self
			[:unsigned, :signed, :text, :variable].each{|kind|
				define_method kind do |name, size, description, *options|
					field(kind, name, size, description, options)
				end
			}
			
			private
			def field kind, name, size, description, options
				@_fields ||= []
				@_fields << [kind, name, size, description, options]
				self.class_eval %{
					def #{name}= val
						@_#{name} = val
					end
					def #{name}
						@_#{name}
					end
				}
			end
		end
		
		def initialize(values={})
			values.each{|key, value|
				self.send "#{key}=", value
			}
		end
		
		# Returns a binary string representation of the structure according to the fields defined
		# and their current values.
		# @return [String] bit string representing struct
		def to_s
			offset = 0
			buffer = []
			@_fields.collect{|field|
				kind, name, size, description, options = field
				data = self.send(name)
				data ||= 0
				
				if offset == 0
					buffer 
				end
			}
			buffer.pack("c*")
		end
	end
	
end