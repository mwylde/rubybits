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
			
			def fields; @_fields; end
			
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
			# This method works by iterating through each bit of each field and setting the bits in
			# the current output byte appropriately.
			self.class.fields.collect{|field|
				kind, name, size, description, options = field
				data = self.send(name)
				data ||= 0
				bytes = [data].pack(PACK_MAP[kind]).bytes.to_a
				b_iter = (size/8.0).ceil
				size.times do |bit|
					buffer << 0 if offset % 8 == 0
					b_iter -= 1 if bit % 8 == 0
					# the largest multiple of 8 smaller than size
					lm_of_8 = (size/8)*8
					# we need to calculate this function:
					# f(x) = {8 if bit < lm_of_8; size-lm_of_8 otherwise}
					buffer[-1] |= (get_bit(bytes[b_iter], (bit < lm_of_8 ? 8 : size-lm_of_8)-(bit % 8)-1) << 7-(offset % 8))
					offset += 1
				end
			}
			puts
			puts buffer.collect{|x| "%08b" % x}.inspect
			puts [0b11010001, 0b10101010, 0b11111010, 0b10001110].collect{|x| "%08b" % x}.inspect
			
			buffer.pack("c*")
		end
		
		private
		PACK_MAP = {
			:unsigned => "I",
			:signed   => "i"
		}
		
		def set_bit(byte, bit, value)
			#TODO: this can probably be made more efficient
			byte & (1<<bit) > 0 == value > 0 ? byte : byte ^ (1<<bit)
		end
		
		def get_bit(byte, bit)
			byte & (1<<bit) > 0 ? 1 : 0
		end
	end
	
end