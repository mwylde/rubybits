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
			
			def checksum field, &block
				@_checksum_field = [field, block]
			end
			
			def fields; @_fields; end
			def checksum_field; @_checksum_field; end

			private
			def field kind, name, size, description, options
				@_fields ||= []
				@_fields << [kind, name, size, description, options]
				self.class_eval %{
					def #{name}= val
						@__#{name} = val
						@_checksum_cached = false
					end
					def #{name}
						@__#{name}
					end
				}
			end
		end
		
		def initialize(values={})
			values.each{|key, value|
				self.send "#{key}=", value
			}
			@_checksum_cached = false
		end
				
		# Returns a binary string representation of the structure according to the fields defined
		# and their current values.
		# @return [String] bit string representing struct
		def to_s(do_checksum = true)
			if self.class.checksum_field && do_checksum && !@_checksum_cached
				self.calculate_checksum
			end
			offset = 0
			buffer = []
			# This method works by iterating through each bit of each field and setting the bits in
			# the current output byte appropriately.
			self.class.fields.collect{|field|
				kind, name, size, description, options = field
				data = self.send(name)
				data ||= 0
				size.times do |bit|
					buffer << 0 if offset % 8 == 0
					lm_of_8 = (size/8)*8
					buffer[-1] |= get_bit(data, size-bit-1) << 7-(offset % 8)
					offset += 1
				end
			}
			#puts
			#puts buffer.collect{|x| "%08b" % x}.inspect
			#puts [0b11010001, 0b10101010, 0b11111010, 0b10001110].collect{|x| "%08b" % x}.inspect
			
			buffer.pack("c*")
			
		end
		
		
		protected
		
		PACK_MAP = {
			:unsigned => "I",
			:signed   => "i"
		}
		
		def calculate_checksum
			if self.class.checksum_field
				self.send("#{self.class.checksum_field[0]}=", 0)
				checksum = self.class.checksum_field[1].call(self.to_s(false).bytes.to_a)
				self.send("#{self.class.checksum_field[0]}=", checksum)
				@_checksum_cached = true
			end
		end
		
		def set_bit(byte, bit, value)
			#TODO: this can probably be made more efficient
			byte & (1<<bit) > 0 == value > 0 ? byte : byte ^ (1<<bit)
		end
		
		def get_bit(byte, bit)
			byte & (1<<bit) > 0 ? 1 : 0
		end
	end
	
end