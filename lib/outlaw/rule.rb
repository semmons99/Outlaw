module Outlaw
  class Rule
    NoDetectionBlockProvided = Class.new(StandardError)
    attr_reader :message, :restriction
    def initialize(message, restriction, type=:ruby, scope=:file, &detection_block)
      raise NoDetectionBlockProvided unless detection_block
      @message          = message
      @restriction      = restriction
      @type             = type
      @scope            = scope
      @detection_block  = detection_block
    end

    def call(code)
      @detection_block.call(code)
    end

    class << self
      def test(program, start_index, pattern)
        pattern_index = 0
        params = params_count_hash(pattern)
        start_index.upto(program.length) do |index|
          code = program[index]
          part = pattern[pattern_index]

          next if IGNORE_TYPES.include? token_type(code)

          #RegEx responds to .source but not .to_sym, symbols vice versa.
          #Is this really better than checking is_type_of? Smells since not using methods
          if (part.respond_to?(:to_a)   && part.include?(code))
            pattern_index += 1
          elsif (part.respond_to?(:source) && code.match(part))
            pattern_index += 1
          elsif (part.respond_to?(:to_sym) && param_type_equal(token_type(code), part))
            #check count on first and count down subseq matches
            if params[part].first.nil?
              params[part][0] = code
              params[part][1] -= 1
              pattern_index += 1
            else
              if params[part].first == code
                params[part][1] -= 1
                pattern_index += 1
              else
                return false
              end
            end
          else
            return false
          end
          return true if pattern_index >= pattern.length
        end   #we got to the end of pattern, so it was matched
        return false
        # got to end of program without end of pattern
      end

      private

      def param_type_equal(lex, param)
        #for now just check if it's a variable type, not kw, ws or other token
        PARAM_TYPES.include? lex
      end

      def token_type(code)
        Ripper.lex(code).flatten(1)[1] #Ripper's name for token type is returned in array
      end

      def params_count_hash(pattern)
        params = Hash.new(0)
        pattern.each do |element|
          params[element] += 1 if element.respond_to?(:to_sym)
        end
        output = {}                   #nil is placeholder for matched lex code
        params.keys.each {|key| output[key] = [nil, params[key]]}
        output
      end
    end
  end
end
